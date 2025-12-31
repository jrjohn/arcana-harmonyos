/**
 * Injectable User Repository Service
 * Implements IUserRepositoryService interface for DI container
 * Follows offline-first pattern with local database as single source of truth
 */

import { injectable, inject, preDestroy } from '../../core/di/decorators';
import {
  IUserRepositoryService,
  IUserApiService,
  IUserLocalDataSource,
  ILogger,
  INetworkMonitor
} from '../../core/di/interfaces';
import { TYPES } from '../../core/di/tokens';
import {
  User,
  CreateUserRequest,
  UpdateUserRequest,
  PaginatedUsers,
  LocalUser,
  SyncStatus,
  LocalUserFactory
} from '../../domain/models/User';
import { Result, ResultFactory } from '../../domain/models/Result';
import { AppError, AppErrorFactory } from '../../domain/models/AppError';
import { LruCache } from '../cache/LruCache';
import { ApiConfig } from '../api/ApiConfig';

const TAG = 'UserRepositoryService';

/**
 * Injectable user repository service implementation
 */
@injectable()
export class UserRepositoryService implements IUserRepositoryService {
  private apiService: IUserApiService;
  private localDataSource: IUserLocalDataSource;
  private logger: ILogger;
  private networkMonitor?: INetworkMonitor;

  private pageCache: LruCache<number, PaginatedUsers>;
  private userCache: LruCache<number, User>;
  private pageCacheTimestamps: Map<number, number>;

  constructor(
    apiService: IUserApiService,
    localDataSource: IUserLocalDataSource,
    logger: ILogger
  ) {
    this.apiService = apiService;
    this.localDataSource = localDataSource;
    this.logger = logger;

    this.pageCache = new LruCache(20, ApiConfig.CACHE_TTL, 'pageCache');
    this.userCache = new LruCache(100, ApiConfig.CACHE_TTL, 'userCache');
    this.pageCacheTimestamps = new Map();

    this.logger.d(TAG, 'UserRepositoryService initialized');
  }

  /**
   * Sets the network monitor (for checking connectivity)
   */
  setNetworkMonitor(monitor: INetworkMonitor): void {
    this.networkMonitor = monitor;
  }

  async initialize(): Promise<void> {
    await this.localDataSource.initialize();
    this.logger.d(TAG, 'Repository data sources initialized');
  }

  @preDestroy()
  destroy(): void {
    this.pageCache.clear();
    this.userCache.clear();
    this.logger.d(TAG, 'Repository destroyed');
  }

  // ===== High-Level Operations (Offline-First) =====

  async getUsers(page: number, forceRefresh: boolean = false): Promise<Result<PaginatedUsers, AppError>> {
    this.logger.d(TAG, `getUsers page=${page}, forceRefresh=${forceRefresh}`);

    // Check memory cache first
    if (!forceRefresh && this.isPageCacheValid(page)) {
      const cached = this.pageCache.get(page);
      if (cached) {
        this.logger.d(TAG, 'Returning from memory cache');
        return ResultFactory.success(cached);
      }
    }

    // Check if online
    const isOnline = await this.checkNetworkAvailable();

    if (isOnline) {
      const networkResult = await this.fetchUsersFromNetwork(page);

      if (ResultFactory.isSuccess(networkResult)) {
        await this.setLastSyncTime(Date.now());
        return networkResult;
      }

      this.logger.w(TAG, 'Network failed, falling back to local data');
    }

    // Return local data
    return this.getLocalPaginatedUsers(page);
  }

