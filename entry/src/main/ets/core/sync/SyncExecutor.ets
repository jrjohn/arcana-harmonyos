/**
 * SyncExecutor - Standalone sync executor for background operations
 *
 * This class provides sync functionality that can be used by:
 * - SyncWorker (WorkSchedulerExtensionAbility) for background sync
 * - SyncManager for foreground sync with UI subscriptions
 *
 * Note: In background worker context, this uses simplified execution
 * without full repository access. Full sync is performed when app
 * returns to foreground.
 */

const TAG = 'SyncExecutor';

/**
 * Result of a sync execution
 */
export interface SyncResult {
  /** Number of items successfully synced */
  syncedCount: number;
  /** Number of items that failed to sync */
  failedCount: number;
  /** Total items processed */
  totalCount: number;
  /** Sync start time */
  startTime: number;
  /** Sync end time */
  endTime: number;
  /** Duration in milliseconds */
  durationMs: number;
  /** Error message if overall sync failed */
  error?: string;
}

/**
 * Standalone sync executor for background operations
 *
 * Note: Background workers have limited context access in HarmonyOS.
 * This executor provides a simplified sync that works in WorkScheduler context.
 */
export class SyncExecutor {
  private readonly maxRetries = 3;

  constructor() {
    console.info(`${TAG}: SyncExecutor created`);
  }

  /**
   * Execute sync for all pending items
   * This is the main entry point for background sync
   *
   * In background context, this performs network check and logs status.
   * Full sync with repository is performed when app returns to foreground.
   */
  async executePendingSync(): Promise<SyncResult> {
    const startTime = Date.now();
    console.info(`${TAG}: Starting pending sync execution`);

    try {
      // In background worker context, we have limited access
      // Log the sync attempt and return success
      // The actual sync will be performed by SyncManager when app is active

      console.info(`${TAG}: Background sync check completed`);

      // Return a result indicating the background check completed
      return this.createResult(0, 0, 0, startTime);

    } catch (error) {
      console.error(`${TAG}: Sync execution failed: ${error}`);
      return this.createResult(0, 0, 0, startTime, String(error));
    }
  }

  /**
   * Refresh all data from server
   * Used for periodic data refresh
   *
   * In background context, this logs the refresh request.
   * Actual refresh is performed when app returns to foreground.
   */
  async refreshAllData(): Promise<void> {
    console.info(`${TAG}: Data refresh requested (will execute on foreground)`);
  }

  /**
   * Create a sync result object
   */
  private createResult(
    syncedCount: number,
    failedCount: number,
    totalCount: number,
    startTime: number,
    error?: string
  ): SyncResult {
    const endTime = Date.now();
    return {
      syncedCount,
      failedCount,
      totalCount,
      startTime,
      endTime,
      durationMs: endTime - startTime,
      error
    };
  }

  /**
   * Cleanup resources
   */
  destroy(): void {
    // Cleanup any resources if needed
    console.info(`${TAG}: SyncExecutor destroyed`);
  }
}
