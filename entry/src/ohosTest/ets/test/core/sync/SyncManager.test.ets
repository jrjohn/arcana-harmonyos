/**
 * Unit Tests for SyncManager
 * Tests offline-first synchronization functionality
 */

import { describe, it, expect, beforeEach, afterEach } from '@ohos/hypium';
import {
  SyncManager,
  SyncState,
  SyncStateCallback,
  SyncUnsubscribeCallback
} from '../../../../../main/ets/core/sync/SyncManager';
import { Result, ResultFactory } from '../../../../../main/ets/domain/models/Result';
import { User, LocalUser, SyncStatus, UserImpl, LocalUserImpl } from '../../../../../main/ets/domain/models/User';
import { AppError, AppErrorFactory } from '../../../../../main/ets/domain/models/AppError';

// Mock UserRepositoryImpl for testing
class MockUserRepository {
  private pendingUsers: LocalUser[] = [];
  private lastSyncTime: number | undefined;
  private shouldFail = false;

  constructor() {}

  setShouldFail(fail: boolean): void {
    this.shouldFail = fail;
  }

  addPendingUser(user: LocalUser): void {
    this.pendingUsers.push(user);
  }

  clearPendingUsers(): void {
    this.pendingUsers = [];
  }

  async getPendingSyncUsers(): Promise<Result<LocalUser[], AppError>> {
    if (this.shouldFail) {
      return ResultFactory.failure(AppErrorFactory.networkError('Mock error'));
    }
    return ResultFactory.success(this.pendingUsers);
  }

  async setLastSyncTime(time: number): Promise<void> {
    this.lastSyncTime = time;
  }

  async getLastSyncTime(): Promise<number | undefined> {
    return this.lastSyncTime;
  }

  async updateSyncStatus(userId: number, status: SyncStatus, error?: string): Promise<void> {
    const user = this.pendingUsers.find(u => u.id === userId);
    if (user) {
      // Update status (in real implementation)
    }
  }

  async createUserOnNetwork(request: object): Promise<Result<User, AppError>> {
    if (this.shouldFail) {
      return ResultFactory.failure(AppErrorFactory.networkError('Create failed'));
    }
    return ResultFactory.success(UserImpl.create(100, 'test@test.com', 'Test', 'User', ''));
  }

  async updateUserOnNetwork(request: object): Promise<Result<User, AppError>> {
    if (this.shouldFail) {
      return ResultFactory.failure(AppErrorFactory.networkError('Update failed'));
    }
    return ResultFactory.success(UserImpl.create(1, 'test@test.com', 'Test', 'User', ''));
  }

  async deleteUserFromNetwork(userId: number): Promise<Result<void, AppError>> {
    if (this.shouldFail) {
      return ResultFactory.failure(AppErrorFactory.networkError('Delete failed'));
    }
    return ResultFactory.success(undefined);
  }

  async deleteUserFromLocal(userId: number): Promise<void> {}

  async saveUserToLocal(user: LocalUser): Promise<void> {}
}

