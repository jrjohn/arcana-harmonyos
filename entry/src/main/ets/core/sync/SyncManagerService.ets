/**
 * Injectable Sync Manager Service
 * Implements ISyncManager interface for DI container
 */

import { injectable, inject, preDestroy } from '../di/decorators';
import { ISyncManager, IUserRepositoryService, INetworkMonitor, ILogger } from '../di/interfaces';
import { TYPES } from '../di/tokens';
import { LocalUser, SyncStatus, LocalUserFactory } from '../../domain/models/User';
import { ResultFactory } from '../../domain/models/Result';
import { NetworkStatus } from '../network/NetworkMonitor';
import { SyncState, SyncStateCallback } from './SyncManager';

const TAG = 'SyncManagerService';

/**
 * Injectable sync manager service implementation
 */
@injectable()
export class SyncManagerService implements ISyncManager {
  private repository: IUserRepositoryService;
  private networkMonitor: INetworkMonitor;
  private logger: ILogger;

  private callbacks: Set<SyncStateCallback> = new Set();
  private syncInProgress: boolean = false;
  private syncState: SyncState = {
    isSyncing: false,
    pendingCount: 0,
    lastSyncTime: undefined,
    lastSyncError: undefined
  };
  private networkUnsubscribe: (() => void) | null = null;
  private syncTimeoutId: number | null = null;

  // Retry configuration
  private readonly maxRetries = 3;
  private readonly retryDelayMs = 2000;
  private readonly syncIntervalMs = 30000; // 30 seconds

  constructor(
    repository: IUserRepositoryService,
    networkMonitor: INetworkMonitor,
    logger: ILogger
  ) {
    this.repository = repository;
    this.networkMonitor = networkMonitor;
    this.logger = logger;
    this.setupNetworkListener();
    this.updatePendingCount();
  }

  private setupNetworkListener(): void {
    this.networkUnsubscribe = this.networkMonitor.subscribe((state) => {
      this.logger.d(TAG, `Network state changed: ${state.status}`);

      if (state.status === NetworkStatus.AVAILABLE) {
        this.triggerSync();
      }
    });
  }

  subscribe(callback: SyncStateCallback): () => void {
    this.callbacks.add(callback);
    callback({ ...this.syncState });

    return () => {
      this.callbacks.delete(callback);
    };
  }

  getState(): SyncState {
    return { ...this.syncState };
  }

  async triggerSync(): Promise<void> {
    if (this.syncInProgress) {
      this.logger.d(TAG, 'Sync already in progress');
      return;
    }

    const isOnline = await this.networkMonitor.isNetworkAvailable();
    if (!isOnline) {
      this.logger.d(TAG, 'Network not available, skipping sync');
      return;
    }

    await this.performSync();
  }

  private async performSync(): Promise<void> {
    this.syncInProgress = true;
    this.updateState({ isSyncing: true });
    this.logger.i(TAG, 'Starting sync...');

    const endTimer = this.logger.time(TAG, 'Sync operation');

    try {
      const pendingResult = await this.repository.getPendingSyncUsers();
      if (ResultFactory.isFailure(pendingResult)) {
        throw new Error('Failed to get pending users');
      }

      const pendingUsers = pendingResult.value;
      this.logger.d(TAG, `Found ${pendingUsers.length} items to sync`);

      let successCount = 0;
      let failureCount = 0;

      for (const user of pendingUsers) {
        const success = await this.syncUser(user);
        if (success) {
          successCount++;
        } else {
          failureCount++;
        }
      }

      await this.repository.setLastSyncTime(Date.now());

      this.logger.i(TAG, `Sync completed: ${successCount} success, ${failureCount} failed`);

      this.updateState({
        isSyncing: false,
        lastSyncTime: Date.now(),
        lastSyncError: failureCount > 0 ? `${failureCount} items failed to sync` : undefined
      });
    } catch (error) {
      this.logger.e(TAG, `Sync failed: ${error}`);
      this.updateState({
        isSyncing: false,
        lastSyncError: String(error)
      });
    } finally {
      this.syncInProgress = false;
      await this.updatePendingCount();
      endTimer();
    }
  }

