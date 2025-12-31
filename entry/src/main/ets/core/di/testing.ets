/**
 * Testing Utilities for Dependency Injection
 * Provides mock implementations and test helpers
 *
 * Usage:
 * ```
 * // Create test container with mocks
 * const container = createTestContainer();
 *
 * // Or create container with specific overrides
 * const container = createTestContainerWithOverrides({
 *   [TYPES.Logger]: new MockLogger(),
 *   [TYPES.NetworkMonitor]: new MockNetworkMonitor(true)
 * });
 *
 * // Test your service
 * const myService = container.get<IMyService>(TYPES.MyService);
 * ```
 */

import { Container, createContainer } from './Container';
import { TYPES } from './tokens';
import {
  INetworkMonitor,
  ILogger,
  ISyncManager,
  IAnalyticsService,
  IUserRepositoryService,
  IUserApiService,
  IUserLocalDataSource
} from './interfaces';
import { NetworkState, NetworkStatus, NetworkType, NetworkStateCallback } from '../network/NetworkMonitor';
import { SyncState, SyncStateCallback } from '../sync/SyncManager';
import { LogLevel } from '../logging/Logger';
import {
  User,
  CreateUserRequest,
  UpdateUserRequest,
  PaginatedUsers,
  LocalUser,
  SyncStatus
} from '../../domain/models/User';
import { Result, ResultFactory } from '../../domain/models/Result';
import { AppError } from '../../domain/models/AppError';

// ===== Mock Logger =====

/**
 * Mock logger for testing
 * Records all log calls for verification
 */
export class MockLogger implements ILogger {
  logs: { level: string; tag: string; message: string }[] = [];
  private enabled = true;
  private level = LogLevel.DEBUG;

  setLevel(level: LogLevel): void {
    this.level = level;
  }

  setEnabled(enabled: boolean): void {
    this.enabled = enabled;
  }

  d(tag: string, message: string, ..._args: Object[]): void {
    if (this.enabled) this.logs.push({ level: 'DEBUG', tag, message });
  }

  i(tag: string, message: string, ..._args: Object[]): void {
    if (this.enabled) this.logs.push({ level: 'INFO', tag, message });
  }

  w(tag: string, message: string, ..._args: Object[]): void {
    if (this.enabled) this.logs.push({ level: 'WARN', tag, message });
  }

  e(tag: string, message: string, ..._args: Object[]): void {
    if (this.enabled) this.logs.push({ level: 'ERROR', tag, message });
  }

  f(tag: string, message: string, ..._args: Object[]): void {
    if (this.enabled) this.logs.push({ level: 'FATAL', tag, message });
  }

  log(level: LogLevel, tag: string, message: string, ..._args: Object[]): void {
    if (this.enabled) this.logs.push({ level: LogLevel[level], tag, message });
  }

  exception(tag: string, message: string, _error: Error): void {
    if (this.enabled) this.logs.push({ level: 'ERROR', tag, message });
  }

  json(tag: string, label: string, _data: object): void {
    if (this.enabled) this.logs.push({ level: 'DEBUG', tag, message: label });
  }

  time(_tag: string, _label: string): () => void {
    return () => {};
  }

  clear(): void {
    this.logs = [];
  }

  hasLog(level: string, messageContains: string): boolean {
    return this.logs.some(l => l.level === level && l.message.includes(messageContains));
  }
}

// ===== Mock Network Monitor =====

/**
 * Mock network monitor for testing
 * Allows controlling network state
 */
export class MockNetworkMonitor implements INetworkMonitor {
  private isOnline: boolean;
  private callbacks: Set<NetworkStateCallback> = new Set();
  private state: NetworkState;

  constructor(isOnline: boolean = true) {
    this.isOnline = isOnline;
    this.state = {
      status: isOnline ? NetworkStatus.AVAILABLE : NetworkStatus.UNAVAILABLE,
      type: isOnline ? NetworkType.WIFI : NetworkType.NONE,
      isMetered: false
    };
  }

  async initialize(): Promise<void> {}

  async isNetworkAvailable(): Promise<boolean> {
    return this.isOnline;
  }

  async getNetworkState(): Promise<NetworkState> {
    return { ...this.state };
  }

  subscribe(callback: NetworkStateCallback): () => void {
    this.callbacks.add(callback);
    callback({ ...this.state });
    return () => this.callbacks.delete(callback);
  }

  destroy(): void {
    this.callbacks.clear();
  }

  // Test helpers
  setOnline(online: boolean): void {
    this.isOnline = online;
    this.state.status = online ? NetworkStatus.AVAILABLE : NetworkStatus.UNAVAILABLE;
    this.state.type = online ? NetworkType.WIFI : NetworkType.NONE;
    this.notifyCallbacks();
  }

