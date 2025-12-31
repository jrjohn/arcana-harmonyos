/**
 * Service Interfaces for Dependency Injection
 * Defines contracts for all injectable services
 */

import { common } from '@kit.AbilityKit';
import { NetworkState, NetworkStatus, NetworkStateCallback } from '../network/NetworkMonitor';
import { SyncState, SyncStateCallback } from '../sync/SyncManager';
import { LogLevel } from '../logging/Logger';
import { AnalyticsEvent } from '../analytics/AnalyticsService';
import { User, CreateUserRequest, UpdateUserRequest, PaginatedUsers, LocalUser, SyncStatus } from '../../domain/models/User';
import { Result } from '../../domain/models/Result';
import { AppError } from '../../domain/models/AppError';

// ===== Network Monitor Interface =====

/**
 * Network monitoring service interface
 */
export interface INetworkMonitor {
  /**
   * Initializes the network monitor
   */
  initialize(): Promise<void>;

  /**
   * Checks if network is currently available
   */
  isNetworkAvailable(): Promise<boolean>;

  /**
   * Gets current network state
   */
  getNetworkState(): Promise<NetworkState>;

  /**
   * Subscribes to network state changes
   * @returns Unsubscribe function
   */
  subscribe(callback: NetworkStateCallback): () => void;

  /**
   * Cleanup resources
   */
  destroy(): void;
}

// ===== Logger Interface =====

/**
 * Logging service interface
 */
export interface ILogger {
  /**
   * Sets the minimum log level
   */
  setLevel(level: LogLevel): void;

  /**
   * Enables or disables logging
   */
  setEnabled(enabled: boolean): void;

  /**
   * Debug level log
   */
  d(tag: string, message: string, ...args: Object[]): void;

  /**
   * Info level log
   */
  i(tag: string, message: string, ...args: Object[]): void;

  /**
   * Warning level log
   */
  w(tag: string, message: string, ...args: Object[]): void;

  /**
   * Error level log
   */
  e(tag: string, message: string, ...args: Object[]): void;

  /**
   * Fatal level log
   */
  f(tag: string, message: string, ...args: Object[]): void;

  /**
   * Logs with specified level
   */
  log(level: LogLevel, tag: string, message: string, ...args: Object[]): void;

  /**
   * Logs an exception with stack trace
   */
  exception(tag: string, message: string, error: Error): void;

  /**
   * Logs JSON data (pretty printed in debug)
   */
  json(tag: string, label: string, data: object): void;

  /**
   * Performance timing log
   * @returns Function to call when operation completes
   */
  time(tag: string, label: string): () => void;
}

// ===== Sync Manager Interface =====

/**
 * Synchronization manager service interface
 */
export interface ISyncManager {
  /**
   * Subscribes to sync state changes
   * @returns Unsubscribe function
   */
  subscribe(callback: SyncStateCallback): () => void;

  /**
   * Gets current sync state
   */
  getState(): SyncState;

  /**
   * Triggers a sync operation
   */
  triggerSync(): Promise<void>;

  /**
   * Schedules background sync
   */
  scheduleBackgroundSync(): Promise<void>;

  /**
   * Cleanup resources
   */
  destroy(): void;
}

// ===== Analytics Service Interface =====

/**
 * Analytics service interface
 */
export interface IAnalyticsService {
  /**
   * Initializes the analytics service
   */
  initialize(): Promise<void>;

  /**
   * Tracks a screen view
   */
  trackScreen(screenName: string, screenClass?: string): void;

  /**
   * Tracks a custom event
   */
  trackEvent(name: string, properties?: Record<string, string | number | boolean>): void;

  /**
   * Tracks a user action
   */
  trackAction(action: string, target: string, properties?: Record<string, string | number | boolean>): void;

  /**
   * Tracks an error
   */
  trackError(errorCode: string, errorMessage: string, properties?: Record<string, string | number | boolean>): void;

  /**
   * Tracks a performance metric
   */
  trackPerformance(metric: string, value: number, unit?: string): void;

  /**
   * Creates a timing utility for measuring operations
   * @returns Function to call when operation completes
   */
  startTiming(operationName: string): () => void;

  /**
   * Flushes queued events to the backend
   */
  flush(): Promise<void>;

  /**
   * Gets session duration
   */
  getSessionDuration(): number;

  /**
   * Gets current screen name
   */
  getCurrentScreen(): string | undefined;

  /**
   * Cleanup resources
   */
  destroy(): void;
}

// ===== User Repository Interface =====

/**
 * Extended user repository interface for DI
 * Extends the domain interface with lifecycle methods
 */
export interface IUserRepositoryService {
  // ===== Lifecycle =====

  /**
   * Initializes the repository
   */
  initialize(): Promise<void>;

  /**
   * Cleanup resources
   */
  destroy(): void;

  // ===== High-level Operations =====

  /**
   * Gets users with offline-first strategy
   */
  getUsers(page: number, forceRefresh?: boolean): Promise<Result<PaginatedUsers, AppError>>;

