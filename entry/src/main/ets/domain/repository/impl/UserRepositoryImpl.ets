import { common } from '@kit.AbilityKit';
import {
  User,
  UserImpl,
  CreateUserRequest,
  UpdateUserRequest,
  PaginatedUsers,
  LocalUser,
  SyncStatus,
  LocalUserImpl
} from '../../domain/models/User';
import { Result, Success, Failure } from '../../domain/models/Result';
import { AppError, AppErrorFactory } from '../../domain/models/AppError';
import { IUserRepository } from '../../domain/repository/UserRepository';
import { IUserRepositoryService } from '../../core/di/interfaces';
import { UserApiService } from '../api/UserApiService';
import { UserLocalDataSource } from '../local/UserLocalDataSource';
import { LruCache } from '../cache/LruCache';
import { ObservableCache, ValueUnsubscribe } from '../cache/ObservableCache';
import { ApiConfig } from '../api/ApiConfig';
import { Logger } from '../../core/logging/Logger';
import { NetworkMonitor } from '../../core/network/NetworkMonitor';
import { CacheEventBus } from '../../core/cache/CacheEventBus';

const TAG = 'UserRepositoryImpl';

/**
 * Repository implementation following the offline-first pattern.
 * The local database is the single source of truth.
 * Network data is used to sync and update the local cache.
 */
export class UserRepositoryImpl implements IUserRepository, IUserRepositoryService {
  private apiService: UserApiService;
  private localDataSource: UserLocalDataSource;
  private pageCache: LruCache<number, PaginatedUsers>;
  private userCache: ObservableCache<number, User>;
  private pageCacheTimestamps: Map<number, number>;

  constructor(context: common.UIAbilityContext) {
    this.apiService = new UserApiService();
    this.localDataSource = new UserLocalDataSource(context);
    this.pageCache = new LruCache(20, ApiConfig.CACHE_TTL, 'pageCache');
    this.userCache = new ObservableCache(100, ApiConfig.CACHE_TTL, 'userCache');
    this.pageCacheTimestamps = new Map();

    Logger.d(TAG, 'UserRepository initialized');
  }

  /**
   * Subscribes to changes for a specific user (like Android's getUserFlow)
   * @param userId The user ID to observe
   * @param callback Called when the user changes
   * @returns Unsubscribe function
   */
  subscribeToUser(userId: number, callback: (user: User | undefined) => void): ValueUnsubscribe<User> {
    return this.userCache.subscribeToKey(userId, callback);
  }

  /**
   * Initialize the repository
   */
  async initialize(): Promise<void> {
    await this.localDataSource.initialize();
    Logger.d(TAG, 'Repository data sources initialized');
  }

  // ===== Remote Operations =====

  async fetchUsersFromNetwork(page: number): Promise<Result<PaginatedUsers, AppError>> {
    Logger.d(TAG, `Fetching users from network, page=${page}`);

    const result = await this.apiService.getUsers(page);

    if (result.isSuccess) {
      // Update local cache with network data
      const successResult = result as Success<PaginatedUsers>;
      const localUsers: LocalUser[] = [];
      for (const u of successResult.value.users) {
        localUsers.push(LocalUserImpl.fromUser(u));
      }
      await this.localDataSource.saveUsers(localUsers);

      // Update memory cache
      this.pageCache.put(page, successResult.value);
      this.pageCacheTimestamps.set(page, Date.now());

      // Cache individual users
      for (const u of successResult.value.users) {
        this.userCache.put(u.id, u);
      }

      Logger.d(TAG, `Cached ${successResult.value.users.length} users for page ${page}`);
    }

    return result;
  }

  async fetchUserFromNetwork(userId: number): Promise<Result<User, AppError>> {
    Logger.d(TAG, `Fetching user ${userId} from network`);

    const result = await this.apiService.getUserById(userId);

    if (result.isSuccess) {
      // Update local cache
      const successResult = result as Success<User>;
      const localUser = LocalUserImpl.fromUser(successResult.value);
      await this.localDataSource.saveUser(localUser);

      // Update memory cache
      this.userCache.put(userId, successResult.value);

      Logger.d(TAG, `Cached user ${userId}`);
    }

    return result;
  }

  async createUserOnNetwork(request: CreateUserRequest): Promise<Result<User, AppError>> {
    Logger.d(TAG, `Creating user on network`);
    return this.apiService.createUser(request);
  }

