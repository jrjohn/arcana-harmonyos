/**
 * Container Initializer
 * Manages the DI container lifecycle and service initialization
 * Replaces the old Service Locator pattern with proper DI
 */

import { common } from '@kit.AbilityKit';
import { Container, createContainer } from './Container';
import { TYPES } from './tokens';
import {
  INetworkMonitor,
  ILogger,
  ISyncManager,
  IAnalyticsService,
  IUserRepositoryService,
  IUserApiService,
  IUserLocalDataSource,
  IContextProvider
} from './interfaces';

// Import implementations
import { LoggerService } from '../logging/LoggerService';
import { NetworkMonitorService } from '../network/NetworkMonitorService';
import { SyncManagerService } from '../sync/SyncManagerService';
import { AnalyticsServiceImpl } from '../analytics/AnalyticsServiceImpl';
import { UserRepositoryService } from '../../data/repository/UserRepositoryService';
import { UserApiServiceImpl } from '../../data/api/UserApiServiceImpl';
import { UserLocalDataSourceRdb } from '../../data/local/UserLocalDataSourceRdb';
import { RdbStoreManager } from '../../data/local/RdbStoreManager';
import { DataMigration } from '../../data/local/DataMigration';

const TAG = 'ContainerInitializer';

/**
 * Context provider implementation
 */
class ContextProviderImpl implements IContextProvider {
  constructor(private context: common.UIAbilityContext) {}

  getContext(): common.UIAbilityContext {
    return this.context;
  }
}

/**
 * Application container initializer
 * Manages the DI container and service lifecycle
 */
export class ContainerInitializer {
  private static instance: ContainerInitializer | null = null;
  private container: Container;
  private context: common.UIAbilityContext;
  private initialized: boolean = false;