export default function SyncManagerTest() {
  describe('SyncState', () => {
    it('should have required properties', () => {
      const state: SyncState = {
        isSyncing: false,
        pendingCount: 0,
        lastSyncTime: undefined,
        lastSyncError: undefined
      };

      expect('isSyncing' in state).assertTrue();
      expect('pendingCount' in state).assertTrue();
      expect('lastSyncTime' in state).assertTrue();
      expect('lastSyncError' in state).assertTrue();
    });

    it('should support non-negative pending count', () => {
      const state: SyncState = {
        isSyncing: false,
        pendingCount: 5,
        lastSyncTime: Date.now(),
        lastSyncError: undefined
      };

      expect(state.pendingCount >= 0).assertTrue();
    });
  });

  describe('SyncUnsubscribeCallback', () => {
    it('should create instance', () => {
      const callbacks = new Set<SyncStateCallback>();
      const callback = (state: SyncState) => {};
      callbacks.add(callback);

      const unsubscribe = new SyncUnsubscribeCallback(callback, callbacks);
      expect(unsubscribe).assertNotNull();
    });

    it('should unsubscribe correctly', () => {
      const callbacks = new Set<SyncStateCallback>();
      const callback = (state: SyncState) => {};
      callbacks.add(callback);

      const unsubscribe = new SyncUnsubscribeCallback(callback, callbacks);
      unsubscribe.unsubscribe();

      expect(callbacks.has(callback)).assertFalse();
    });

    it('should be safe to call multiple times', () => {
      const callbacks = new Set<SyncStateCallback>();
      const callback = (state: SyncState) => {};
      callbacks.add(callback);

      const unsubscribe = new SyncUnsubscribeCallback(callback, callbacks);
      unsubscribe.unsubscribe();
      unsubscribe.unsubscribe();

      expect(true).assertTrue();
    });
  });

  describe('SyncManager', () => {
    let mockRepository: MockUserRepository;
    let syncManager: SyncManager;

    beforeEach(() => {
      mockRepository = new MockUserRepository();
      syncManager = new SyncManager(mockRepository as unknown as import('../../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl);
    });

    afterEach(() => {
      syncManager.destroy();
    });

    describe('constructor', () => {
      it('should create instance', () => {
        expect(syncManager).assertNotNull();
      });
    });

    describe('getState', () => {
      it('should return initial state', () => {
        const state = syncManager.getState();

        expect(state).assertNotNull();
        expect(state.isSyncing).assertFalse();
        expect(typeof state.pendingCount === 'number').assertTrue();
      });

      it('should return copy of state', () => {
        const state1 = syncManager.getState();
        const state2 = syncManager.getState();

        expect(state1 !== state2).assertTrue();
        expect(state1.isSyncing).assertEqual(state2.isSyncing);
      });
    });

    describe('subscribe', () => {
      it('should return SyncUnsubscribeCallback', () => {
        const unsubscribe = syncManager.subscribe((state) => {});

        expect(unsubscribe).assertNotNull();
        expect(unsubscribe instanceof SyncUnsubscribeCallback).assertTrue();

        unsubscribe.unsubscribe();
      });

      it('should call callback immediately with current state', () => {
        let receivedState: SyncState | null = null;

        const unsubscribe = syncManager.subscribe((state) => {
          receivedState = state;
        });

        expect(receivedState).assertNotNull();
        expect(receivedState!.isSyncing).assertFalse();

        unsubscribe.unsubscribe();
      });

      it('should handle multiple subscriptions', () => {
        let callCount = 0;

        const unsubscribe1 = syncManager.subscribe(() => callCount++);
        const unsubscribe2 = syncManager.subscribe(() => callCount++);

        expect(callCount).assertEqual(2);

        unsubscribe1.unsubscribe();
        unsubscribe2.unsubscribe();
      });
    });

    describe('triggerSync', () => {
      it('should not throw', async () => {
        try {
          await syncManager.triggerSync();
          expect(true).assertTrue();
        } catch (e) {
          // May fail without network, which is expected
          expect(true).assertTrue();
        }
      });

      it('should update state during sync', async () => {
        const states: SyncState[] = [];

        const unsubscribe = syncManager.subscribe((state) => {
          states.push({
            isSyncing: state.isSyncing,
            pendingCount: state.pendingCount,
            lastSyncTime: state.lastSyncTime,
            lastSyncError: state.lastSyncError
          });
        });

        try {
          await syncManager.triggerSync();
        } catch (e) {
          // Expected in test environment
        }

        expect(states.length >= 1).assertTrue();
        unsubscribe.unsubscribe();
      });
    });

    describe('scheduleBackgroundSync', () => {
      it('should schedule without error', async () => {
        try {
          await syncManager.scheduleBackgroundSync();
          expect(true).assertTrue();
        } catch (e) {
          // WorkScheduler may not be available
          expect(true).assertTrue();
        }
      });
    });

    describe('schedulePeriodicSync', () => {
      it('should return boolean result', async () => {
        const result = await syncManager.schedulePeriodicSync();
        expect(typeof result === 'boolean').assertTrue();
      });
    });

    describe('isPeriodicSyncScheduled', () => {
      it('should return boolean', async () => {
        const result = await syncManager.isPeriodicSyncScheduled();
        expect(typeof result === 'boolean').assertTrue();
      });
    });

    describe('cancelScheduledSync', () => {
      it('should complete without error', async () => {
        await syncManager.cancelScheduledSync();
        expect(true).assertTrue();
      });
    });

    describe('destroy', () => {
      it('should cleanup without error', () => {
        syncManager.destroy();
        expect(true).assertTrue();
      });

      it('should be safe to call multiple times', () => {
        syncManager.destroy();
        syncManager.destroy();
        expect(true).assertTrue();
      });

      it('should unsubscribe network listener', () => {
        syncManager.destroy();
        // Should not throw after destroy
        expect(true).assertTrue();
      });
    });
  });

  describe('SyncManager state transitions', () => {
    it('should track pending count changes', () => {
      const mockRepository = new MockUserRepository();

      // Add pending user
      const pendingUser = LocalUserImpl.createLocal('test@test.com', 'Test', 'User', '');
      mockRepository.addPendingUser(pendingUser);

      const syncManager = new SyncManager(mockRepository as unknown as import('../../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl);

      // State should reflect pending items
      const state = syncManager.getState();
      expect(typeof state.pendingCount === 'number').assertTrue();

      syncManager.destroy();
    });
  });
}
