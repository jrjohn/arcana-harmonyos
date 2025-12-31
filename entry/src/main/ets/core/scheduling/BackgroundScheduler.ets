/**
 * Background Scheduler using HarmonyOS WorkScheduler
 * Replaces setTimeout-based background tasks with proper system scheduling
 */

import { workScheduler } from '@kit.BackgroundTasksKit';
import { injectable, preDestroy } from '../di/decorators';
import { ILogger } from '../di/interfaces';

const TAG = 'BackgroundScheduler';

/**
 * Work types for background tasks
 */
export enum WorkType {
  /** Sync pending data with server */
  SYNC = 'sync',
  /** Clean up expired cache */
  CACHE_CLEANUP = 'cache_cleanup',
  /** Upload analytics events */
  ANALYTICS_UPLOAD = 'analytics_upload',
  /** Refresh user data */
  DATA_REFRESH = 'data_refresh'
}

/**
 * Work configuration
 */
export interface WorkConfig {
  /** Work type identifier */
  type: WorkType;
  /** Minimum interval in minutes */
  intervalMinutes: number;
  /** Require network connectivity */
  requireNetwork: boolean;
  /** Require device charging */
  requireCharging: boolean;
  /** Require device idle */
  requireIdle: boolean;
  /** Allow during battery saver mode */
  allowBatterySaver: boolean;
  /** Persist across reboots */
  persist: boolean;
}

/**
 * Default work configurations
 */
export const DEFAULT_WORK_CONFIGS: Record<WorkType, WorkConfig> = {
  [WorkType.SYNC]: {
    type: WorkType.SYNC,
    intervalMinutes: 15,
    requireNetwork: true,
    requireCharging: false,
    requireIdle: false,
    allowBatterySaver: false,
    persist: true
  },
  [WorkType.CACHE_CLEANUP]: {
    type: WorkType.CACHE_CLEANUP,
    intervalMinutes: 60,
    requireNetwork: false,
    requireCharging: false,
    requireIdle: true,
    allowBatterySaver: true,
    persist: true
  },
  [WorkType.ANALYTICS_UPLOAD]: {
    type: WorkType.ANALYTICS_UPLOAD,
    intervalMinutes: 30,
    requireNetwork: true,
    requireCharging: false,
    requireIdle: false,
    allowBatterySaver: false,
    persist: true
  },
  [WorkType.DATA_REFRESH]: {
    type: WorkType.DATA_REFRESH,
    intervalMinutes: 120,
    requireNetwork: true,
    requireCharging: true,
    requireIdle: true,
    allowBatterySaver: false,
    persist: false
  }
};

/**
 * Work execution callback
 */
export type WorkCallback = () => Promise<void>;

/**
 * Background Scheduler interface
 */
export interface IBackgroundScheduler {
  /** Schedule a periodic work */
  schedulePeriodicWork(config: WorkConfig): Promise<boolean>;

  /** Schedule a one-time work */
  scheduleOneTimeWork(type: WorkType, delayMinutes: number): Promise<boolean>;

  /** Cancel scheduled work */
  cancelWork(type: WorkType): Promise<boolean>;

  /** Cancel all scheduled work */
  cancelAllWork(): Promise<void>;

  /** Check if work is scheduled */
  isWorkScheduled(type: WorkType): Promise<boolean>;

  /** Get next scheduled run time */
  getNextRunTime(type: WorkType): Promise<number | undefined>;

  /** Register work callback */
  registerCallback(type: WorkType, callback: WorkCallback): void;

  /** Start the scheduler */
  start(): Promise<void>;

  /** Stop the scheduler */
  stop(): Promise<void>;
}

/**
 * Background Scheduler implementation
 */
@injectable()
export class BackgroundScheduler implements IBackgroundScheduler {
  private logger?: ILogger;
  private callbacks = new Map<WorkType, WorkCallback>();
  private workIds = new Map<WorkType, number>();
  private isRunning = false;

  constructor() {}

  setLogger(logger: ILogger): void {
    this.logger = logger;
  }

  async schedulePeriodicWork(config: WorkConfig): Promise<boolean> {
    try {
      const workInfo = this.createWorkInfo(config, true);
      const workId = workInfo.workId;

      await workScheduler.startWork(workInfo);
      this.workIds.set(config.type, workId);

      this.log(`Scheduled periodic work: ${config.type} (interval: ${config.intervalMinutes}min)`);
      return true;
    } catch (error) {
      this.logError(`Failed to schedule periodic work ${config.type}: ${error}`);
      return false;
    }
  }

  async scheduleOneTimeWork(type: WorkType, delayMinutes: number): Promise<boolean> {
    try {
      const config = DEFAULT_WORK_CONFIGS[type];
      const generatedWorkId = this.generateWorkId(type);
      const workInfo: workScheduler.WorkInfo = {
        workId: generatedWorkId,
        bundleName: 'com.arcana.harmonyos',
        abilityName: 'SyncWorker',
        networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY,
        isCharging: config.requireCharging,
        isPersisted: false,
        isRepeat: false,
        parameters: {
          workType: type
        }
      };

      await workScheduler.startWork(workInfo);
      this.workIds.set(type, generatedWorkId);

      this.log(`Scheduled one-time work: ${type} (delay: ${delayMinutes}min)`);
      return true;
    } catch (error) {
      this.logError(`Failed to schedule one-time work ${type}: ${error}`);
      return false;
    }
  }