  async getUser(userId: number, forceRefresh: boolean = false): Promise<Result<User, AppError>> {
    this.logger.d(TAG, `getUser userId=${userId}`);

    // Check memory cache
    if (!forceRefresh) {
      const cached = this.userCache.get(userId);
      if (cached) {
        this.logger.d(TAG, 'Returning from memory cache');
        return ResultFactory.success(cached);
      }
    }

    // Check if online
    const isOnline = await this.checkNetworkAvailable();

    if (isOnline) {
      const networkResult = await this.apiService.getUser(userId);
      if (ResultFactory.isSuccess(networkResult)) {
        const localUser = LocalUserFactory.fromUser(networkResult.value);
        await this.localDataSource.saveUser(localUser);
        this.userCache.put(userId, networkResult.value);
        return networkResult;
      }
    }

    // Try local
    const localUser = await this.localDataSource.getUser(userId);
    if (localUser) {
      const user: User = {
        id: localUser.id,
        email: localUser.email,
        firstName: localUser.firstName,
        lastName: localUser.lastName,
        avatar: localUser.avatar
      };
      return ResultFactory.success(user);
    }

    return ResultFactory.failure(AppErrorFactory.apiNotFound(`User ${userId}`));
  }

  async createUser(request: CreateUserRequest): Promise<Result<User, AppError>> {
    this.logger.d(TAG, 'Creating user');

    // Create local user first (optimistic)
    const pendingUser = LocalUserFactory.createPending(
      request.email,
      request.firstName,
      request.lastName,
      request.avatar
    );

    await this.localDataSource.saveUser(pendingUser);
    this.invalidateAllCache();

    // Check if online
    const isOnline = await this.checkNetworkAvailable();

    if (isOnline) {
      const networkResult = await this.createUserOnNetwork(request);

      if (ResultFactory.isSuccess(networkResult)) {
        // Update local with server ID
        await this.localDataSource.deleteUser(pendingUser.id);
        const syncedUser = LocalUserFactory.markAsSynced(pendingUser, networkResult.value.id);
        await this.localDataSource.saveUser(syncedUser);
        this.invalidateAllCache();

        return networkResult;
      }

      this.logger.w(TAG, 'Network create failed, user saved locally for sync');
    }

    // Return locally created user
    const user: User = {
      id: pendingUser.id,
      email: pendingUser.email,
      firstName: pendingUser.firstName,
      lastName: pendingUser.lastName,
      avatar: pendingUser.avatar
    };

    return ResultFactory.success(user);
  }

  async updateUser(request: UpdateUserRequest): Promise<Result<User, AppError>> {
    this.logger.d(TAG, `Updating user ${request.id}`);

    // Get current local user
    const currentUser = await this.localDataSource.getUser(request.id);
    if (!currentUser) {
      return ResultFactory.failure(AppErrorFactory.apiNotFound(`User ${request.id}`));
    }

    // Update local first (optimistic)
    const updatedLocalUser: LocalUser = {
      ...currentUser,
      email: request.email,
      firstName: request.firstName,
      lastName: request.lastName,
      avatar: request.avatar,
      syncStatus: SyncStatus.PENDING_UPDATE,
      updatedAt: Date.now()
    };

    await this.localDataSource.saveUser(updatedLocalUser);
    this.userCache.remove(request.id);
    this.invalidateAllCache();

    // Check if online
    const isOnline = await this.checkNetworkAvailable();

    if (isOnline) {
      const networkResult = await this.updateUserOnNetwork(request);

      if (ResultFactory.isSuccess(networkResult)) {
        const syncedUser = LocalUserFactory.markAsSynced(updatedLocalUser);
        await this.localDataSource.saveUser(syncedUser);
        this.userCache.put(request.id, networkResult.value);

        return networkResult;
      }

      this.logger.w(TAG, 'Network update failed, user saved locally for sync');
    }

    // Return optimistic update
    const user: User = {
      id: updatedLocalUser.id,
      email: updatedLocalUser.email,
      firstName: updatedLocalUser.firstName,
      lastName: updatedLocalUser.lastName,
      avatar: updatedLocalUser.avatar
    };

    return ResultFactory.success(user);
  }

