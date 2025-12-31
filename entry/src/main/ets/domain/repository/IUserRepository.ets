import { User, CreateUserRequest, UpdateUserRequest, PaginatedUsers, LocalUser, SyncStatus } from '../models/User';
import { Result } from '../models/Result';
import { AppError } from '../models/AppError';

/**
 * Repository interface for user data access.
 * Follows the repository pattern to abstract data sources.
 * This interface defines the contract that the data layer must implement.
 */
export interface IUserRepository {
  // ===== Remote Operations =====

  /**
   * Fetches users from the remote API
   * @param page - Page number
   * @returns Paginated users from network
   */
  fetchUsersFromNetwork(page: number): Promise<Result<PaginatedUsers, AppError>>;

  /**
   * Fetches a single user from the remote API
   * @param userId - User ID
   * @returns User from network
   */
  fetchUserFromNetwork(userId: number): Promise<Result<User, AppError>>;

  /**
   * Creates a user on the remote API
   * @param request - Create request
   * @returns Created user
   */
  createUserOnNetwork(request: CreateUserRequest): Promise<Result<User, AppError>>;

  /**
   * Updates a user on the remote API
   * @param request - Update request
   * @returns Updated user
   */
  updateUserOnNetwork(request: UpdateUserRequest): Promise<Result<User, AppError>>;

  /**
   * Deletes a user from the remote API
   * @param userId - User ID
   * @returns Success or error
   */
  deleteUserFromNetwork(userId: number): Promise<Result<void, AppError>>;

  // ===== Local Operations =====

  /**
   * Gets all users from local storage
   * @returns All cached users
   */
  getAllUsersFromLocal(): Promise<Result<LocalUser[], AppError>>;

  /**
   * Gets users for a specific page from local storage
   * @param page - Page number
   * @param perPage - Items per page
   * @returns Paginated local users
   */
  getUsersFromLocal(page: number, perPage: number): Promise<Result<LocalUser[], AppError>>;

  /**
   * Gets a single user from local storage
   * @param userId - User ID
   * @returns Local user or error
   */
  getUserFromLocal(userId: number): Promise<Result<LocalUser | undefined, AppError>>;

  /**
   * Saves a user to local storage
   * @param user - User to save
   * @returns Saved user
   */
  saveUserToLocal(user: LocalUser): Promise<Result<LocalUser, AppError>>;

  /**
   * Saves multiple users to local storage
   * @param users - Users to save
   * @returns Success or error
   */
  saveUsersToLocal(users: LocalUser[]): Promise<Result<void, AppError>>;

  /**
   * Deletes a user from local storage
   * @param userId - User ID
   * @returns Success or error
   */
  deleteUserFromLocal(userId: number): Promise<Result<void, AppError>>;

  /**
   * Gets users pending synchronization
   * @returns Users needing sync
   */
  getPendingSyncUsers(): Promise<Result<LocalUser[], AppError>>;

  /**
   * Updates the sync status of a user
   * @param userId - User ID
   * @param status - New sync status
   * @returns Success or error
   */
  updateSyncStatus(userId: number, status: SyncStatus, error?: string): Promise<Result<void, AppError>>;

  /**
   * Clears all local user data
   * @returns Success or error
   */
  clearLocalData(): Promise<Result<void, AppError>>;

  /**
   * Gets the total count of users in local storage
   * @returns User count
   */
  getLocalUserCount(): Promise<Result<number, AppError>>;

  // ===== Cache Operations =====

  /**
   * Checks if page data is cached and still valid
   * @param page - Page number
   * @returns Whether cache is valid
   */
  isPageCacheValid(page: number): boolean;

  /**
   * Invalidates cache for a specific page
   * @param page - Page number
   */
  invalidatePageCache(page: number): void;

  /**
   * Invalidates all cached data
   */
  invalidateAllCache(): void;

  /**
   * Gets the last sync timestamp
   * @returns Timestamp of last sync
   */
  getLastSyncTime(): Promise<number | undefined>;

  /**
   * Updates the last sync timestamp
   * @param timestamp - Sync timestamp
   */
  setLastSyncTime(timestamp: number): Promise<void>;
}