  private async syncUser(user: LocalUser): Promise<boolean> {
    this.logger.d(TAG, `Syncing user ${user.id} with status ${user.syncStatus}`);

    try {
      switch (user.syncStatus) {
        case SyncStatus.PENDING_CREATE:
          return await this.syncCreate(user);

        case SyncStatus.PENDING_UPDATE:
          return await this.syncUpdate(user);

        case SyncStatus.PENDING_DELETE:
          return await this.syncDelete(user);

        case SyncStatus.SYNC_FAILED:
          if (user.syncAttempts < this.maxRetries) {
            return await this.retrySync(user);
          }
          this.logger.w(TAG, `User ${user.id} exceeded max retries`);
          return false;

        default:
          return true;
      }
    } catch (error) {
      this.logger.e(TAG, `Error syncing user ${user.id}: ${error}`);
      await this.repository.updateSyncStatus(user.id, SyncStatus.SYNC_FAILED, String(error));
      return false;
    }
  }

  private async syncCreate(user: LocalUser): Promise<boolean> {
    const result = await this.repository.createUserOnNetwork({
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      avatar: user.avatar
    });

    if (ResultFactory.isSuccess(result)) {
      await this.repository.deleteUserFromLocal(user.id);
      const syncedUser = LocalUserFactory.markAsSynced(user, result.value.id);
      await this.repository.saveUserToLocal(syncedUser);
      this.logger.d(TAG, `Created user synced with ID ${result.value.id}`);
      return true;
    }

    await this.repository.updateSyncStatus(user.id, SyncStatus.SYNC_FAILED, 'Create failed');
    return false;
  }

  private async syncUpdate(user: LocalUser): Promise<boolean> {
    const result = await this.repository.updateUserOnNetwork({
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      avatar: user.avatar
    });

    if (ResultFactory.isSuccess(result)) {
      await this.repository.updateSyncStatus(user.id, SyncStatus.SYNCED);
      this.logger.d(TAG, `Updated user ${user.id} synced`);
      return true;
    }

    await this.repository.updateSyncStatus(user.id, SyncStatus.SYNC_FAILED, 'Update failed');
    return false;
  }

  private async syncDelete(user: LocalUser): Promise<boolean> {
    const result = await this.repository.deleteUserFromNetwork(user.id);

    if (ResultFactory.isSuccess(result)) {
      await this.repository.deleteUserFromLocal(user.id);
      this.logger.d(TAG, `Deleted user ${user.id} synced`);
      return true;
    }

    if (result.error.code === 'E2001') {
      await this.repository.deleteUserFromLocal(user.id);
      return true;
    }

    await this.repository.updateSyncStatus(user.id, SyncStatus.SYNC_FAILED, 'Delete failed');
    return false;
  }

  private async retrySync(user: LocalUser): Promise<boolean> {
    this.logger.d(TAG, `Retrying sync for user ${user.id}, attempt ${user.syncAttempts + 1}`);

    if (user.id < 0) {
      return await this.syncCreate(user);
    }

    return await this.syncUpdate(user);
  }

  private async updatePendingCount(): Promise<void> {
    const result = await this.repository.getPendingSyncUsers();
    if (ResultFactory.isSuccess(result)) {
      this.updateState({ pendingCount: result.value.length });
    }
  }

  async scheduleBackgroundSync(): Promise<void> {
    // TODO: Use HarmonyOS WorkScheduler for proper background scheduling
    if (this.syncTimeoutId !== null) {
      clearTimeout(this.syncTimeoutId);
    }

    this.syncTimeoutId = setTimeout(async () => {
      this.logger.d(TAG, 'Background sync triggered');
      await this.triggerSync();
    }, this.syncIntervalMs) as unknown as number;

    this.logger.d(TAG, `Background sync scheduled in ${this.syncIntervalMs}ms`);
  }

  private updateState(partial: Partial<SyncState>): void {
    this.syncState = { ...this.syncState, ...partial };

    this.callbacks.forEach(callback => {
      try {
        callback({ ...this.syncState });
      } catch (error) {
        this.logger.e(TAG, `Error in sync callback: ${error}`);
      }
    });
  }

  @preDestroy()
  destroy(): void {
    if (this.networkUnsubscribe) {
      this.networkUnsubscribe();
      this.networkUnsubscribe = null;
    }

    if (this.syncTimeoutId !== null) {
      clearTimeout(this.syncTimeoutId);
      this.syncTimeoutId = null;
    }

    this.callbacks.clear();
    this.logger.d(TAG, 'SyncManagerService destroyed');
  }
}