  async deleteUser(userId: number): Promise<Result<void, AppError>> {
    this.logger.d(TAG, `Deleting user ${userId}`);

    // Get current local user
    const localUser = await this.localDataSource.getUser(userId);
    if (localUser) {
      // Mark for deletion locally
      const markedUser = LocalUserFactory.markForDeletion(localUser);
      await this.localDataSource.saveUser(markedUser);
    }

    // Remove from caches
    this.userCache.remove(userId);
    this.invalidateAllCache();

    // Check if online
    const isOnline = await this.checkNetworkAvailable();

    if (isOnline) {
      const networkResult = await this.deleteUserFromNetwork(userId);

      if (ResultFactory.isSuccess(networkResult)) {
        await this.localDataSource.deleteUser(userId);
        return ResultFactory.success(undefined);
      }

      this.logger.w(TAG, 'Network delete failed, user marked for deletion locally');
    }

    return ResultFactory.success(undefined);
  }

  async searchUsers(query: string): Promise<Result<User[], AppError>> {
    this.logger.d(TAG, `Searching users: ${query}`);

    const allUsers = await this.localDataSource.getAllUsers();
    const lowerQuery = query.toLowerCase();

    const matchingUsers = allUsers
      .filter(u => u.syncStatus !== SyncStatus.PENDING_DELETE)
      .filter(u =>
        u.email.toLowerCase().includes(lowerQuery) ||
        u.firstName.toLowerCase().includes(lowerQuery) ||
        u.lastName.toLowerCase().includes(lowerQuery)
      )
      .map(lu => ({
        id: lu.id,
        email: lu.email,
        firstName: lu.firstName,
        lastName: lu.lastName,
        avatar: lu.avatar
      }));

    return ResultFactory.success(matchingUsers);
  }

  // ===== Remote Operations =====

  async fetchUsersFromNetwork(page: number): Promise<Result<PaginatedUsers, AppError>> {
    this.logger.d(TAG, `Fetching users from network, page=${page}`);

    const result = await this.apiService.getUsers(page);

    if (ResultFactory.isSuccess(result)) {
      // Update local cache with network data
      const localUsers = result.value.users.map(u => LocalUserFactory.fromUser(u));
      await this.localDataSource.saveUsers(localUsers);

      // Update memory cache
      this.pageCache.put(page, result.value);
      this.pageCacheTimestamps.set(page, Date.now());

      // Cache individual users
      result.value.users.forEach(u => this.userCache.put(u.id, u));

      this.logger.d(TAG, `Cached ${result.value.users.length} users for page ${page}`);
    }

    return result;
  }

  async createUserOnNetwork(request: CreateUserRequest): Promise<Result<User, AppError>> {
    this.logger.d(TAG, 'Creating user on network');
    return this.apiService.createUser(request);
  }

  async updateUserOnNetwork(request: UpdateUserRequest): Promise<Result<User, AppError>> {
    this.logger.d(TAG, `Updating user ${request.id} on network`);
    return this.apiService.updateUser(request);
  }

  async deleteUserFromNetwork(userId: number): Promise<Result<void, AppError>> {
    this.logger.d(TAG, `Deleting user ${userId} from network`);
    return this.apiService.deleteUser(userId);
  }

  // ===== Local Operations =====

  async getAllUsersFromLocal(): Promise<Result<LocalUser[], AppError>> {
    try {
      const users = await this.localDataSource.getAllUsers();
      return ResultFactory.success(users);
    } catch (error) {
      return ResultFactory.failure(AppErrorFactory.databaseError('get users', error as Error));
    }
  }

  async saveUserToLocal(user: LocalUser): Promise<Result<LocalUser, AppError>> {
    try {
      await this.localDataSource.saveUser(user);
      this.invalidateAllCache();
      return ResultFactory.success(user);
    } catch (error) {
      return ResultFactory.failure(AppErrorFactory.databaseError('save user', error as Error));
    }
  }

