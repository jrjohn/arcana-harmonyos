import { UserRepositoryImpl } from '../../data/repository/UserRepositoryImpl';
import { LocalUser, SyncStatus, LocalUserImpl } from '../../domain/models/User';
import { Success, Failure } from '../../domain/models/Result';
import { NetworkMonitor, NetworkStatus, UnsubscribeCallback } from '../network/NetworkMonitor';
import { AppError } from '../../domain/models/AppError';
import { Logger } from '../logging/Logger';

const TAG = 'SyncManager';

/**
 * Sync state for tracking sync progress
 */
export interface SyncState {
  isSyncing: boolean;
  pendingCount: number;
  lastSyncTime: number | undefined;
  lastSyncError: string | undefined;
}

/**
 * Sync state change callback
 */
export type SyncStateCallback = (state: SyncState) => void;

/**
 * Unsubscribe callback class for sync state
 */
export class SyncUnsubscribeCallback {
  private callback: SyncStateCallback;
  private callbacks: Set<SyncStateCallback>;

  constructor(callback: SyncStateCallback, callbacks: Set<SyncStateCallback>) {
    this.callback = callback;
    this.callbacks = callbacks;
  }

  unsubscribe(): void {
    this.callbacks.delete(this.callback);
  }
}

/**
 * Manages offline-first synchronization of user data.
 * Handles queuing, retrying, and conflict resolution.
 */
export class SyncManager {
  private repository: UserRepositoryImpl;
  private callbacks: Set<SyncStateCallback> = new Set();
  private syncInProgress: boolean = false;
  private syncState: SyncState;
  private networkUnsubscribe: UnsubscribeCallback | null = null;
  private syncTimeoutId: number | null = null;

  private initSyncState(): void {
    this.syncState = {
      isSyncing: false,
      pendingCount: 0,
      lastSyncTime: undefined,
      lastSyncError: undefined
    };
  }

  // Retry configuration
  private readonly maxRetries = 3;
  private readonly retryDelayMs = 2000;
  private readonly syncIntervalMs = 30000; // 30 seconds

  constructor(repository: UserRepositoryImpl) {
    this.repository = repository;
    this.syncState = {
      isSyncing: false,
      pendingCount: 0,
      lastSyncTime: undefined,
      lastSyncError: undefined
    };
    this.setupNetworkListener();
    this.updatePendingCount();
  }

  /**
   * Sets up network connectivity listener
   */
  private setupNetworkListener(): void {
    this.networkUnsubscribe = NetworkMonitor.subscribe((state) => {
      Logger.d(TAG, `Network state changed: ${state.status}`);

      if (state.status === NetworkStatus.AVAILABLE) {
        // Network restored, trigger sync
        this.triggerSync();
      }
    });
  }

  /**
   * Subscribes to sync state changes
   */
  subscribe(callback: SyncStateCallback): SyncUnsubscribeCallback {
    this.callbacks.add(callback);
    callback(this.copySyncState(this.syncState));

    return new SyncUnsubscribeCallback(callback, this.callbacks);
  }

  /**
   * Gets current sync state
   */
  getState(): SyncState {
    return this.copySyncState(this.syncState);
  }

  /**
   * Creates a copy of the sync state
   */
  private copySyncState(state: SyncState): SyncState {
    const copy: SyncState = {
      isSyncing: state.isSyncing,
      pendingCount: state.pendingCount,
      lastSyncTime: state.lastSyncTime,
      lastSyncError: state.lastSyncError
    };
    return copy;
  }

  /**
   * Triggers a sync operation
   */
  async triggerSync(): Promise<void> {
    if (this.syncInProgress) {
      Logger.d(TAG, 'Sync already in progress');
      return;
    }

    const isOnline = await NetworkMonitor.isNetworkAvailable();
    if (!isOnline) {
      Logger.d(TAG, 'Network not available, skipping sync');
      return;
    }

    await this.performSync();
  }

  /**
   * Performs the actual sync operation
   */
  private async performSync(): Promise<void> {
    this.syncInProgress = true;
    this.syncState.isSyncing = true;
    this.notifySyncStateChanged();
    Logger.i(TAG, 'Starting sync...');

    const endTimer = Logger.time(TAG, 'Sync operation');

    try {
      // Get pending items
      const pendingResult = await this.repository.getPendingSyncUsers();
      if (pendingResult.isFailure) {
        throw new Error('Failed to get pending users');
      }

      const successResult = pendingResult as Success<LocalUser[]>;
      const pendingUsers = successResult.value;
      Logger.d(TAG, `Found ${pendingUsers.length} items to sync`);

      let successCount = 0;
      let failureCount = 0;

      // Process each pending item
      for (const user of pendingUsers) {
        const success = await this.syncUser(user);
        if (success) {
          successCount++;
        } else {
          failureCount++;
        }
      }

      // Update last sync time
      await this.repository.setLastSyncTime(Date.now());

      Logger.i(TAG, `Sync completed: ${successCount} success, ${failureCount} failed`);

      this.syncState.isSyncing = false;
      this.syncState.lastSyncTime = Date.now();
      this.syncState.lastSyncError = failureCount > 0 ? `${failureCount} items failed to sync` : undefined;
      this.notifySyncStateChanged();
    } catch (error) {
      Logger.e(TAG, `Sync failed: ${error}`);
      this.syncState.isSyncing = false;
      this.syncState.lastSyncError = String(error);
      this.notifySyncStateChanged();
    } finally {
      this.syncInProgress = false;
      await this.updatePendingCount();
      endTimer.end();
    }
  }