  async cancelWork(type: WorkType): Promise<boolean> {
    try {
      const workId = this.workIds.get(type);
      if (workId !== undefined) {
        const workInfo: workScheduler.WorkInfo = {
          workId: workId,
          bundleName: 'com.arcana.harmonyos',
          abilityName: 'SyncWorker'
        };
        await workScheduler.stopWork(workInfo);
        this.workIds.delete(type);
        this.log(`Cancelled work: ${type}`);
        return true;
      }
      return false;
    } catch (error) {
      this.logError(`Failed to cancel work ${type}: ${error}`);
      return false;
    }
  }

  async cancelAllWork(): Promise<void> {
    try {
      await workScheduler.stopAndClearWorks();
      this.workIds.clear();
      this.log('Cancelled all scheduled work');
    } catch (error) {
      this.logError(`Failed to cancel all work: ${error}`);
    }
  }

  async isWorkScheduled(type: WorkType): Promise<boolean> {
    try {
      const workId = this.workIds.get(type);
      if (workId === undefined) return false;

      const status = await workScheduler.getWorkStatus(workId);
      return status !== undefined;
    } catch {
      return false;
    }
  }

  async getNextRunTime(type: WorkType): Promise<number | undefined> {
    // WorkScheduler doesn't expose next run time directly
    // This is a placeholder - would need to track manually
    return undefined;
  }

  registerCallback(type: WorkType, callback: WorkCallback): void {
    this.callbacks.set(type, callback);
    this.log(`Registered callback for: ${type}`);
  }

  async start(): Promise<void> {
    if (this.isRunning) return;

    try {
      // Schedule default periodic works
      await this.schedulePeriodicWork(DEFAULT_WORK_CONFIGS[WorkType.SYNC]);
      await this.schedulePeriodicWork(DEFAULT_WORK_CONFIGS[WorkType.CACHE_CLEANUP]);
      await this.schedulePeriodicWork(DEFAULT_WORK_CONFIGS[WorkType.ANALYTICS_UPLOAD]);

      this.isRunning = true;
      this.log('Background scheduler started');
    } catch (error) {
      this.logError(`Failed to start scheduler: ${error}`);
    }
  }

  @preDestroy()
  async stop(): Promise<void> {
    if (!this.isRunning) return;

    await this.cancelAllWork();
    this.callbacks.clear();
    this.isRunning = false;
    this.log('Background scheduler stopped');
  }

  /**
   * Execute work (called by WorkSchedulerExtensionAbility)
   */
  async executeWork(type: WorkType): Promise<boolean> {
    const callback = this.callbacks.get(type);
    if (!callback) {
      this.logError(`No callback registered for work: ${type}`);
      return false;
    }

    try {
      this.log(`Executing work: ${type}`);
      await callback();
      this.log(`Work completed: ${type}`);
      return true;
    } catch (error) {
      this.logError(`Work failed ${type}: ${error}`);
      return false;
    }
  }

  // ===== Private Methods =====

  private createWorkInfo(config: WorkConfig, isRepeat: boolean): workScheduler.WorkInfo {
    const workInfo: workScheduler.WorkInfo = {
      workId: this.generateWorkId(config.type),
      bundleName: 'com.arcana.harmonyos',
      abilityName: 'SyncWorker',
      networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY,
      isCharging: config.requireCharging,
      isPersisted: config.persist,
      isRepeat: isRepeat,
      repeatCycleTime: config.intervalMinutes * 60 * 1000, // Convert to ms
      parameters: {
        workType: config.type
      }
    };
    return workInfo;
  }

  private generateWorkId(type: WorkType): number {
    // Generate unique work ID based on type
    const typeHash = this.hashString(type);
    return typeHash;
  }

  private hashString(str: string): number {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return Math.abs(hash);
  }

  private log(message: string): void {
    if (this.logger) {
      this.logger.d(TAG, message);
    }
  }

  private logError(message: string): void {
    if (this.logger) {
      this.logger.e(TAG, message);
    }
  }
}

/**
 * Exponential backoff calculator for retries
 */
export class ExponentialBackoff {
  private readonly baseDelayMs: number;
  private readonly maxDelayMs: number;
  private readonly multiplier: number;
  private attempt: number = 0;

  constructor(
    baseDelayMs: number = 1000,
    maxDelayMs: number = 60000,
    multiplier: number = 2
  ) {
    this.baseDelayMs = baseDelayMs;
    this.maxDelayMs = maxDelayMs;
    this.multiplier = multiplier;
  }

  /**
   * Get next delay with jitter
   */
  nextDelay(): number {
    const delay = Math.min(
      this.baseDelayMs * Math.pow(this.multiplier, this.attempt),
      this.maxDelayMs
    );

    // Add jitter (±25%)
    const jitter = delay * 0.25 * (Math.random() * 2 - 1);
    const finalDelay = Math.max(0, delay + jitter);

    this.attempt++;
    return Math.round(finalDelay);
  }

  /**
   * Reset attempt counter
   */
  reset(): void {
    this.attempt = 0;
  }

  /**
   * Get current attempt number
   */
  getAttempt(): number {
    return this.attempt;
  }
}
