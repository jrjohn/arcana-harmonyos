import { common } from '@kit.AbilityKit';
import { UserRepositoryImpl } from '../../data/repository/UserRepositoryImpl';
import { NetworkMonitor } from '../network/NetworkMonitor';
import { SyncManager } from '../sync/SyncManager';
import { AnalyticsService } from '../analytics/AnalyticsService';
import { Logger } from '../logging/Logger';
import { Success } from '../../domain/models/Result';

const TAG = 'AppInitializer';

/**
 * Application-level dependency container and initializer.
 * Implements a simple service locator pattern for dependency management.
 */
export class AppInitializer {
  private static instance: AppInitializer | null = null;
  private context: common.UIAbilityContext;
  private userRepository: UserRepositoryImpl | null = null;
  private syncManager: SyncManager | null = null;
  private analyticsService: AnalyticsService | null = null;
  private initialized: boolean = false;

  private constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  /**
   * Gets the singleton instance
   */
  static getInstance(context: common.UIAbilityContext): AppInitializer {
    if (!AppInitializer.instance) {
      AppInitializer.instance = new AppInitializer(context);
    }
    return AppInitializer.instance;
  }

  /**
   * Initializes all application dependencies
   */
  async initialize(): Promise<void> {
    if (this.initialized) {
      Logger.d(TAG, 'Already initialized');
      return;
    }

    const timer = Logger.time(TAG, 'App initialization');

    try {
      // Initialize network monitor
      await NetworkMonitor.initialize();
      Logger.d(TAG, 'NetworkMonitor initialized');

      // Initialize repository
      this.userRepository = new UserRepositoryImpl(this.context);
      await this.userRepository.initialize();
      Logger.d(TAG, 'UserRepository initialized');

      // Initialize sync manager
      this.syncManager = new SyncManager(this.userRepository);
      Logger.d(TAG, 'SyncManager initialized');

      // Initialize analytics
      this.analyticsService = new AnalyticsService();
      await this.analyticsService.initialize();
      Logger.d(TAG, 'AnalyticsService initialized');

      this.initialized = true;
      timer.end();

      // Log initial sync status
      const pendingResult = await this.userRepository.getPendingSyncUsers();
      if (pendingResult.isSuccess) {
        const successResult = pendingResult as Success<import('../../domain/models/User').LocalUser[]>;
        Logger.i(TAG, `Pending sync items: ${successResult.value.length}`);
      }
    } catch (error) {
      Logger.e(TAG, `Initialization failed: ${error}`);
      if (error instanceof Error) {
        throw error;
      }
      throw new Error(String(error));
    }
  }

  /**
   * Called when app comes to foreground
   */
  async onForeground(): Promise<void> {
    Logger.d(TAG, 'App entering foreground');

    // Trigger sync
    if (this.syncManager) {
      this.syncManager.triggerSync();
    }

    // Track analytics
    if (this.analyticsService) {
      this.analyticsService.trackEvent('app_foreground');
    }
  }

  /**
   * Called when app goes to background
   */
  async onBackground(): Promise<void> {
    Logger.d(TAG, 'App entering background');

    // Schedule background sync if needed
    if (this.syncManager) {
      await this.syncManager.scheduleBackgroundSync();
    }

    // Track analytics
    if (this.analyticsService) {
      this.analyticsService.trackEvent('app_background');
    }
  }

  /**
   * Gets the user repository instance
   */
  getUserRepository(): UserRepositoryImpl {
    if (!this.userRepository) {
      throw new Error('UserRepository not initialized. Call initialize() first.');
    }
    return this.userRepository;
  }

  /**
   * Gets the sync manager instance
   */
  getSyncManager(): SyncManager {
    if (!this.syncManager) {
      throw new Error('SyncManager not initialized. Call initialize() first.');
    }
    return this.syncManager;
  }

  /**
   * Gets the analytics service instance
   */
  getAnalyticsService(): AnalyticsService {
    if (!this.analyticsService) {
      throw new Error('AnalyticsService not initialized. Call initialize() first.');
    }
    return this.analyticsService;
  }

  /**
   * Cleanup all resources
   */
  cleanup(): void {
    Logger.d(TAG, 'Cleaning up app resources');

    if (this.userRepository) {
      this.userRepository.destroy();
      this.userRepository = null;
    }

    if (this.syncManager) {
      this.syncManager.destroy();
      this.syncManager = null;
    }

    if (this.analyticsService) {
      this.analyticsService.destroy();
      this.analyticsService = null;
    }

    NetworkMonitor.destroy();

    this.initialized = false;
    AppInitializer.instance = null;
  }
}

// Module-level context storage for ServiceLocator
let serviceLocatorContext: common.UIAbilityContext | null = null;

/**
 * Global service locator for accessing dependencies from UI components.
 * This provides a simple way to access services without prop drilling.
 */
export class ServiceLocator {
  /**
   * Sets the application context
   */
  static setContext(context: common.UIAbilityContext): void {
    serviceLocatorContext = context;
  }

  /**
   * Gets the user repository
   */
  static getUserRepository(): UserRepositoryImpl {
    if (!serviceLocatorContext) {
      throw new Error('Context not set. Call setContext() first.');
    }
    return AppInitializer.getInstance(serviceLocatorContext).getUserRepository();
  }

  /**
   * Gets the sync manager
   */
  static getSyncManager(): SyncManager {
    if (!serviceLocatorContext) {
      throw new Error('Context not set. Call setContext() first.');
    }
    return AppInitializer.getInstance(serviceLocatorContext).getSyncManager();
  }

  /**
   * Gets the analytics service
   */
  static getAnalyticsService(): AnalyticsService {
    if (!serviceLocatorContext) {
      throw new Error('Context not set. Call setContext() first.');
    }
    return AppInitializer.getInstance(serviceLocatorContext).getAnalyticsService();
  }
}