  /**
   * Syncs a single user
   */
  private async syncUser(user: LocalUser): Promise<boolean> {
    Logger.d(TAG, `Syncing user ${user.id} with status ${user.syncStatus}`);

    try {
      switch (user.syncStatus) {
        case SyncStatus.PENDING_CREATE:
          return await this.syncCreate(user);

        case SyncStatus.PENDING_UPDATE:
          return await this.syncUpdate(user);

        case SyncStatus.PENDING_DELETE:
          return await this.syncDelete(user);

        case SyncStatus.SYNC_FAILED:
          // Retry based on previous status
          if (user.syncAttempts < this.maxRetries) {
            return await this.retrySync(user);
          }
          Logger.w(TAG, `User ${user.id} exceeded max retries`);
          return false;

        default:
          return true;
      }
    } catch (error) {
      Logger.e(TAG, `Error syncing user ${user.id}: ${error}`);
      await this.repository.updateSyncStatus(user.id, SyncStatus.SYNC_FAILED, String(error));
      return false;
    }
  }

  /**
   * Syncs a pending create operation
   */
  private async syncCreate(user: LocalUser): Promise<boolean> {
    const result = await this.repository.createUserOnNetwork({
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      avatar: user.avatar
    });

    if (result.isSuccess) {
      // Delete the temporary local user and save with real ID
      const successResult = result as Success<import('../../domain/models/User').User>;
      await this.repository.deleteUserFromLocal(user.id);
      const syncedUser = LocalUserImpl.markAsSynced(user, successResult.value.id);
      await this.repository.saveUserToLocal(syncedUser);
      Logger.d(TAG, `Created user synced with ID ${successResult.value.id}`);
      return true;
    }

    await this.repository.updateSyncStatus(user.id, SyncStatus.SYNC_FAILED, 'Create failed');
    return false;
  }

  /**
   * Syncs a pending update operation
   */
  private async syncUpdate(user: LocalUser): Promise<boolean> {
    const result = await this.repository.updateUserOnNetwork({
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      avatar: user.avatar
    });

    if (result.isSuccess) {
      await this.repository.updateSyncStatus(user.id, SyncStatus.SYNCED);
      Logger.d(TAG, `Updated user ${user.id} synced`);
      return true;
    }

    await this.repository.updateSyncStatus(user.id, SyncStatus.SYNC_FAILED, 'Update failed');
    return false;
  }

  /**
   * Syncs a pending delete operation
   */
  private async syncDelete(user: LocalUser): Promise<boolean> {
    const result = await this.repository.deleteUserFromNetwork(user.id);

    if (result.isSuccess) {
      // Actually remove from local storage
      await this.repository.deleteUserFromLocal(user.id);
      Logger.d(TAG, `Deleted user ${user.id} synced`);
      return true;
    }

    // If 404, the user was already deleted on server
    const failureResult = result as Failure<AppError>;
    if (failureResult.error.code === 'E2001') {
      await this.repository.deleteUserFromLocal(user.id);
      return true;
    }

    await this.repository.updateSyncStatus(user.id, SyncStatus.SYNC_FAILED, 'Delete failed');
    return false;
  }

  /**
   * Retries a failed sync
   */
  private async retrySync(user: LocalUser): Promise<boolean> {
    Logger.d(TAG, `Retrying sync for user ${user.id}, attempt ${user.syncAttempts + 1}`);

    // Determine original operation based on ID
    if (user.id < 0) {
      return await this.syncCreate(user);
    }

    // For existing users, we don't know the original operation
    // Default to update
    return await this.syncUpdate(user);
  }

  /**
   * Updates pending count
   */
  private async updatePendingCount(): Promise<void> {
    const result = await this.repository.getPendingSyncUsers();
    if (result.isSuccess) {
      const successResult = result as Success<LocalUser[]>;
      this.syncState.pendingCount = successResult.value.length;
      this.notifySyncStateChanged();
    }
  }

  /**
   * Schedules background sync
   */
  async scheduleBackgroundSync(): Promise<void> {
    // In HarmonyOS, you would use WorkScheduler for background tasks
    // For now, we'll use a simple timeout
    if (this.syncTimeoutId !== null) {
      clearTimeout(this.syncTimeoutId);
    }

    const timeoutId: number = setTimeout(async () => {
      Logger.d(TAG, 'Background sync triggered');
      await this.triggerSync();
    }, this.syncIntervalMs);
    this.syncTimeoutId = timeoutId;

    Logger.d(TAG, `Background sync scheduled in ${this.syncIntervalMs}ms`);
  }

  /**
   * Notifies subscribers of state changes
   */
  private notifySyncStateChanged(): void {
    const stateCopy = this.copySyncState(this.syncState);
    this.callbacks.forEach(callback => {
      try {
        callback(stateCopy);
      } catch (error) {
        Logger.e(TAG, `Error in sync callback: ${error}`);
      }
    });
  }

  /**
   * Cleanup resources
   */
  destroy(): void {
    if (this.networkUnsubscribe) {
      this.networkUnsubscribe.unsubscribe();
      this.networkUnsubscribe = null;
    }

    if (this.syncTimeoutId !== null) {
      clearTimeout(this.syncTimeoutId);
      this.syncTimeoutId = null;
    }

    this.callbacks.clear();
    Logger.d(TAG, 'SyncManager destroyed');
  }
}