  async deleteUserFromLocal(userId: number): Promise<Result<void, AppError>> {
    try {
      await this.localDataSource.deleteUser(userId);
      this.userCache.remove(userId);
      this.invalidateAllCache();
      return ResultFactory.success(undefined);
    } catch (error) {
      return ResultFactory.failure(AppErrorFactory.databaseError('delete user', error as Error));
    }
  }

  async getPendingSyncUsers(): Promise<Result<LocalUser[], AppError>> {
    try {
      const pendingStatuses = [
        SyncStatus.PENDING_CREATE,
        SyncStatus.PENDING_UPDATE,
        SyncStatus.PENDING_DELETE,
        SyncStatus.SYNC_FAILED
      ];
      const users = await this.localDataSource.getUsersBySyncStatus(pendingStatuses);
      return ResultFactory.success(users);
    } catch (error) {
      return ResultFactory.failure(AppErrorFactory.databaseError('get pending users', error as Error));
    }
  }

  async updateSyncStatus(userId: number, status: SyncStatus, error?: string): Promise<Result<void, AppError>> {
    try {
      const user = await this.localDataSource.getUser(userId);
      if (user) {
        let updatedUser: LocalUser;
        if (status === SyncStatus.SYNC_FAILED && error) {
          updatedUser = LocalUserFactory.markSyncFailed(user, error);
        } else if (status === SyncStatus.SYNCED) {
          updatedUser = LocalUserFactory.markAsSynced(user);
        } else {
          updatedUser = { ...user, syncStatus: status, updatedAt: Date.now() };
        }
        await this.localDataSource.saveUser(updatedUser);
      }
      return ResultFactory.success(undefined);
    } catch (error) {
      return ResultFactory.failure(AppErrorFactory.databaseError('update sync status', error as Error));
    }
  }

  // ===== Cache Operations =====

  invalidateAllCache(): void {
    this.pageCache.clear();
    this.pageCacheTimestamps.clear();
    this.logger.d(TAG, 'Invalidated all page caches');
  }

  async getLastSyncTime(): Promise<number | undefined> {
    return this.localDataSource.getLastSyncTime();
  }

  async setLastSyncTime(timestamp: number): Promise<void> {
    await this.localDataSource.setLastSyncTime(timestamp);
  }

  // ===== Private Helpers =====

  private isPageCacheValid(page: number): boolean {
    const timestamp = this.pageCacheTimestamps.get(page);
    if (!timestamp) return false;

    const age = Date.now() - timestamp;
    const isValid = age < ApiConfig.CACHE_TTL;

    this.logger.d(TAG, `Page ${page} cache valid: ${isValid} (age: ${age}ms)`);
    return isValid;
  }

  private async checkNetworkAvailable(): Promise<boolean> {
    if (this.networkMonitor) {
      return this.networkMonitor.isNetworkAvailable();
    }
    // Fallback: assume online
    return true;
  }

  private async getLocalPaginatedUsers(page: number): Promise<Result<PaginatedUsers, AppError>> {
    try {
      const allUsers = await this.localDataSource.getAllUsers();
      const filteredUsers = allUsers.filter(u => u.syncStatus !== SyncStatus.PENDING_DELETE);

      const startIndex = (page - 1) * ApiConfig.PAGE_SIZE;
      const pageUsers = filteredUsers.slice(startIndex, startIndex + ApiConfig.PAGE_SIZE);

      const paginatedUsers: PaginatedUsers = {
        users: pageUsers.map(lu => ({
          id: lu.id,
          email: lu.email,
          firstName: lu.firstName,
          lastName: lu.lastName,
          avatar: lu.avatar
        })),
        page,
        perPage: ApiConfig.PAGE_SIZE,
        total: filteredUsers.length,
        totalPages: Math.ceil(filteredUsers.length / ApiConfig.PAGE_SIZE)
      };

      this.logger.d(TAG, 'Returning local data');
      return ResultFactory.success(paginatedUsers);
    } catch (error) {
      return ResultFactory.failure(AppErrorFactory.databaseError('get users', error as Error));
    }
  }
}