  private notifyCallbacks(): void {
    this.callbacks.forEach(cb => cb({ ...this.state }));
  }
}

// ===== Mock Sync Manager =====

/**
 * Mock sync manager for testing
 */
export class MockSyncManager implements ISyncManager {
  private callbacks: Set<SyncStateCallback> = new Set();
  private state: SyncState = {
    isSyncing: false,
    pendingCount: 0,
    lastSyncTime: undefined,
    lastSyncError: undefined
  };
  syncTriggerCount = 0;

  subscribe(callback: SyncStateCallback): () => void {
    this.callbacks.add(callback);
    callback({ ...this.state });
    return () => this.callbacks.delete(callback);
  }

  getState(): SyncState {
    return { ...this.state };
  }

  async triggerSync(): Promise<void> {
    this.syncTriggerCount++;
  }

  async scheduleBackgroundSync(): Promise<void> {}

  destroy(): void {
    this.callbacks.clear();
  }

  // Test helpers
  setState(partial: Partial<SyncState>): void {
    this.state = { ...this.state, ...partial };
    this.callbacks.forEach(cb => cb({ ...this.state }));
  }
}

// ===== Mock Analytics Service =====

/**
 * Mock analytics service for testing
 */
export class MockAnalyticsService implements IAnalyticsService {
  events: { type: string; name: string; properties?: Record<string, string | number | boolean> }[] = [];
  screens: string[] = [];

  async initialize(): Promise<void> {}

  trackScreen(screenName: string, _screenClass?: string): void {
    this.screens.push(screenName);
  }

  trackEvent(name: string, properties?: Record<string, string | number | boolean>): void {
    this.events.push({ type: 'event', name, properties });
  }

  trackAction(action: string, target: string, properties?: Record<string, string | number | boolean>): void {
    this.events.push({ type: 'action', name: `${action}:${target}`, properties });
  }

  trackError(errorCode: string, errorMessage: string, properties?: Record<string, string | number | boolean>): void {
    this.events.push({ type: 'error', name: `${errorCode}:${errorMessage}`, properties });
  }

  trackPerformance(metric: string, value: number, _unit?: string): void {
    this.events.push({ type: 'performance', name: metric, properties: { value } });
  }

  startTiming(_operationName: string): () => void {
    return () => {};
  }

  async flush(): Promise<void> {}

  getSessionDuration(): number {
    return 0;
  }

  getCurrentScreen(): string | undefined {
    return this.screens[this.screens.length - 1];
  }

  destroy(): void {}

  // Test helpers
  clear(): void {
    this.events = [];
    this.screens = [];
  }

  hasEvent(name: string): boolean {
    return this.events.some(e => e.name === name || e.name.includes(name));
  }
}

// ===== Mock User API Service =====

/**
 * Mock user API service for testing
 */
export class MockUserApiService implements IUserApiService {
  users: User[] = [];
  shouldFail = false;
  failureError?: AppError;

  async getUsers(page: number = 1, perPage: number = 6): Promise<Result<PaginatedUsers, AppError>> {
    if (this.shouldFail && this.failureError) {
      return ResultFactory.failure(this.failureError);
    }

    const start = (page - 1) * perPage;
    const pageUsers = this.users.slice(start, start + perPage);

    return ResultFactory.success({
      users: pageUsers,
      page,
      perPage,
      total: this.users.length,
      totalPages: Math.ceil(this.users.length / perPage)
    });
  }

  async getUser(userId: number): Promise<Result<User, AppError>> {
    if (this.shouldFail && this.failureError) {
      return ResultFactory.failure(this.failureError);
    }

    const user = this.users.find(u => u.id === userId);
    if (user) {
      return ResultFactory.success(user);
    }
    return ResultFactory.failure({ code: 'E2001', message: 'Not found' } as AppError);
  }

  async createUser(request: CreateUserRequest): Promise<Result<User, AppError>> {
    if (this.shouldFail && this.failureError) {
      return ResultFactory.failure(this.failureError);
    }

    const newUser: User = {
      id: this.users.length + 1,
      email: request.email,
      firstName: request.firstName,
      lastName: request.lastName,
      avatar: request.avatar || ''
    };
    this.users.push(newUser);
    return ResultFactory.success(newUser);
  }

  async updateUser(request: UpdateUserRequest): Promise<Result<User, AppError>> {
    if (this.shouldFail && this.failureError) {
      return ResultFactory.failure(this.failureError);
    }

    const index = this.users.findIndex(u => u.id === request.id);
    if (index >= 0) {
      this.users[index] = {
        ...this.users[index],
        email: request.email,
        firstName: request.firstName,
        lastName: request.lastName,
        avatar: request.avatar
      };
      return ResultFactory.success(this.users[index]);
    }
    return ResultFactory.failure({ code: 'E2001', message: 'Not found' } as AppError);
  }

