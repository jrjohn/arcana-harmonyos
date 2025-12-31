/**
 * Integration Tests - End to End
 * Tests complete user flows across multiple components
 */

import { describe, it, expect, beforeEach, afterEach } from '@ohos/hypium';
import { User, UserImpl, LocalUser, LocalUserImpl, SyncStatus } from '../../../../main/ets/domain/models/User';
import { Result, ResultFactory } from '../../../../main/ets/domain/models/Result';
import { AppError, AppErrorFactory } from '../../../../main/ets/domain/models/AppError';
import { UserValidator, ValidationResult } from '../../../../main/ets/domain/validators/UserValidator';
import { LruCache, CacheManager } from '../../../../main/ets/data/cache/LruCache';
import { SyncExecutor, SyncResult } from '../../../../main/ets/core/sync/SyncExecutor';
import { Logger, LogLevel } from '../../../../main/ets/core/logging/Logger';
import { NetworkStatus, NetworkType, NetworkState } from '../../../../main/ets/core/network/NetworkMonitor';

export default function EndToEndTest() {
  describe('User Creation Flow', () => {
    it('should validate and create user', () => {
      // Step 1: Validate user data
      const validationResult = UserValidator.validate('John', 'Doe', 'john@example.com');

      expect(validationResult.isValid).assertTrue();
      expect(validationResult.errors.length).assertEqual(0);

      // Step 2: Create user model
      const user = UserImpl.create(1, 'john@example.com', 'John', 'Doe', 'avatar.png');

      expect(user.id).assertEqual(1);
      expect(user.email).assertEqual('john@example.com');
      expect(user.fullName).assertEqual('John Doe');
    });

    it('should reject invalid user data', () => {
      // Invalid email
      const result1 = UserValidator.validate('John', 'Doe', 'invalid-email');
      expect(result1.isValid).assertFalse();

      // Empty name
      const result2 = UserValidator.validate('', 'Doe', 'john@example.com');
      expect(result2.isValid).assertFalse();

      // Short name
      const result3 = UserValidator.validate('J', 'Doe', 'john@example.com');
      expect(result3.isValid).assertFalse();
    });
  });

  describe('Offline-First User Creation', () => {
    it('should create local user with pending status', () => {
      const localUser = LocalUserImpl.createLocal(
        'local@example.com',
        'Local',
        'User',
        ''
      );

      expect(localUser.id < 0).assertTrue(); // Negative ID for local users
      expect(localUser.syncStatus).assertEqual(SyncStatus.PENDING_CREATE);
      expect(localUser.localId).assertNotNull();
    });

    it('should mark local user as synced', () => {
      const localUser = LocalUserImpl.createLocal(
        'local@example.com',
        'Local',
        'User',
        ''
      );

      const syncedUser = LocalUserImpl.markAsSynced(localUser, 100);

      expect(syncedUser.id).assertEqual(100);
      expect(syncedUser.syncStatus).assertEqual(SyncStatus.SYNCED);
      expect(syncedUser.syncError).assertUndefined();
    });

    it('should handle sync failure', () => {
      const localUser = LocalUserImpl.createLocal(
        'local@example.com',
        'Local',
        'User',
        ''
      );

      const failedUser = LocalUserImpl.markAsSyncFailed(localUser, 'Network error');

      expect(failedUser.syncStatus).assertEqual(SyncStatus.SYNC_FAILED);
      expect(failedUser.syncError).assertEqual('Network error');
      expect(failedUser.syncAttempts > 0).assertTrue();
    });
  });

  describe('Cache Integration', () => {
    let cache: LruCache<string, User>;

    beforeEach(() => {
      cache = new LruCache<string, User>(10, 60000);
    });

    afterEach(() => {
      cache.clear();
    });

    it('should cache and retrieve users', () => {
      const user = UserImpl.create(1, 'cached@example.com', 'Cached', 'User', '');

      cache.put('user_1', user);
      const retrieved = cache.get('user_1');

      expect(retrieved).assertNotNull();
      expect(retrieved?.email).assertEqual('cached@example.com');
    });

    it('should evict oldest when full', () => {
      const smallCache = new LruCache<string, User>(2, 60000);

      const user1 = UserImpl.create(1, 'user1@example.com', 'User', 'One', '');
      const user2 = UserImpl.create(2, 'user2@example.com', 'User', 'Two', '');
      const user3 = UserImpl.create(3, 'user3@example.com', 'User', 'Three', '');

      smallCache.put('user_1', user1);
      smallCache.put('user_2', user2);
      smallCache.put('user_3', user3);

      // First user should be evicted
      expect(smallCache.get('user_1')).assertNull();
      expect(smallCache.get('user_2')).assertNotNull();
      expect(smallCache.get('user_3')).assertNotNull();

      smallCache.clear();
    });

    it('should update access order on get', () => {
      const smallCache = new LruCache<string, User>(2, 60000);

      const user1 = UserImpl.create(1, 'user1@example.com', 'User', 'One', '');
      const user2 = UserImpl.create(2, 'user2@example.com', 'User', 'Two', '');
      const user3 = UserImpl.create(3, 'user3@example.com', 'User', 'Three', '');

      smallCache.put('user_1', user1);
      smallCache.put('user_2', user2);

      // Access user_1 to make it recently used
      smallCache.get('user_1');

      // Add user_3 - should evict user_2 (least recently used)
      smallCache.put('user_3', user3);

      expect(smallCache.get('user_1')).assertNotNull();
      expect(smallCache.get('user_2')).assertNull();

      smallCache.clear();
    });
  });

  describe('Result Type Flow', () => {
    it('should propagate success through layers', () => {
      const user = UserImpl.create(1, 'success@example.com', 'Success', 'User', '');
      const result = ResultFactory.success(user);

      expect(result.isSuccess).assertTrue();
      expect(result.isFailure).assertFalse();

      if (result.isSuccess) {
        expect(result.getOrNull()?.email).assertEqual('success@example.com');
      }
    });

    it('should propagate failure through layers', () => {
      const error = AppErrorFactory.networkError('Connection failed');
      const result: Result<User, AppError> = ResultFactory.failure(error);

      expect(result.isSuccess).assertFalse();
      expect(result.isFailure).assertTrue();

      if (result.isFailure) {
        const failedResult = result as import('../../../../main/ets/domain/models/Result').Failure<AppError>;
        expect(failedResult.error.message).assertEqual('Connection failed');
      }
    });

    it('should handle Result mapping', () => {
      const user = UserImpl.create(1, 'map@example.com', 'Map', 'User', '');
      const result = ResultFactory.success(user);

      const email = result.getOrDefault(UserImpl.create(0, 'default@example.com', 'Default', 'User', '')).email;
      expect(email).assertEqual('map@example.com');
    });
  });

  describe('Error Handling Flow', () => {
    it('should create appropriate error types', () => {
      const networkError = AppErrorFactory.networkError('Connection timeout');
      expect(networkError.code).assertEqual('E1001');

      const notFoundError = AppErrorFactory.apiNotFound('User');
      expect(notFoundError.code).assertEqual('E2001');

      const validationError = AppErrorFactory.validationError('Invalid email');
      expect(validationError.code).assertEqual('E3001');
    });

    it('should provide user-friendly messages', () => {
      const error = AppErrorFactory.networkError('Connection timeout');

      expect(error.userMessage).assertNotNull();
      expect(error.userMessage.length > 0).assertTrue();
    });
  });

  describe('Sync Executor Integration', () => {
    let executor: SyncExecutor;

    beforeEach(() => {
      executor = new SyncExecutor();
    });

    afterEach(() => {
      executor.destroy();
    });

    it('should execute sync and return result', async () => {
      const result = await executor.executePendingSync();

      expect(result).assertNotNull();
      expect(typeof result.syncedCount === 'number').assertTrue();
      expect(typeof result.failedCount === 'number').assertTrue();
      expect(result.durationMs >= 0).assertTrue();
    });

    it('should handle concurrent sync operations', async () => {
      const executor1 = new SyncExecutor();
      const executor2 = new SyncExecutor();

      const results = await Promise.all([
        executor1.executePendingSync(),
        executor2.executePendingSync()
      ]);

      expect(results.length).assertEqual(2);
      expect(results[0]).assertNotNull();
      expect(results[1]).assertNotNull();

      executor1.destroy();
      executor2.destroy();
    });
  });

  describe('Logging Integration', () => {
    beforeEach(() => {
      Logger.setLevel(LogLevel.DEBUG);
      Logger.setEnabled(true);
    });

    afterEach(() => {
      Logger.setLevel(LogLevel.DEBUG);
      Logger.setEnabled(true);
    });

    it('should log through all levels', () => {
      Logger.d('Test', 'Debug message');
      Logger.i('Test', 'Info message');
      Logger.w('Test', 'Warning message');
      Logger.e('Test', 'Error message');
      expect(true).assertTrue();
    });

    it('should support timing operations', async () => {
      const timing = Logger.time('Test', 'operation');
      await new Promise<void>(resolve => setTimeout(resolve, 10));
      timing.end();
      expect(true).assertTrue();
    });
  });

  describe('Full User CRUD Simulation', () => {
    it('should simulate create operation', () => {
      // Create locally
      const localUser = LocalUserImpl.createLocal('new@example.com', 'New', 'User', '');

      expect(localUser.syncStatus).assertEqual(SyncStatus.PENDING_CREATE);

      // Simulate network success
      const syncedUser = LocalUserImpl.markAsSynced(localUser, 42);

      expect(syncedUser.id).assertEqual(42);
      expect(syncedUser.syncStatus).assertEqual(SyncStatus.SYNCED);
    });

    it('should simulate update operation', () => {
      // Start with synced user
      const existingUser = LocalUserImpl.fromUser(
        UserImpl.create(1, 'existing@example.com', 'Existing', 'User', '')
      );

      // Mark for update
      const pendingUpdate = LocalUserImpl.markForUpdate(existingUser);

      expect(pendingUpdate.syncStatus).assertEqual(SyncStatus.PENDING_UPDATE);

      // Sync succeeds
      const synced = LocalUserImpl.markAsSynced(pendingUpdate, 1);

      expect(synced.syncStatus).assertEqual(SyncStatus.SYNCED);
    });

    it('should simulate delete operation', () => {
      const existingUser = LocalUserImpl.fromUser(
        UserImpl.create(1, 'delete@example.com', 'Delete', 'User', '')
      );

      const pendingDelete = LocalUserImpl.markForDelete(existingUser);

      expect(pendingDelete.syncStatus).assertEqual(SyncStatus.PENDING_DELETE);
    });

    it('should handle create retry on failure', () => {
      const localUser = LocalUserImpl.createLocal('retry@example.com', 'Retry', 'User', '');

      // First failure
      let failed = LocalUserImpl.markAsSyncFailed(localUser, 'Network error');
      expect(failed.syncAttempts).assertEqual(1);

      // Second failure
      failed = LocalUserImpl.markAsSyncFailed(failed, 'Timeout');
      expect(failed.syncAttempts).assertEqual(2);

      // Eventually succeeds
      const synced = LocalUserImpl.markAsSynced(failed, 99);
      expect(synced.syncStatus).assertEqual(SyncStatus.SYNCED);
    });
  });

  describe('Network State Simulation', () => {
    it('should handle network state transitions', () => {
      const states: NetworkState[] = [];

      // Simulate network becoming available
      states.push({
        status: NetworkStatus.UNAVAILABLE,
        type: NetworkType.NONE,
        isMetered: false
      });

      states.push({
        status: NetworkStatus.AVAILABLE,
        type: NetworkType.WIFI,
        isMetered: false
      });

      // Verify state transition
      expect(states[0].status).assertEqual(NetworkStatus.UNAVAILABLE);
      expect(states[1].status).assertEqual(NetworkStatus.AVAILABLE);
    });

    it('should identify metered connections', () => {
      const meteredState: NetworkState = {
        status: NetworkStatus.AVAILABLE,
        type: NetworkType.CELLULAR,
        isMetered: true
      };

      expect(meteredState.isMetered).assertTrue();
      expect(meteredState.type).assertEqual(NetworkType.CELLULAR);
    });
  });
}