  async updateUserOnNetwork(request: UpdateUserRequest): Promise<Result<User, AppError>> {
    Logger.d(TAG, `Updating user ${request.id} on network`);
    return this.apiService.updateUser(request);
  }

  async deleteUserFromNetwork(userId: number): Promise<Result<void, AppError>> {
    Logger.d(TAG, `Deleting user ${userId} from network`);
    return this.apiService.deleteUser(userId);
  }

  // ===== Local Operations =====

  async getAllUsersFromLocal(): Promise<Result<LocalUser[], AppError>> {
    return this.localDataSource.getAllUsers();
  }

  async getUsersFromLocal(page: number, perPage: number): Promise<Result<LocalUser[], AppError>> {
    return this.localDataSource.getUsersForPage(page, perPage);
  }

  async getUserFromLocal(userId: number): Promise<Result<LocalUser | undefined, AppError>> {
    return this.localDataSource.getUserById(userId);
  }

  async saveUserToLocal(user: LocalUser): Promise<Result<LocalUser, AppError>> {
    const result = await this.localDataSource.saveUser(user);

    if (result.isSuccess) {
      // Invalidate page caches since data changed
      this.invalidateAllCache();
    }

    return result;
  }

  async saveUsersToLocal(users: LocalUser[]): Promise<Result<void, AppError>> {
    return this.localDataSource.saveUsers(users);
  }

  async deleteUserFromLocal(userId: number): Promise<Result<void, AppError>> {
    const result = await this.localDataSource.deleteUser(userId);

    if (result.isSuccess) {
      // Remove from caches
      this.userCache.remove(userId);
      this.invalidateAllCache();
    }

    return result;
  }

  async getPendingSyncUsers(): Promise<Result<LocalUser[], AppError>> {
    return this.localDataSource.getPendingSyncUsers();
  }

  async updateSyncStatus(userId: number, status: SyncStatus, error?: string): Promise<Result<void, AppError>> {
    return this.localDataSource.updateSyncStatus(userId, status, error);
  }

  async clearLocalData(): Promise<Result<void, AppError>> {
    const result = await this.localDataSource.clearAllData();

    if (result.isSuccess) {
      this.pageCache.clear();
      this.userCache.clear();
      this.pageCacheTimestamps.clear();
    }

    return result;
  }

  async getLocalUserCount(): Promise<Result<number, AppError>> {
    return this.localDataSource.getUserCount();
  }

  // ===== Cache Operations =====

  isPageCacheValid(page: number): boolean {
    const timestamp = this.pageCacheTimestamps.get(page);
    if (!timestamp) return false;

    const age = Date.now() - timestamp;
    const isValid = age < ApiConfig.CACHE_TTL;

    Logger.d(TAG, `Page ${page} cache valid: ${isValid} (age: ${age}ms)`);
    return isValid;
  }

  invalidatePageCache(page: number): void {
    this.pageCache.remove(page);
    this.pageCacheTimestamps.delete(page);
    Logger.d(TAG, `Invalidated cache for page ${page}`);
  }

  invalidateAllCache(): void {
    this.pageCache.clear();
    this.pageCacheTimestamps.clear();
    CacheEventBus.emitInvalidateAll();
    Logger.d(TAG, 'Invalidated all page caches');
  }

  async getLastSyncTime(): Promise<number | undefined> {
    return this.localDataSource.getLastSyncTime();
  }

  async setLastSyncTime(timestamp: number): Promise<void> {
    await this.localDataSource.setLastSyncTime(timestamp);
  }

  // ===== High-Level Operations (Offline-First) =====

