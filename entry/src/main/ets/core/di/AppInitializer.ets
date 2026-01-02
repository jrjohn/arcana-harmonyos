/**
 * Application Initializer
 * Thin wrapper around AppContainer for backward compatibility
 * All actual initialization logic is now in AppContainer
 */

import { common } from '@kit.AbilityKit';
import { AppContainer, getContainer, inject } from './AppContainer';
import { TYPES } from './tokens';
import { IUserRepositoryService, ISyncManager, IAnalyticsService } from './interfaces';
import { Logger } from '../logging/Logger';

const TAG = 'AppInitializer';

/**
 * Application-level initializer.
 * Delegates to AppContainer for all dependency management.
 *
 * @deprecated Use AppContainer directly for new code.
 * This class is kept for backward compatibility during migration.
 */
export class AppInitializer {
  private static instance: AppInitializer | null = null;
  private container: AppContainer;

  private constructor() {
    this.container = getContainer();
  }

  /**
   * Gets the singleton instance
   * @deprecated Use getContainer() instead
   */
  static getInstance(context: common.UIAbilityContext): AppInitializer {
    if (!AppInitializer.instance) {
      AppInitializer.instance = new AppInitializer();
    }
    // Store context for initialization
    (AppInitializer.instance as AppInitializer).initContext = context;
    return AppInitializer.instance;
  }

  private initContext: common.UIAbilityContext | null = null;

  /**
   * Initializes all application dependencies
   */
  async initialize(): Promise<void> {
    if (this.container.isInitialized()) {
      Logger.d(TAG, 'Already initialized');
      return;
    }

    if (!this.initContext) {
      throw new Error('Context not set. Call getInstance(context) first.');
    }

    await this.container.initialize(this.initContext);
  }

  /**
   * Called when app comes to foreground
   */
  async onForeground(): Promise<void> {
    await this.container.onForeground();
  }

  /**
   * Called when app goes to background
   */
  async onBackground(): Promise<void> {
    await this.container.onBackground();
  }

  /**
   * Gets the user repository instance
   * @deprecated Use inject<IUserRepositoryService>(TYPES.UserRepository) instead
   */
  getUserRepository(): IUserRepositoryService {
    return this.container.getUserRepository();
  }

  /**
   * Gets the sync manager instance
   * @deprecated Use inject<ISyncManager>(TYPES.SyncManager) instead
   */
  getSyncManager(): ISyncManager {
    return this.container.getSyncManager();
  }

  /**
   * Gets the analytics service instance
   * @deprecated Use inject<IAnalyticsService>(TYPES.AnalyticsService) instead
   */
  getAnalyticsService(): IAnalyticsService {
    return this.container.getAnalyticsService();
  }

  /**
   * Cleanup all resources
   */
  async cleanup(): Promise<void> {
    Logger.d(TAG, 'Cleaning up app resources');
    await this.container.dispose();
    AppInitializer.instance = null;
  }
}

// Re-export container functions for convenience
export { getContainer, inject, TYPES };
