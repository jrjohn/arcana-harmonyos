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
    console.info(`${TAG}: onWorkStart - workId: ${workInfo.workId}`);

    let workType: string = WorkType.SYNC;
    if (workInfo.parameters !== undefined) {
      const params = workInfo.parameters;
      if (params['workType'] !== undefined) {
        workType = params['workType'] as string;
      }
    }

    console.info(`${TAG}: Executing work type: ${workType}`);

    // Execute the appropriate work based on type
    this.executeWork(workType).then((success) => {
      console.info(`${TAG}: Work completed - success: ${success}`);
    }).catch((error: Error) => {
      console.error(`${TAG}: Work failed - error: ${error.message}`);
    });
  }

  /**
   * Called when the work should stop (timeout, cancellation, or completion)
   */
  onWorkStop(workInfo: workScheduler.WorkInfo): void {
    console.info(`${TAG}: onWorkStop - workId: ${workInfo.workId}`);
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
          console.warn(`${TAG}: Unknown work type: ${workType}`);
          return false;
      }
    } catch (error) {
      console.error(`${TAG}: executeWork failed: ${error}`);
      return false;
    }
  }

  /**
   * Perform sync of pending user data
   */
  private async performSync(): Promise<boolean> {
    console.info(`${TAG}: Starting sync operation...`);

    try {
      const executor = new SyncExecutor();
      const result = await executor.executePendingSync();

      console.info(`${TAG}: Sync completed - synced: ${result.syncedCount}, failed: ${result.failedCount}`);
      return result.failedCount === 0;
    } catch (error) {
      console.error(`${TAG}: Sync failed: ${error}`);
      return false;
    }
  }

  /**
   * Perform cache cleanup
   */
  private async performCacheCleanup(): Promise<boolean> {
    console.info(`${TAG}: Starting cache cleanup...`);

    try {
      const purgedCount = CacheManager.purgeAllExpired();
      console.info(`${TAG}: Cache cleanup completed - purged: ${purgedCount} entries`);
      return true;
    } catch (error) {
      console.error(`${TAG}: Cache cleanup failed: ${error}`);
      return false;
    }
  }

  /**
   * Perform analytics upload
   */
  private async performAnalyticsUpload(): Promise<boolean> {
    console.info(`${TAG}: Starting analytics upload...`);

    try {
      // Analytics upload would be implemented here
      // For now, just log completion
      console.info(`${TAG}: Analytics upload completed`);
      return true;
    } catch (error) {
      console.error(`${TAG}: Analytics upload failed: ${error}`);
      return false;
    }
  }

  /**
   * Perform data refresh
   */
  private async performDataRefresh(): Promise<boolean> {
    console.info(`${TAG}: Starting data refresh...`);

    try {
      const executor = new SyncExecutor();
      await executor.refreshAllData();

      console.info(`${TAG}: Data refresh completed`);
      return true;
    } catch (error) {
      console.error(`${TAG}: Data refresh failed: ${error}`);
      return false;
    }
  }
}
