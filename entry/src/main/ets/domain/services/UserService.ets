import { User, CreateUserRequest, UpdateUserRequest, PaginatedUsers, LocalUser } from '../models/User';
import { Result } from '../models/Result';
import { AppError } from '../models/AppError';

/**
 * Domain service interface for user operations.
 * Defines the contract for user-related business operations.
 * This is a pure domain interface with no implementation details.
 */
export interface IUserService {
  /**
   * Gets a paginated list of users
   * @param page - Page number (1-indexed)
   * @param forceRefresh - Whether to force a network refresh
   * @returns Paginated list of users
   */
  getUsers(page: number, forceRefresh?: boolean): Promise<Result<PaginatedUsers, AppError>>;

  /**
   * Gets a single user by ID
   * @param userId - The user's ID
   * @returns The user or an error
   */
  getUserById(userId: number): Promise<Result<User, AppError>>;

  /**
   * Creates a new user
   * @param request - The create user request
   * @returns The created user or an error
   */
  createUser(request: CreateUserRequest): Promise<Result<User, AppError>>;

  /**
   * Updates an existing user
   * @param request - The update user request
   * @returns The updated user or an error
   */
  updateUser(request: UpdateUserRequest): Promise<Result<User, AppError>>;

  /**
   * Deletes a user
   * @param userId - The user's ID
   * @returns Success or an error
   */
  deleteUser(userId: number): Promise<Result<void, AppError>>;

  /**
   * Searches users by name or email
   * @param query - Search query string
   * @returns List of matching users
   */
  searchUsers(query: string): Promise<Result<User[], AppError>>;

  /**
   * Gets users pending synchronization
   * @returns List of users needing sync
   */
  getPendingSyncUsers(): Promise<Result<LocalUser[], AppError>>;

  /**
   * Triggers manual sync for pending changes
   * @returns Number of successfully synced items
   */
  syncPendingChanges(): Promise<Result<number, AppError>>;
}

/**
 * User service events for reactive updates
 */
export enum UserServiceEvent {
  USERS_UPDATED = 'users_updated',
  USER_CREATED = 'user_created',
  USER_UPDATED = 'user_updated',
  USER_DELETED = 'user_deleted',
  SYNC_STARTED = 'sync_started',
  SYNC_COMPLETED = 'sync_completed',
  SYNC_FAILED = 'sync_failed'
}

/**
 * User service event payload
 */
export interface UserServiceEventPayload {
  readonly event: UserServiceEvent;
  readonly userId?: number;
  readonly data?: User | User[];
  readonly error?: AppError;
}
