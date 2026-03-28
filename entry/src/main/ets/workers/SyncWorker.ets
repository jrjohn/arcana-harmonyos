/**
 * SyncWorker - WorkSchedulerExtensionAbility for background sync
 *
 * This worker is triggered by the system when scheduling conditions are met.
 * It handles background synchronization of pending user data.
 *
 * Constraints:
 * - Maximum 2 minutes execution time per invocation
 * - Cannot use camera, audio, or media APIs
 * - System may delay based on battery, memory, or temperature
 */

import { WorkSchedulerExtensionAbility, workScheduler } from '@kit.BackgroundTasksKit';
import { Logger } from '../core/logging/Logger';
import { WorkType } from '../core/scheduling/BackgroundScheduler';
import { SyncExecutor } from '../core/sync/SyncExecutor';
import { CacheManager } from '../data/cache/LruCache';

const TAG = 'SyncWorker';

/**
 * SyncWorker handles background sync operations
 */
export default class SyncWorker extends WorkSchedulerExtensionAbility {
  /**
   * Called when the system triggers the background work
   * Maximum execution time: 2 minutes
   */
  onWorkStart(workInfo: workScheduler.WorkInfo): void {
    Logger.i(TAG, `onWorkStart - workId: ${workInfo.workId}`);

    let workType: string = WorkType.SYNC;
    if (workInfo.parameters !== undefined) {
      const params = workInfo.parameters;
      if (params['workType'] !== undefined) {
        workType = params['workType'] as string;
      }
    }

    Logger.i(TAG, `Executing work type: ${workType}`);

    // Execute the appropriate work based on type
    this.executeWork(workType).then((success) => {
      Logger.i(TAG, `Work completed - success: ${success}`);
    }).catch((error: Error) => {
      Logger.e(TAG, `Work failed - error: ${error.message}`);
    });
  }

  /**
   * Called when the work should stop (timeout, cancellation, or completion)
   */
  onWorkStop(workInfo: workScheduler.WorkInfo): void {
    Logger.i(TAG, `onWorkStop - workId: ${workInfo.workId}`);
    // Cleanup any resources if needed
  }

  /**
   * Execute work based on type
   */
  private async executeWork(workType: string): Promise<boolean> {
    try {
      switch (workType) {
        case WorkType.SYNC:
          return await this.performSync();

        case WorkType.CACHE_CLEANUP:
          return await this.performCacheCleanup();

        case WorkType.ANALYTICS_UPLOAD:
          return await this.performAnalyticsUpload();

        case WorkType.DATA_REFRESH:
          return await this.performDataRefresh();

        default:
          Logger.w(TAG, `Unknown work type: ${workType}`);
          return false;
      }
    } catch (error) {
      Logger.e(TAG, `executeWork failed: ${error}`);
      return false;
    }
  }

  /**
   * Perform sync of pending user data
   */
  private async performSync(): Promise<boolean> {
    Logger.i(TAG, `Starting sync operation...`);

    try {
      const executor = new SyncExecutor();
      const result = await executor.executePendingSync();

      Logger.i(TAG, `Sync completed - synced: ${result.syncedCount}, failed: ${result.failedCount}`);
      return result.failedCount === 0;
    } catch (error) {
      Logger.e(TAG, `Sync failed: ${error}`);
      return false;
    }
  }

  /**
   * Perform cache cleanup
   */
  private async performCacheCleanup(): Promise<boolean> {
    Logger.i(TAG, `Starting cache cleanup...`);

    try {
      CacheManager.purgeAllExpired();
      Logger.i(TAG, `Cache cleanup completed`);
      return true;
    } catch (error) {
      Logger.e(TAG, `Cache cleanup failed: ${error}`);
      return false;
    }
  }

  /**
   * Perform analytics upload
   */
  private async performAnalyticsUpload(): Promise<boolean> {
    Logger.i(TAG, `Starting analytics upload...`);

    try {
      // Analytics upload would be implemented here
      // For now, just log completion
      Logger.i(TAG, `Analytics upload completed`);
      return true;
    } catch (error) {
      Logger.e(TAG, `Analytics upload failed: ${error}`);
      return false;
    }
  }

  /**
   * Perform data refresh
   */
  private async performDataRefresh(): Promise<boolean> {
    Logger.i(TAG, `Starting data refresh...`);

    try {
      const executor = new SyncExecutor();
      await executor.refreshAllData();

      Logger.i(TAG, `Data refresh completed`);
      return true;
    } catch (error) {
      Logger.e(TAG, `Data refresh failed: ${error}`);
      return false;
    }
  }
}