  async deleteUser(userId: number): Promise<Result<void, AppError>> {
    if (this.shouldFail && this.failureError) {
      return ResultFactory.failure(this.failureError);
    }

    const index = this.users.findIndex(u => u.id === userId);
    if (index >= 0) {
      this.users.splice(index, 1);
    }
    return ResultFactory.success(undefined);
  }

  // Test helpers
  addUser(user: User): void {
    this.users.push(user);
  }

  setUsers(users: User[]): void {
    this.users = users;
  }

  setFailure(error: AppError): void {
    this.shouldFail = true;
    this.failureError = error;
  }

  clearFailure(): void {
    this.shouldFail = false;
    this.failureError = undefined;
  }
}

// ===== Mock Local Data Source =====

/**
 * Mock local data source for testing
 */
export class MockUserLocalDataSource implements IUserLocalDataSource {
  private users: LocalUser[] = [];
  private lastSyncTime?: number;

  async initialize(): Promise<void> {}

  async getAllUsers(): Promise<LocalUser[]> {
    return [...this.users];
  }

  async getUser(userId: number): Promise<LocalUser | undefined> {
    return this.users.find(u => u.id === userId);
  }

  async saveUser(user: LocalUser): Promise<void> {
    const index = this.users.findIndex(u => u.id === user.id);
    if (index >= 0) {
      this.users[index] = user;
    } else {
      this.users.push(user);
    }
  }

  async saveUsers(users: LocalUser[]): Promise<void> {
    for (const user of users) {
      await this.saveUser(user);
    }
  }

  async deleteUser(userId: number): Promise<void> {
    this.users = this.users.filter(u => u.id !== userId);
  }

  async clearAll(): Promise<void> {
    this.users = [];
    this.lastSyncTime = undefined;
  }

  async getUsersBySyncStatus(statuses: SyncStatus[]): Promise<LocalUser[]> {
    return this.users.filter(u => statuses.includes(u.syncStatus));
  }

  async getLastSyncTime(): Promise<number | undefined> {
    return this.lastSyncTime;
  }

  async setLastSyncTime(timestamp: number): Promise<void> {
    this.lastSyncTime = timestamp;
  }

  // Test helpers
  setUsers(users: LocalUser[]): void {
    this.users = [...users];
  }

  addUser(user: LocalUser): void {
    this.users.push(user);
  }
}

// ===== Test Container Factory =====

/**
 * Creates a test container with all mock implementations
 */
export function createTestContainer(): Container {
  const container = createContainer();

  container.bind<ILogger>(TYPES.Logger).toConstantValue(new MockLogger());
  container.bind<INetworkMonitor>(TYPES.NetworkMonitor).toConstantValue(new MockNetworkMonitor(true));
  container.bind<ISyncManager>(TYPES.SyncManager).toConstantValue(new MockSyncManager());
  container.bind<IAnalyticsService>(TYPES.AnalyticsService).toConstantValue(new MockAnalyticsService());
  container.bind<IUserApiService>(TYPES.UserApiService).toConstantValue(new MockUserApiService());
  container.bind<IUserLocalDataSource>(TYPES.UserLocalDataSource).toConstantValue(new MockUserLocalDataSource());

  return container;
}

/**
 * Creates a test container with specific overrides
 */
export function createTestContainerWithOverrides(
  overrides: Partial<Record<symbol, Object>>
): Container {
  const container = createTestContainer();

  for (const [token, implementation] of Object.entries(overrides)) {
    const symbolToken = Symbol.for(token);
    container.rebind(symbolToken).toConstantValue(implementation);
  }

  return container;
}

/**
 * Test helper to create a sample user
 */
export function createSampleUser(partial: Partial<User> = {}): User {
  return {
    id: partial.id ?? 1,
    email: partial.email ?? 'test@example.com',
    firstName: partial.firstName ?? 'Test',
    lastName: partial.lastName ?? 'User',
    avatar: partial.avatar ?? 'https://example.com/avatar.png'
  };
}

/**
 * Test helper to create a sample local user
 */
export function createSampleLocalUser(partial: Partial<LocalUser> = {}): LocalUser {
  const now = Date.now();
  return {
    id: partial.id ?? 1,
    localId: partial.localId ?? `local_${now}`,
    email: partial.email ?? 'test@example.com',
    firstName: partial.firstName ?? 'Test',
    lastName: partial.lastName ?? 'User',
    avatar: partial.avatar ?? 'https://example.com/avatar.png',
    syncStatus: partial.syncStatus ?? SyncStatus.SYNCED,
    syncAttempts: partial.syncAttempts ?? 0,
    createdAt: partial.createdAt ?? now,
    updatedAt: partial.updatedAt ?? now
  };
}