  private constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.container = createContainer();
  }

  /**
   * Gets the singleton instance
   */
  static getInstance(context: common.UIAbilityContext): ContainerInitializer {
    if (!ContainerInitializer.instance) {
      ContainerInitializer.instance = new ContainerInitializer(context);
    }
    return ContainerInitializer.instance;
  }

  /**
   * Gets the DI container
   */
  getContainer(): Container {
    return this.container;
  }

  /**
   * Initializes all application dependencies
   */
  async initialize(): Promise<void> {
    if (this.initialized) {
      this.log('Already initialized');
      return;
    }

    const startTime = Date.now();

    try {
      // 1. Bind core services
      this.bindCoreServices();

      // 2. Bind data layer services
      this.bindDataServices();

      // 3. Bind sync services
      this.bindSyncServices();

      // 4. Initialize services that require async initialization
      await this.initializeServices();

      this.initialized = true;
      const duration = Date.now() - startTime;
      this.log(`App initialization completed in ${duration}ms`);

      // Log initial sync status
      const repository = this.container.get<IUserRepositoryService>(TYPES.UserRepository);
      const pendingResult = await repository.getPendingSyncUsers();
      if (pendingResult.kind === 'success') {
        this.log(`Pending sync items: ${pendingResult.value.length}`);
      }
    } catch (error) {
      this.logError(`Initialization failed: ${error}`);
      throw error;
    }
  }

  /**
   * Binds core services to the container
   */
  private bindCoreServices(): void {
    // Context provider
    this.container.bind<IContextProvider>(TYPES.ContextProvider)
      .toConstantValue(new ContextProviderImpl(this.context));

    // Logger (singleton)
    const logger = new LoggerService();
    this.container.bind<ILogger>(TYPES.Logger)
      .toConstantValue(logger);

    // Network monitor (singleton)
    const networkMonitor = new NetworkMonitorService();
    networkMonitor.setLogger(logger);
    this.container.bind<INetworkMonitor>(TYPES.NetworkMonitor)
      .toConstantValue(networkMonitor);

    // Analytics (singleton)
    const analytics = new AnalyticsServiceImpl();
    analytics.setLogger(logger);
    this.container.bind<IAnalyticsService>(TYPES.AnalyticsService)
      .toConstantValue(analytics);

    this.log('Core services bound');
  }

  /**
   * Binds data layer services to the container
   */
  private bindDataServices(): void {
    const logger = this.container.get<ILogger>(TYPES.Logger);

    // API service (singleton)
    const apiService = new UserApiServiceImpl();
    apiService.setLogger(logger);
    this.container.bind<IUserApiService>(TYPES.UserApiService)
      .toConstantValue(apiService);

    // Local data source - using RDB (RelationalStore) implementation
    const localDataSource = new UserLocalDataSourceRdb(this.context);
    localDataSource.setLogger(logger);
    this.container.bind<IUserLocalDataSource>(TYPES.UserLocalDataSource)
      .toConstantValue(localDataSource);

    // Repository (singleton)
    const repository = new UserRepositoryService(apiService, localDataSource, logger);
    const networkMonitor = this.container.get<INetworkMonitor>(TYPES.NetworkMonitor);
    repository.setNetworkMonitor(networkMonitor);
    this.container.bind<IUserRepositoryService>(TYPES.UserRepository)
      .toConstantValue(repository);

    this.log('Data layer services bound');
  }

  /**
   * Binds sync services to the container
   */
  private bindSyncServices(): void {
    const repository = this.container.get<IUserRepositoryService>(TYPES.UserRepository);
    const networkMonitor = this.container.get<INetworkMonitor>(TYPES.NetworkMonitor);
    const logger = this.container.get<ILogger>(TYPES.Logger);

    // Sync manager (singleton)
    const syncManager = new SyncManagerService(repository, networkMonitor, logger);
    this.container.bind<ISyncManager>(TYPES.SyncManager)
      .toConstantValue(syncManager);

    this.log('Sync services bound');
  }

  /**
   * Initializes services that require async initialization
   */
  private async initializeServices(): Promise<void> {
    const logger = this.container.get<ILogger>(TYPES.Logger);

    // Initialize network monitor
    const networkMonitor = this.container.get<INetworkMonitor>(TYPES.NetworkMonitor);
    await networkMonitor.initialize();
    this.log('NetworkMonitor initialized');

    // Initialize RDB store manager first
    const dbManager = RdbStoreManager.getInstance();
    await dbManager.initialize(this.context);
    this.log('RdbStoreManager initialized');

    // Run migration from Preferences to RDB if needed
    await this.runMigrationIfNeeded(logger);

    // Initialize local data source (RDB-based)
    const localDataSource = this.container.get<IUserLocalDataSource>(TYPES.UserLocalDataSource);
    await localDataSource.initialize();
    this.log('LocalDataSource (RDB) initialized');

    // Initialize repository
    const repository = this.container.get<IUserRepositoryService>(TYPES.UserRepository);
    await repository.initialize();
    this.log('UserRepository initialized');

    // Initialize analytics
    const analytics = this.container.get<IAnalyticsService>(TYPES.AnalyticsService);
    await analytics.initialize();
    this.log('AnalyticsService initialized');
  }

  /**
   * Runs migration from Preferences to RDB if needed
   */
  private async runMigrationIfNeeded(logger: ILogger): Promise<void> {
    const migration = new DataMigration(this.context);
    migration.setLogger(logger);

    const needsMigration = await migration.isMigrationNeeded();
    if (needsMigration) {
      this.log('Starting data migration from Preferences to RDB...');
      const result = await migration.migrate();

      if (result.success) {
        this.log(`Migration completed: ${result.usersMigrated} users migrated in ${result.durationMs}ms`);
        // Cleanup old Preferences data after successful migration
        await migration.cleanupPreferences();
      } else {
        this.logError(`Migration failed: ${result.error}`);
        // Continue anyway - RDB will start fresh if migration fails
      }
    } else {
      this.log('No migration needed');
    }
  }

  /**
   * Called when app comes to foreground
   */
  async onForeground(): Promise<void> {
    this.log('App entering foreground');

    const syncManager = this.container.get<ISyncManager>(TYPES.SyncManager);
    syncManager.triggerSync();

    const analytics = this.container.get<IAnalyticsService>(TYPES.AnalyticsService);
    analytics.trackEvent('app_foreground');
  }

  /**
   * Called when app goes to background
   */
  async onBackground(): Promise<void> {
    this.log('App entering background');

    const syncManager = this.container.get<ISyncManager>(TYPES.SyncManager);
    await syncManager.scheduleBackgroundSync();

    const analytics = this.container.get<IAnalyticsService>(TYPES.AnalyticsService);
    analytics.trackEvent('app_background');
  }

  /**
   * Gets a service from the container
   */
  get<T>(identifier: symbol): T {
    return this.container.get<T>(identifier);
  }

  /**
   * Cleanup all resources
   */
  async cleanup(): Promise<void> {
    this.log('Cleaning up app resources');

    await this.container.dispose();

    this.initialized = false;
    ContainerInitializer.instance = null;
  }

  private log(message: string): void {
    try {
      const logger = this.container.get<ILogger>(TYPES.Logger);
      logger.d(TAG, message);
    } catch {
      // Logger not yet bound, use console
      console.debug(`[${TAG}] ${message}`);
    }
  }

  private logError(message: string): void {
    try {
      const logger = this.container.get<ILogger>(TYPES.Logger);
      logger.e(TAG, message);
    } catch {
      console.error(`[${TAG}] ${message}`);
    }
  }
}

// ===== Global Container Access =====

let globalContainer: Container | null = null;

/**
 * Sets the global container instance
 */
export function setGlobalContainer(container: Container): void {
  globalContainer = container;
}

/**
 * Gets the global container instance
 */
export function getGlobalContainer(): Container {
  if (!globalContainer) {
    throw new Error('Container not initialized. Call ContainerInitializer.initialize() first.');
  }
  return globalContainer;
}

/**
 * Resolves a service from the global container
 */
export function resolve<T>(identifier: symbol): T {
  return getGlobalContainer().get<T>(identifier);
}

// ===== Service Accessors =====

/**
 * Gets the logger service
 */
export function getLogger(): ILogger {
  return resolve<ILogger>(TYPES.Logger);
}

/**
 * Gets the network monitor service
 */
export function getNetworkMonitor(): INetworkMonitor {
  return resolve<INetworkMonitor>(TYPES.NetworkMonitor);
}

/**
 * Gets the sync manager service
 */
export function getSyncManager(): ISyncManager {
  return resolve<ISyncManager>(TYPES.SyncManager);
}

/**
 * Gets the analytics service
 */
export function getAnalyticsService(): IAnalyticsService {
  return resolve<IAnalyticsService>(TYPES.AnalyticsService);
}

/**
 * Gets the user repository service
 */
export function getUserRepository(): IUserRepositoryService {
  return resolve<IUserRepositoryService>(TYPES.UserRepository);
}