  /**
   * Gets users with offline-first strategy:
   * 1. Return cached data immediately if available
   * 2. Fetch from network in background
   * 3. If offline, return local data
   */
  async getUsers(page: number, forceRefresh: boolean = false): Promise<Result<PaginatedUsers, AppError>> {
    Logger.d(TAG, `getUsers page=${page}, forceRefresh=${forceRefresh}`);

    // Check memory cache first (fastest)
    if (!forceRefresh && this.isPageCacheValid(page)) {
      const cached = this.pageCache.get(page);
      if (cached) {
        Logger.d(TAG, 'Returning from memory cache');
        return new Success<PaginatedUsers>(cached);
      }
    }

    // Check if online
    const isOnline = await NetworkMonitor.isNetworkAvailable();

    if (isOnline) {
      // Try network first when online
      const networkResult = await this.fetchUsersFromNetwork(page);

      if (networkResult.isSuccess) {
        await this.setLastSyncTime(Date.now());
        return networkResult;
      }

      // Network failed, try local
      Logger.w(TAG, 'Network failed, falling back to local data');
    }

    // Return local data (offline mode or network failure)
    const localResult = await this.getUsersFromLocal(page, ApiConfig.PAGE_SIZE);

    if (localResult.isSuccess) {
      const successLocalResult = localResult as Success<LocalUser[]>;
      const countResult = await this.getLocalUserCount();
      const total = countResult.isSuccess ? (countResult as Success<number>).value : successLocalResult.value.length;

      const users: User[] = [];
      for (const lu of successLocalResult.value) {
        users.push(UserImpl.create(lu.id, lu.email, lu.firstName, lu.lastName, lu.avatar));
      }

      const paginatedUsers: PaginatedUsers = {
        users: users,
        page: page,
        perPage: ApiConfig.PAGE_SIZE,
        total: total,
        totalPages: Math.ceil(total / ApiConfig.PAGE_SIZE)
      };

      Logger.d(TAG, 'Returning local data');
      return new Success<PaginatedUsers>(paginatedUsers);
    }

    return new Failure<AppError>(AppErrorFactory.noConnection());
  }

  /**
   * Gets a single user with offline-first strategy
   */
  async getUser(userId: number): Promise<Result<User, AppError>> {
    Logger.d(TAG, `getUser userId=${userId}`);

    // Check memory cache
    const cached = this.userCache.get(userId);
    if (cached) {
      Logger.d(TAG, 'Returning from memory cache');
      return new Success<User>(cached);
    }

    // Check if online
    const isOnline = await NetworkMonitor.isNetworkAvailable();

    if (isOnline) {
      const networkResult = await this.fetchUserFromNetwork(userId);
      if (networkResult.isSuccess) {
        return networkResult;
      }
    }

    // Try local
    const localResult = await this.getUserFromLocal(userId);
    if (localResult.isSuccess) {
      const successLocalResult = localResult as Success<LocalUser | undefined>;
      if (successLocalResult.value) {
        const lu = successLocalResult.value;
        const user = UserImpl.create(lu.id, lu.email, lu.firstName, lu.lastName, lu.avatar);
        return new Success<User>(user);
      }
    }

    return new Failure<AppError>(AppErrorFactory.apiNotFound(`User ${userId}`));
  }

  /**
   * Searches users locally by query
   */
  async searchUsers(query: string): Promise<Result<User[], AppError>> {
    Logger.d(TAG, `searchUsers query=${query}`);

    const localResult = await this.getAllUsersFromLocal();
    if (localResult.isFailure) {
      return new Failure<AppError>((localResult as Failure<AppError>).error);
    }

    const successResult = localResult as Success<LocalUser[]>;
    const lowerQuery = query.toLowerCase();
    const filteredUsers: User[] = [];

    for (const lu of successResult.value) {
      if (lu.firstName.toLowerCase().includes(lowerQuery) ||
          lu.lastName.toLowerCase().includes(lowerQuery) ||
          lu.email.toLowerCase().includes(lowerQuery)) {
        filteredUsers.push(UserImpl.create(lu.id, lu.email, lu.firstName, lu.lastName, lu.avatar));
      }
    }

    Logger.d(TAG, `Found ${filteredUsers.length} users matching query`);
    return new Success<User[]>(filteredUsers);
  }

  /**
   * Creates a user with optimistic update
   */
  async createUser(request: CreateUserRequest): Promise<Result<User, AppError>> {
    Logger.d(TAG, 'Creating user');

    // Create local user first (optimistic)
    const pendingUser = LocalUserImpl.createPending(
      request.email,
      request.firstName,
      request.lastName,
      request.avatar
    );

    await this.saveUserToLocal(pendingUser);

    // Check if online
    const isOnline = await NetworkMonitor.isNetworkAvailable();

    if (isOnline) {
      const networkResult = await this.createUserOnNetwork(request);

      if (networkResult.isSuccess) {
        // Update local with server ID
        const successNetworkResult = networkResult as Success<User>;
        const syncedUser = LocalUserImpl.markAsSynced(pendingUser, successNetworkResult.value.id);
        await this.localDataSource.deleteUser(pendingUser.id);
        await this.saveUserToLocal(syncedUser);
        this.invalidateAllCache();

        // Emit user created event
        CacheEventBus.emitUserCreated(successNetworkResult.value.id);

        return networkResult;
      }

      // Network failed, keep as pending
      Logger.w(TAG, 'Network create failed, user saved locally for sync');
    }

    // Return the locally created user
    const user = UserImpl.create(
      pendingUser.id,
      pendingUser.email,
      pendingUser.firstName,
      pendingUser.lastName,
      pendingUser.avatar
    );

    // Emit user created event for optimistic local creation
    CacheEventBus.emitUserCreated(pendingUser.id);

    return new Success<User>(user);
  }

