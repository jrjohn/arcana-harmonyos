/**
 * Integration Tests - Data Flow
 * Tests data flow through the architecture layers
 */

import { describe, it, expect, beforeEach, afterEach } from '@ohos/hypium';
import { User, UserImpl, LocalUser, LocalUserImpl, SyncStatus } from '../../../../main/ets/domain/models/User';
import { Result, ResultFactory } from '../../../../main/ets/domain/models/Result';
import { AppError, AppErrorFactory, ErrorCode } from '../../../../main/ets/domain/models/AppError';
import { LruCache, CacheManager } from '../../../../main/ets/data/cache/LruCache';
import { ApiConfig } from '../../../../main/ets/data/api/ApiConfig';
import { UserDto, UserDtoMapper } from '../../../../main/ets/data/api/dto/UserDto';
import { BindingScope } from '../../../../main/ets/core/di/types';

export default function DataFlowTest() {
  describe('API to Domain Mapping', () => {
    it('should map UserDto to User', () => {
      const dto: UserDto = {
        id: 1,
        email: 'dto@example.com',
        first_name: 'First',
        last_name: 'Last',
        avatar: 'avatar.png'
      };

      const user = UserDtoMapper.toDomain(dto);

      expect(user.id).assertEqual(1);
      expect(user.email).assertEqual('dto@example.com');
      expect(user.firstName).assertEqual('First');
      expect(user.lastName).assertEqual('Last');
      expect(user.avatar).assertEqual('avatar.png');
    });

    it('should map User to UserDto', () => {
      const user = UserImpl.create(2, 'user@example.com', 'User', 'Name', 'pic.png');

      const dto = UserDtoMapper.toDto(user);

      expect(dto.id).assertEqual(2);
      expect(dto.email).assertEqual('user@example.com');
      expect(dto.first_name).assertEqual('User');
      expect(dto.last_name).assertEqual('Name');
    });

    it('should handle list mapping', () => {
      const dtos: UserDto[] = [
        { id: 1, email: 'a@example.com', first_name: 'A', last_name: 'User', avatar: '' },
        { id: 2, email: 'b@example.com', first_name: 'B', last_name: 'User', avatar: '' }
      ];

      const users = UserDtoMapper.toDomainList(dtos);

      expect(users.length).assertEqual(2);
      expect(users[0].email).assertEqual('a@example.com');
      expect(users[1].email).assertEqual('b@example.com');
    });
  });

  describe('Cache Layer Flow', () => {
    let userCache: LruCache<string, User>;

    beforeEach(() => {
      userCache = new LruCache<string, User>(50, 300000);
    });

    afterEach(() => {
      userCache.clear();
    });

    it('should cache API response', () => {
      // Simulate API response
      const user = UserImpl.create(1, 'cached@example.com', 'Cached', 'User', '');

      // Cache result
      userCache.put('user_1', user);

      // Verify cache hit
      const cached = userCache.get('user_1');
      expect(cached).assertNotNull();
      expect(cached?.id).assertEqual(1);
    });

    it('should invalidate cache on update', () => {
      const user = UserImpl.create(1, 'update@example.com', 'Original', 'User', '');
      userCache.put('user_1', user);

      // Invalidate on update
      userCache.remove('user_1');

      expect(userCache.get('user_1')).assertNull();
    });

    it('should provide cache statistics', () => {
      const user1 = UserImpl.create(1, 'stat1@example.com', 'Stat', 'One', '');
      const user2 = UserImpl.create(2, 'stat2@example.com', 'Stat', 'Two', '');

      userCache.put('user_1', user1);
      userCache.put('user_2', user2);

      const size = userCache.size();
      expect(size).assertEqual(2);
    });
  });

  describe('Local Storage Flow', () => {
    it('should convert User to LocalUser', () => {
      const user = UserImpl.create(1, 'local@example.com', 'Local', 'User', '');

      const localUser = LocalUserImpl.fromUser(user);

      expect(localUser.id).assertEqual(1);
      expect(localUser.email).assertEqual('local@example.com');
      expect(localUser.syncStatus).assertEqual(SyncStatus.SYNCED);
    });

    it('should track sync status transitions', () => {
      // Create local user
      let user = LocalUserImpl.createLocal('track@example.com', 'Track', 'User', '');
      expect(user.syncStatus).assertEqual(SyncStatus.PENDING_CREATE);

      // Sync succeeds
      user = LocalUserImpl.markAsSynced(user, 100);
      expect(user.syncStatus).assertEqual(SyncStatus.SYNCED);

      // Mark for update
      user = LocalUserImpl.markForUpdate(user);
      expect(user.syncStatus).assertEqual(SyncStatus.PENDING_UPDATE);

      // Mark for delete
      user = LocalUserImpl.markForDelete(user);
      expect(user.syncStatus).assertEqual(SyncStatus.PENDING_DELETE);
    });
  });

  describe('Error Propagation', () => {
    it('should propagate network errors', () => {
      const error = AppErrorFactory.networkError('Connection refused');

      expect(error.code).assertEqual(ErrorCode.NETWORK_ERROR);
      expect(error.isRetryable).assertTrue();
    });

    it('should propagate API errors', () => {
      const error = AppErrorFactory.apiServerError('Internal server error');

      expect(error.code).assertEqual(ErrorCode.API_SERVER_ERROR);
    });

    it('should propagate validation errors', () => {
      const error = AppErrorFactory.validationError('Invalid input');

      expect(error.code).assertEqual(ErrorCode.VALIDATION_ERROR);
      expect(error.isRetryable).assertFalse();
    });

    it('should handle unknown errors', () => {
      const error = AppErrorFactory.unknownError('Something went wrong');

      expect(error.code).assertEqual(ErrorCode.UNKNOWN_ERROR);
    });
  });

  describe('Result Chain Flow', () => {
    it('should chain successful results', () => {
      const user = UserImpl.create(1, 'chain@example.com', 'Chain', 'User', '');

      // Simulate repository layer
      const repoResult = ResultFactory.success(user);
      expect(repoResult.isSuccess).assertTrue();

      // Use case layer transforms
      const useCaseResult = repoResult.getOrNull();
      expect(useCaseResult?.email).assertEqual('chain@example.com');
    });

    it('should short-circuit on failure', () => {
      const error = AppErrorFactory.apiNotFound('User');
      const result: Result<User, AppError> = ResultFactory.failure(error);

      // Check failure propagates
      expect(result.isFailure).assertTrue();

      // Default should be returned
      const defaultUser = UserImpl.create(0, 'default@example.com', 'Default', 'User', '');
      const value = result.getOrDefault(defaultUser);
      expect(value.id).assertEqual(0);
    });
  });

  describe('DI Configuration Flow', () => {
    it('should define valid binding scopes', () => {
      expect(BindingScope.SINGLETON).assertEqual('singleton');
      expect(BindingScope.TRANSIENT).assertEqual('transient');
      expect(BindingScope.REQUEST).assertEqual('request');
    });
  });

  describe('API Configuration', () => {
    it('should have base URL configured', () => {
      expect(ApiConfig.BASE_URL).assertNotNull();
      expect(ApiConfig.BASE_URL.length > 0).assertTrue();
    });

    it('should have endpoints defined', () => {
      expect(ApiConfig.endpoints.users).assertNotNull();
      expect(ApiConfig.endpoints.user(1).includes('1')).assertTrue();
    });

    it('should have timeout configured', () => {
      expect(ApiConfig.TIMEOUT_MS > 0).assertTrue();
    });

    it('should have retry configuration', () => {
      expect(ApiConfig.MAX_RETRIES >= 0).assertTrue();
      expect(ApiConfig.RETRY_DELAY_MS > 0).assertTrue();
    });
  });

  describe('Multi-Layer Cache Strategy', () => {
    it('should implement LRU eviction', () => {
      const cache = new LruCache<number, string>(3, 60000);

      cache.put(1, 'first');
      cache.put(2, 'second');
      cache.put(3, 'third');

      // Access first to make it recently used
      cache.get(1);

      // Add fourth, should evict second (least recently used)
      cache.put(4, 'fourth');

      expect(cache.get(1)).assertEqual('first');
      expect(cache.get(2)).assertNull();
      expect(cache.get(3)).assertEqual('third');
      expect(cache.get(4)).assertEqual('fourth');

      cache.clear();
    });

    it('should support TTL expiration', async () => {
      const cache = new LruCache<number, string>(10, 50); // 50ms TTL

      cache.put(1, 'expires');

      // Item exists immediately
      expect(cache.get(1)).assertEqual('expires');

      // Wait for expiration
      await new Promise<void>(resolve => setTimeout(resolve, 100));

      // Item should be expired
      expect(cache.get(1)).assertNull();

      cache.clear();
    });
  });

  describe('Offline Queue Management', () => {
    it('should queue pending operations by type', () => {
      const pending: LocalUser[] = [];

      // Add create
      pending.push(LocalUserImpl.createLocal('create@example.com', 'Create', 'User', ''));

      // Add update
      const existing = LocalUserImpl.fromUser(UserImpl.create(1, 'update@example.com', 'Update', 'User', ''));
      pending.push(LocalUserImpl.markForUpdate(existing));

      // Add delete
      const toDelete = LocalUserImpl.fromUser(UserImpl.create(2, 'delete@example.com', 'Delete', 'User', ''));
      pending.push(LocalUserImpl.markForDelete(toDelete));

      // Verify queue
      expect(pending.length).assertEqual(3);

      const creates = pending.filter(u => u.syncStatus === SyncStatus.PENDING_CREATE);
      const updates = pending.filter(u => u.syncStatus === SyncStatus.PENDING_UPDATE);
      const deletes = pending.filter(u => u.syncStatus === SyncStatus.PENDING_DELETE);

      expect(creates.length).assertEqual(1);
      expect(updates.length).assertEqual(1);
      expect(deletes.length).assertEqual(1);
    });

    it('should order operations correctly', () => {
      // Deletes should be processed before creates to avoid conflicts
      const operations = [
        { type: SyncStatus.PENDING_CREATE, priority: 2 },
        { type: SyncStatus.PENDING_UPDATE, priority: 1 },
        { type: SyncStatus.PENDING_DELETE, priority: 0 }
      ];

      operations.sort((a, b) => a.priority - b.priority);

      expect(operations[0].type).assertEqual(SyncStatus.PENDING_DELETE);
      expect(operations[1].type).assertEqual(SyncStatus.PENDING_UPDATE);
      expect(operations[2].type).assertEqual(SyncStatus.PENDING_CREATE);
    });
  });
}
