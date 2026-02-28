/**
 * Application Dependency Injection Container
 * Centralizes all service bindings and provides global access
 *
 * Replaces ServiceLocator pattern with proper IoC Container
 */

import { common } from '@kit.AbilityKit';
import { Container, createContainer } from './Container';
import { TYPES } from './tokens';
import {
  IUserRepositoryService,
  ISyncManager,
  IAnalyticsService,
  ILogger,
  INetworkMonitor,
  IContextProvider
} from './interfaces';
import { IUserService } from '../../domain/services/UserService';
import { UserServiceImpl } from '../../domain/services/impl/UserServiceImpl';
import { INavigator, Navigator } from '../navigation/Navigator';
import { UserRepositoryImpl } from '../../domain/repository/impl/UserRepositoryImpl';
import { SyncManager } from '../sync/SyncManager';
import { AnalyticsService } from '../analytics/AnalyticsService';
import { Logger } from '../logging/Logger';
import { NetworkMonitor } from '../network/NetworkMonitor';
import { HomeViewModel } from '../../presentation/viewmodel/HomeViewModel';
import { UserListViewModel } from '../../presentation/viewmodel/UserListViewModel';
import { UserDetailViewModel } from '../../presentation/viewmodel/UserDetailViewModel';
import { UserFormViewModel } from '../../presentation/viewmodel/UserFormViewModel';

const TAG = 'AppContainer';

/**
 * Context provider implementation
 */
class ContextProvider implements IContextProvider {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  getContext(): common.UIAbilityContext {
    return this.context;
  }
}

/**
 * Logger service wrapper (adapts static Logger to ILogger interface)
 */
class LoggerService implements ILogger {
  setLevel(): void {}
  setEnabled(): void {}

  d(tag: string, message: string): void {
    Logger.d(tag, message);
  }

  i(tag: string, message: string): void {
    Logger.i(tag, message);
  }

  w(tag: string, message: string): void {
    Logger.w(tag, message);
  }

  e(tag: string, message: string): void {
    Logger.e(tag, message);
  }

  f(tag: string, message: string): void {
    Logger.e(tag, `FATAL: ${message}`);
  }

  log(_level: number, tag: string, message: string): void {
    Logger.d(tag, message);
  }

  exception(tag: string, message: string, error: Error): void {
    Logger.e(tag, `${message}: ${error.message}`);
  }

  json(tag: string, label: string, data: object): void {
    Logger.d(tag, `${label}: ${JSON.stringify(data)}`);
  }

  time(tag: string, label: string): () => void {
    const timer = Logger.time(tag, label);
    return () => timer.end();
  }
}

/**
 * Network monitor service wrapper
 */
class NetworkMonitorService implements INetworkMonitor {
  async initialize(): Promise<void> {
    await NetworkMonitor.initialize();
  }

  async isNetworkAvailable(): Promise<boolean> {
    return NetworkMonitor.isNetworkAvailable();
  }

  async getNetworkState(): Promise<import('../network/NetworkMonitor').NetworkState> {
    return NetworkMonitor.getNetworkState();
  }

  subscribe(callback: import('../network/NetworkMonitor').NetworkStateCallback): () => void {
    const unsubscribe = NetworkMonitor.subscribe(callback);
    return () => unsubscribe.unsubscribe();
  }

  destroy(): void {
    NetworkMonitor.destroy();
  }
}

/**
 * Global application container
 * Singleton pattern for container access
 */
export class AppContainer {
  private static instance: AppContainer | null = null;
  private container: Container;
  private context: common.UIAbilityContext | null = null;
  private initialized: boolean = false;

  private constructor() {
    this.container = createContainer();
  }

  /**
   * Gets the singleton container instance
   */
  static getInstance(): AppContainer {
    if (!AppContainer.instance) {
      AppContainer.instance = new AppContainer();
    }
    return AppContainer.instance;
  }

  /**
   * Gets the raw container for advanced usage
   */
  getContainer(): Container {
    return this.container;
  }

  /**
   * Initializes the container with all bindings
   */
  async initialize(context: common.UIAbilityContext): Promise<void> {
    if (this.initialized) {
      Logger.d(TAG, 'Container already initialized');
      return;
    }

    this.context = context;
    const timer = Logger.time(TAG, 'Container initialization');

    try {
      // Bind context provider
      this.container.bind<IContextProvider>(TYPES.ContextProvider)
        .toConstantValue(new ContextProvider(context));

      // Bind logger
      this.container.bind<ILogger>(TYPES.Logger)
        .toConstantValue(new LoggerService());

      // Initialize and bind network monitor
      const networkMonitor = new NetworkMonitorService();
      await networkMonitor.initialize();
      this.container.bind<INetworkMonitor>(TYPES.NetworkMonitor)
        .toConstantValue(networkMonitor);

      // Initialize and bind user repository
      const userRepository = new UserRepositoryImpl(context);
      await userRepository.initialize();
      this.container.bind<IUserRepositoryService>(TYPES.UserRepository)
        .toConstantValue(userRepository);

      // Bind domain user service (depends on repository)
      const userService = new UserServiceImpl(userRepository);
      this.container.bind<IUserService>(TYPES.UserService)
        .toConstantValue(userService);

      // Bind sync manager (depends on repository)
      const syncManager = new SyncManager(userRepository);
      this.container.bind<ISyncManager>(TYPES.SyncManager)
        .toConstantValue(syncManager);

      // Initialize and bind analytics service
      const analyticsService = new AnalyticsService();
      await analyticsService.initialize();
      this.container.bind<IAnalyticsService>(TYPES.AnalyticsService)
        .toConstantValue(analyticsService);

      // Bind navigator
      const navigator = new Navigator();
      navigator.setDependencies(
        this.container.get<ILogger>(TYPES.Logger),
        this.container.get<IAnalyticsService>(TYPES.AnalyticsService)
      );
      this.container.bind<INavigator>(TYPES.Navigator)
        .toConstantValue(navigator);

      this.initialized = true;
      timer.end();

      Logger.i(TAG, 'Container initialized successfully');
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      Logger.e(TAG, `Container initialization failed: ${errorMessage}`);
      throw new Error(`Container initialization failed: ${errorMessage}`);
    }
  }