  /**
   * Updates a user with optimistic update
   */
  async updateUser(request: UpdateUserRequest): Promise<Result<User, AppError>> {
    Logger.d(TAG, `Updating user ${request.id}`);

    // Get current local user
    const localResult = await this.getUserFromLocal(request.id);
    if (localResult.isFailure) {
      const failureResult = localResult as Failure<AppError>;
      return new Failure<AppError>(failureResult.error);
    }

    const successLocalResult = localResult as Success<LocalUser | undefined>;
    const currentUser = successLocalResult.value;
    if (!currentUser) {
      return new Failure<AppError>(AppErrorFactory.apiNotFound(`User ${request.id}`));
    }

    // Update local first (optimistic)
    const updatedLocalUser = new LocalUserImpl(
      currentUser.id,
      request.email,
      request.firstName,
      request.lastName,
      request.avatar,
      SyncStatus.PENDING_UPDATE,
      currentUser.localId,
      currentUser.createdAt,
      Date.now(),
      currentUser.syncAttempts,
      currentUser.syncError,
      currentUser.version + 1  // Increment version on update
    );

    await this.saveUserToLocal(updatedLocalUser);
    this.userCache.remove(request.id);

    // Check if online
    const isOnline = await NetworkMonitor.isNetworkAvailable();

    if (isOnline) {
      const networkResult = await this.updateUserOnNetwork(request);

      if (networkResult.isSuccess) {
        // Mark as synced
        const successNetworkResult = networkResult as Success<User>;
        const syncedUser = LocalUserImpl.markAsSynced(updatedLocalUser);
        await this.saveUserToLocal(syncedUser);
        this.userCache.put(request.id, successNetworkResult.value);

        // Emit user updated event
        CacheEventBus.emitUserUpdated(request.id);

        return networkResult;
      }

      Logger.w(TAG, 'Network update failed, user saved locally for sync');
    }

    // Return optimistic update
    const user = UserImpl.create(
      updatedLocalUser.id,
      updatedLocalUser.email,
      updatedLocalUser.firstName,
      updatedLocalUser.lastName,
      updatedLocalUser.avatar
    );

    // Emit user updated event for optimistic local update
    CacheEventBus.emitUserUpdated(request.id);

    return new Success<User>(user);
  }

  /**
   * Deletes a user with optimistic update
   */
  async deleteUser(userId: number): Promise<Result<void, AppError>> {
    Logger.d(TAG, `Deleting user ${userId}`);

    // Get current local user
    const localResult = await this.getUserFromLocal(userId);
    if (localResult.isSuccess) {
      const successLocalResult = localResult as Success<LocalUser | undefined>;
      if (successLocalResult.value) {
        // Mark for deletion locally
        const markedUser = LocalUserImpl.markForDeletion(successLocalResult.value);
        await this.saveUserToLocal(markedUser);
      }
    }

    // Remove from caches
    this.userCache.remove(userId);
    this.invalidateAllCache();

    // Check if online
    const isOnline = await NetworkMonitor.isNetworkAvailable();

    if (isOnline) {
      const networkResult = await this.deleteUserFromNetwork(userId);

      if (networkResult.isSuccess) {
        // Actually delete from local
        await this.deleteUserFromLocal(userId);

        // Emit user deleted event
        CacheEventBus.emitUserDeleted(userId);

        return new Success<void>(undefined);
      }

      Logger.w(TAG, 'Network delete failed, user marked for deletion locally');
    }

    // Emit user deleted event for optimistic local deletion
    CacheEventBus.emitUserDeleted(userId);

    return new Success<void>(undefined);
  }

  /**
   * Cleanup resources
   */
  destroy(): void {
    this.apiService.destroy();
    this.pageCache.clear();
    this.userCache.clear();
    Logger.d(TAG, 'Repository destroyed');
  }
}
