/**
 * UserServiceImpl - Domain service implementation for user operations.
 * Implements IUserService by delegating to IUserRepositoryService.
 * Acts as the orchestration layer between the presentation and data layers.
 */

import { injectable } from '../../../core/di/decorators';
import { IUserRepositoryService } from '../../../core/di/interfaces';
import { IUserService } from '../UserService';
import {
  User,
  CreateUserRequest,
  UpdateUserRequest,
  PaginatedUsers,
  LocalUser
} from '../../models/User';
import { Result, Success, Failure } from '../../models/Result';
import { AppError } from '../../models/AppError';
import { Logger } from '../../../core/logging/Logger';

const TAG = 'UserServiceImpl';

/**
 * Concrete implementation of the IUserService domain service interface.
 * Delegates all data access to IUserRepositoryService, applying any
 * domain-level logic or orchestration needed between repository calls.
 */
@injectable()
export class UserServiceImpl implements IUserService {
  private userRepository: IUserRepositoryService;

  constructor(userRepository: IUserRepositoryService) {
    this.userRepository = userRepository;
    Logger.d(TAG, 'UserServiceImpl initialized');
  }

  /**
   * Gets a paginated list of users with offline-first strategy.
   */
  async getUsers(page: number, forceRefresh?: boolean): Promise<Result<PaginatedUsers, AppError>> {
    Logger.d(TAG, `getUsers page=${page}, forceRefresh=${forceRefresh}`);
    return this.userRepository.getUsers(page, forceRefresh);
  }

  /**
   * Gets a single user by ID with offline-first strategy.
   */
  async getUserById(userId: number): Promise<Result<User, AppError>> {
    Logger.d(TAG, `getUserById userId=${userId}`);
    return this.userRepository.getUser(userId);
  }

  /**
   * Creates a new user (optimistic local create, queued for network sync).
   */
  async createUser(request: CreateUserRequest): Promise<Result<User, AppError>> {
    Logger.d(TAG, 'createUser');
    return this.userRepository.createUser(request);
  }

  /**
   * Updates an existing user (optimistic local update, queued for network sync).
   */
  async updateUser(request: UpdateUserRequest): Promise<Result<User, AppError>> {
    Logger.d(TAG, `updateUser userId=${request.id}`);
    return this.userRepository.updateUser(request);
  }

  /**
   * Deletes a user (optimistic local delete, queued for network sync).
   */
  async deleteUser(userId: number): Promise<Result<void, AppError>> {
    Logger.d(TAG, `deleteUser userId=${userId}`);
    return this.userRepository.deleteUser(userId);
  }

  /**
   * Searches users by name or email (local search).
   */
  async searchUsers(query: string): Promise<Result<User[], AppError>> {
    Logger.d(TAG, `searchUsers query="${query}"`);
    return this.userRepository.searchUsers(query);
  }

  /**
   * Gets users pending synchronization.
   */
  async getPendingSyncUsers(): Promise<Result<LocalUser[], AppError>> {
    Logger.d(TAG, 'getPendingSyncUsers');
    return this.userRepository.getPendingSyncUsers();
  }

  /**
   * Returns the number of items currently pending synchronization.
   * Actual network sync is coordinated by SyncManager at the application layer.
   */
  async syncPendingChanges(): Promise<Result<number, AppError>> {
    Logger.d(TAG, 'syncPendingChanges');
    const pendingResult = await this.userRepository.getPendingSyncUsers();
    if (pendingResult.isFailure) {
      const failureResult = pendingResult as Failure<AppError>;
      return new Failure<AppError>(failureResult.error);
    }
    const successResult = pendingResult as Success<LocalUser[]>;
    const pendingCount = successResult.value.length;
    Logger.d(TAG, `syncPendingChanges: ${pendingCount} items pending`);
    return new Success<number>(pendingCount);
  }
}