  /**
   * Called when app comes to foreground
   */
  async onForeground(): Promise<void> {
    Logger.d(TAG, 'App entering foreground');

    const syncManager = this.resolve<ISyncManager>(TYPES.SyncManager);
    syncManager.triggerSync();

    const analytics = this.resolve<IAnalyticsService>(TYPES.AnalyticsService);
    analytics.trackEvent('app_foreground');
  }

  /**
   * Called when app goes to background
   */
  async onBackground(): Promise<void> {
    Logger.d(TAG, 'App entering background');

    const syncManager = this.resolve<ISyncManager>(TYPES.SyncManager);
    await syncManager.scheduleBackgroundSync();

    const analytics = this.resolve<IAnalyticsService>(TYPES.AnalyticsService);
    analytics.trackEvent('app_background');
  }

  /**
   * Resolves a service by token
   */
  resolve<T>(token: string): T {
    if (!this.initialized) {
      throw new Error('Container not initialized. Call initialize() first.');
    }
    return this.container.get<T>(token);
  }

  /**
   * Checks if container is initialized
   */
  isInitialized(): boolean {
    return this.initialized;
  }

  /**
   * Cleanup all resources
   */
  async dispose(): Promise<void> {
    Logger.d(TAG, 'Disposing container');

    if (this.initialized) {
      // Cleanup services
      try {
        const syncManager = this.container.get<ISyncManager>(TYPES.SyncManager);
        syncManager.destroy();
      } catch { /* ignore */ }

      try {
        const analytics = this.container.get<IAnalyticsService>(TYPES.AnalyticsService);
        analytics.destroy();
      } catch { /* ignore */ }

      try {
        const networkMonitor = this.container.get<INetworkMonitor>(TYPES.NetworkMonitor);
        networkMonitor.destroy();
      } catch { /* ignore */ }

      await this.container.dispose();
    }

    this.initialized = false;
    this.context = null;
    AppContainer.instance = null;
  }

  // ===== Convenience Accessors =====

  /**
   * Gets the user repository
   */
  getUserRepository(): IUserRepositoryService {
    return this.resolve<IUserRepositoryService>(TYPES.UserRepository);
  }

  /**
   * Gets the user service (domain layer)
   */
  getUserService(): IUserService {
    return this.resolve<IUserService>(TYPES.UserService);
  }

  /**
   * Gets the sync manager
   */
  getSyncManager(): ISyncManager {
    return this.resolve<ISyncManager>(TYPES.SyncManager);
  }

  /**
   * Gets the analytics service
   */
  getAnalyticsService(): IAnalyticsService {
    return this.resolve<IAnalyticsService>(TYPES.AnalyticsService);
  }

  /**
   * Gets the navigator
   */
  getNavigator(): INavigator {
    return this.resolve<INavigator>(TYPES.Navigator);
  }

  /**
   * Gets the logger
   */
  getLogger(): ILogger {
    return this.resolve<ILogger>(TYPES.Logger);
  }

  // ===== ViewModel Factories =====
  // Factory methods create ViewModels with proper DI (not registered as singletons)

  /**
   * Creates a HomeViewModel with injected dependencies
   */
  createHomeViewModel(): HomeViewModel {
    const userService = this.resolve<IUserService>(TYPES.UserService);
    const analytics = this.resolve<IAnalyticsService>(TYPES.AnalyticsService);
    return new HomeViewModel(userService, analytics);
  }

  /**
   * Creates a UserListViewModel with injected dependencies
   */
  createUserListViewModel(): UserListViewModel {
    const userService = this.resolve<IUserService>(TYPES.UserService);
    const syncManager = this.resolve<ISyncManager>(TYPES.SyncManager);
    const analytics = this.resolve<IAnalyticsService>(TYPES.AnalyticsService);
    return new UserListViewModel(userService, syncManager, analytics);
  }

  /**
   * Creates a UserDetailViewModel with injected dependencies
   * @param userId - The user ID to load
   */
  createUserDetailViewModel(userId: number): UserDetailViewModel {
    const userService = this.resolve<IUserService>(TYPES.UserService);
    const analytics = this.resolve<IAnalyticsService>(TYPES.AnalyticsService);
    return new UserDetailViewModel(userService, analytics, userId);
  }

  /**
   * Creates a UserFormViewModel with injected dependencies
   * @param mode - 'create' or 'edit'
   * @param userId - Optional user ID for edit mode
   */
  createUserFormViewModel(mode: 'create' | 'edit', userId?: number): UserFormViewModel {
    const userService = this.resolve<IUserService>(TYPES.UserService);
    const analytics = this.resolve<IAnalyticsService>(TYPES.AnalyticsService);
    return new UserFormViewModel(userService, analytics, mode, userId);
  }
}

/**
 * Global container accessor function
 * Shorthand for AppContainer.getInstance()
 */
export function getContainer(): AppContainer {
  return AppContainer.getInstance();
}

/**
 * Resolves a service from the global container
 * Shorthand for AppContainer.getInstance().resolve(token)
 */
export function inject<T>(token: string): T {
  return AppContainer.getInstance().resolve<T>(token);
}