  /**
   * Gets a single user with offline-first strategy
   */
  getUser(userId: number, forceRefresh?: boolean): Promise<Result<User, AppError>>;

  /**
   * Creates a new user (saves locally, queues for sync)
   */
  createUser(request: CreateUserRequest): Promise<Result<User, AppError>>;

  /**
   * Updates a user (saves locally, queues for sync)
   */
  updateUser(request: UpdateUserRequest): Promise<Result<User, AppError>>;

  /**
   * Deletes a user (marks for deletion, queues for sync)
   */
  deleteUser(userId: number): Promise<Result<void, AppError>>;

  /**
   * Searches users locally
   */
  searchUsers(query: string): Promise<Result<User[], AppError>>;

  // ===== Remote Operations =====

  /**
   * Fetches users from the remote API
   */
  fetchUsersFromNetwork(page: number): Promise<Result<PaginatedUsers, AppError>>;

  /**
   * Creates a user on the remote API
   */
  createUserOnNetwork(request: CreateUserRequest): Promise<Result<User, AppError>>;

  /**
   * Updates a user on the remote API
   */
  updateUserOnNetwork(request: UpdateUserRequest): Promise<Result<User, AppError>>;

  /**
   * Deletes a user from the remote API
   */
  deleteUserFromNetwork(userId: number): Promise<Result<void, AppError>>;

  // ===== Local Operations =====

  /**
   * Gets all users from local storage
   */
  getAllUsersFromLocal(): Promise<Result<LocalUser[], AppError>>;

  /**
   * Saves a user to local storage
   */
  saveUserToLocal(user: LocalUser): Promise<Result<LocalUser, AppError>>;

  /**
   * Deletes a user from local storage
   */
  deleteUserFromLocal(userId: number): Promise<Result<void, AppError>>;

  /**
   * Gets users pending synchronization
   */
  getPendingSyncUsers(): Promise<Result<LocalUser[], AppError>>;

  /**
   * Updates the sync status of a user
   */
  updateSyncStatus(userId: number, status: SyncStatus, error?: string): Promise<Result<void, AppError>>;

  // ===== Cache Operations =====

  /**
   * Invalidates all cached data
   */
  invalidateAllCache(): void;

  /**
   * Gets the last sync timestamp
   */
  getLastSyncTime(): Promise<number | undefined>;

  /**
   * Updates the last sync timestamp
   */
  setLastSyncTime(timestamp: number): Promise<void>;
}

// ===== Context Provider Interface =====

/**
 * Application context provider interface
 */
export interface IContextProvider {
  /**
   * Gets the UI ability context
   */
  getContext(): common.UIAbilityContext;
}

// ===== User API Service Interface =====

/**
 * User API service interface
 */
export interface IUserApiService {
  /**
   * Fetches paginated users
   */
  getUsers(page: number, perPage?: number): Promise<Result<PaginatedUsers, AppError>>;

  /**
   * Fetches a single user by ID
   */
  getUser(userId: number): Promise<Result<User, AppError>>;

  /**
   * Creates a new user
   */
  createUser(request: CreateUserRequest): Promise<Result<User, AppError>>;

  /**
   * Updates an existing user
   */
  updateUser(request: UpdateUserRequest): Promise<Result<User, AppError>>;

  /**
   * Deletes a user
   */
  deleteUser(userId: number): Promise<Result<void, AppError>>;
}

// ===== Local Data Source Interface =====

/**
 * Local data source interface for user persistence
 */
export interface IUserLocalDataSource {
  /**
   * Initializes the data source
   */
  initialize(): Promise<void>;

  /**
   * Gets all users from local storage
   */
  getAllUsers(): Promise<LocalUser[]>;

  /**
   * Gets a user by ID
   */
  getUser(userId: number): Promise<LocalUser | undefined>;

  /**
   * Saves a user
   */
  saveUser(user: LocalUser): Promise<void>;

  /**
   * Saves multiple users
   */
  saveUsers(users: LocalUser[]): Promise<void>;

  /**
   * Deletes a user
   */
  deleteUser(userId: number): Promise<void>;

  /**
   * Clears all users
   */
  clearAll(): Promise<void>;

  /**
   * Gets users by sync status
   */
  getUsersBySyncStatus(statuses: SyncStatus[]): Promise<LocalUser[]>;

  /**
   * Gets the last sync timestamp
   */
  getLastSyncTime(): Promise<number | undefined>;

  /**
   * Sets the last sync timestamp
   */
  setLastSyncTime(timestamp: number): Promise<void>;
}

// ===== Cache Manager Interface =====

/**
 * Cache manager interface
 */
export interface ICacheManager<K, V> {
  /**
   * Gets a value from cache
   */
  get(key: K): V | undefined;

  /**
   * Sets a value in cache
   */
  set(key: K, value: V): void;

  /**
   * Removes a value from cache
   */
  delete(key: K): boolean;

  /**
   * Clears all cached values
   */
  clear(): void;

  /**
   * Checks if key exists in cache
   */
  has(key: K): boolean;

  /**
   * Gets the number of items in cache
   */
  size(): number;
}
