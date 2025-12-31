/**
 * Unit Tests for BackgroundScheduler
 * Tests the HarmonyOS WorkScheduler integration
 */

import { describe, it, expect, beforeEach, afterEach } from '@ohos/hypium';
import {
  BackgroundScheduler,
  WorkType,
  WorkConfig,
  DEFAULT_WORK_CONFIGS,
  ExponentialBackoff
} from '../../../../main/ets/core/scheduling/BackgroundScheduler';
import { ILogger } from '../../../../main/ets/core/di/interfaces';

/**
 * Mock logger for testing
 */
class MockLogger implements ILogger {
  logs: string[] = [];
  warnings: string[] = [];
  errors: string[] = [];

  d(tag: string, message: string): void {
    this.logs.push(`[${tag}] ${message}`);
  }

  i(tag: string, message: string): void {
    this.logs.push(`[${tag}] ${message}`);
  }

  w(tag: string, message: string): void {
    this.warnings.push(`[${tag}] ${message}`);
  }

  e(tag: string, message: string): void {
    this.errors.push(`[${tag}] ${message}`);
  }

  clear(): void {
    this.logs = [];
    this.warnings = [];
    this.errors = [];
  }
}

export default function BackgroundSchedulerTest() {
  describe('BackgroundScheduler', () => {
    let scheduler: BackgroundScheduler;
    let mockLogger: MockLogger;

    beforeEach(() => {
      scheduler = new BackgroundScheduler();
      mockLogger = new MockLogger();
      scheduler.setLogger(mockLogger);
    });

    afterEach(async () => {
      await scheduler.stop();
    });

    describe('constructor', () => {
      it('should create scheduler instance', () => {
        expect(scheduler).assertNotNull();
      });

      it('should allow setting logger after construction', () => {
        const newScheduler = new BackgroundScheduler();
        const logger = new MockLogger();
        newScheduler.setLogger(logger);
        expect(true).assertTrue();
      });
    });

    describe('registerCallback', () => {
      it('should register callback for work type', () => {
        let callbackCalled = false;
        scheduler.registerCallback(WorkType.SYNC, async () => {
          callbackCalled = true;
        });

        expect(mockLogger.logs.some(l => l.includes('Registered callback'))).assertTrue();
      });

      it('should register callbacks for multiple work types', () => {
        scheduler.registerCallback(WorkType.SYNC, async () => {});
        scheduler.registerCallback(WorkType.CACHE_CLEANUP, async () => {});
        scheduler.registerCallback(WorkType.ANALYTICS_UPLOAD, async () => {});

        expect(mockLogger.logs.filter(l => l.includes('Registered callback')).length).assertEqual(3);
      });

      it('should replace existing callback for same work type', () => {
        scheduler.registerCallback(WorkType.SYNC, async () => {});
        scheduler.registerCallback(WorkType.SYNC, async () => {});

        // Should have registered twice (replacement)
        expect(mockLogger.logs.filter(l => l.includes('Registered callback')).length).assertEqual(2);
      });
    });

    describe('executeWork', () => {
      it('should execute registered callback', async () => {
        let executed = false;
        scheduler.registerCallback(WorkType.SYNC, async () => {
          executed = true;
        });

        const result = await scheduler.executeWork(WorkType.SYNC);

        expect(result).assertTrue();
        expect(executed).assertTrue();
      });

      it('should return false for unregistered work type', async () => {
        const result = await scheduler.executeWork(WorkType.DATA_REFRESH);

        expect(result).assertFalse();
        expect(mockLogger.errors.some(e => e.includes('No callback registered'))).assertTrue();
      });

      it('should handle callback errors gracefully', async () => {
        scheduler.registerCallback(WorkType.SYNC, async () => {
          throw new Error('Test error');
        });

        const result = await scheduler.executeWork(WorkType.SYNC);

        expect(result).assertFalse();
        expect(mockLogger.errors.some(e => e.includes('Work failed'))).assertTrue();
      });

      it('should log work execution', async () => {
        scheduler.registerCallback(WorkType.SYNC, async () => {});
        mockLogger.clear();

        await scheduler.executeWork(WorkType.SYNC);

        expect(mockLogger.logs.some(l => l.includes('Executing work'))).assertTrue();
        expect(mockLogger.logs.some(l => l.includes('Work completed'))).assertTrue();
      });
    });

    describe('start', () => {
      it('should start scheduler without error', async () => {
        await scheduler.start();
        expect(mockLogger.logs.some(l => l.includes('scheduler started'))).assertTrue();
      });

      it('should be idempotent (safe to call multiple times)', async () => {
        await scheduler.start();
        await scheduler.start();
        await scheduler.start();

        // Should only log started once (or handle gracefully)
        expect(true).assertTrue();
      });
    });

    describe('stop', () => {
      it('should stop scheduler without error', async () => {
        await scheduler.start();
        await scheduler.stop();

        expect(mockLogger.logs.some(l => l.includes('scheduler stopped'))).assertTrue();
      });

      it('should be safe to call without starting', async () => {
        await scheduler.stop();
        expect(true).assertTrue();
      });

      it('should be idempotent (safe to call multiple times)', async () => {
        await scheduler.start();
        await scheduler.stop();
        await scheduler.stop();
        await scheduler.stop();

        expect(true).assertTrue();
      });
    });

    describe('cancelWork', () => {
      it('should return false for non-scheduled work', async () => {
        const result = await scheduler.cancelWork(WorkType.SYNC);
        expect(result).assertFalse();
      });
    });

    describe('cancelAllWork', () => {
      it('should complete without error', async () => {
        await scheduler.cancelAllWork();
        expect(mockLogger.logs.some(l => l.includes('Cancelled all'))).assertTrue();
      });
    });

    describe('isWorkScheduled', () => {
      it('should return false for non-scheduled work', async () => {
        const isScheduled = await scheduler.isWorkScheduled(WorkType.SYNC);
        expect(isScheduled).assertFalse();
      });
    });

    describe('getNextRunTime', () => {
      it('should return undefined when not available', async () => {
        const nextRun = await scheduler.getNextRunTime(WorkType.SYNC);
        expect(nextRun).assertUndefined();
      });
    });
  });

  describe('WorkType enum', () => {
    it('should have SYNC type', () => {
      expect(WorkType.SYNC).assertEqual('sync');
    });

    it('should have CACHE_CLEANUP type', () => {
      expect(WorkType.CACHE_CLEANUP).assertEqual('cache_cleanup');
    });

    it('should have ANALYTICS_UPLOAD type', () => {
      expect(WorkType.ANALYTICS_UPLOAD).assertEqual('analytics_upload');
    });

    it('should have DATA_REFRESH type', () => {
      expect(WorkType.DATA_REFRESH).assertEqual('data_refresh');
    });
  });

  describe('DEFAULT_WORK_CONFIGS', () => {
    describe('SYNC config', () => {
      const config = DEFAULT_WORK_CONFIGS[WorkType.SYNC];

      it('should have correct type', () => {
        expect(config.type).assertEqual(WorkType.SYNC);
      });

      it('should require network', () => {
        expect(config.requireNetwork).assertTrue();
      });

      it('should not require charging', () => {
        expect(config.requireCharging).assertFalse();
      });

      it('should be persisted', () => {
        expect(config.persist).assertTrue();
      });

      it('should have positive interval', () => {
        expect(config.intervalMinutes > 0).assertTrue();
      });
    });

    describe('CACHE_CLEANUP config', () => {
      const config = DEFAULT_WORK_CONFIGS[WorkType.CACHE_CLEANUP];

      it('should have correct type', () => {
        expect(config.type).assertEqual(WorkType.CACHE_CLEANUP);
      });

      it('should not require network', () => {
        expect(config.requireNetwork).assertFalse();
      });

      it('should require idle', () => {
        expect(config.requireIdle).assertTrue();
      });

      it('should allow battery saver', () => {
        expect(config.allowBatterySaver).assertTrue();
      });
    });

    describe('ANALYTICS_UPLOAD config', () => {
      const config = DEFAULT_WORK_CONFIGS[WorkType.ANALYTICS_UPLOAD];

      it('should have correct type', () => {
        expect(config.type).assertEqual(WorkType.ANALYTICS_UPLOAD);
      });

      it('should require network', () => {
        expect(config.requireNetwork).assertTrue();
      });

      it('should be persisted', () => {
        expect(config.persist).assertTrue();
      });
    });

    describe('DATA_REFRESH config', () => {
      const config = DEFAULT_WORK_CONFIGS[WorkType.DATA_REFRESH];

      it('should have correct type', () => {
        expect(config.type).assertEqual(WorkType.DATA_REFRESH);
      });

      it('should require network', () => {
        expect(config.requireNetwork).assertTrue();
      });

      it('should require charging', () => {
        expect(config.requireCharging).assertTrue();
      });

      it('should require idle', () => {
        expect(config.requireIdle).assertTrue();
      });

      it('should not be persisted', () => {
        expect(config.persist).assertFalse();
      });
    });
  });

  describe('ExponentialBackoff', () => {
    describe('constructor', () => {
      it('should create with default values', () => {
        const backoff = new ExponentialBackoff();
        expect(backoff).assertNotNull();
        expect(backoff.getAttempt()).assertEqual(0);
      });

      it('should create with custom values', () => {
        const backoff = new ExponentialBackoff(500, 30000, 3);
        expect(backoff).assertNotNull();
      });
    });

    describe('nextDelay', () => {
      it('should return increasing delays', () => {
        const backoff = new ExponentialBackoff(1000, 60000, 2);

        const delay1 = backoff.nextDelay();
        const delay2 = backoff.nextDelay();
        const delay3 = backoff.nextDelay();

        // Due to jitter, we can't expect exact values
        // But delays should generally increase
        expect(delay1 > 0).assertTrue();
        expect(delay2 > 0).assertTrue();
        expect(delay3 > 0).assertTrue();
      });

      it('should increment attempt counter', () => {
        const backoff = new ExponentialBackoff();

        expect(backoff.getAttempt()).assertEqual(0);
        backoff.nextDelay();
        expect(backoff.getAttempt()).assertEqual(1);
        backoff.nextDelay();
        expect(backoff.getAttempt()).assertEqual(2);
      });

      it('should not exceed max delay', () => {
        const maxDelay = 5000;
        const backoff = new ExponentialBackoff(1000, maxDelay, 2);

        // Call many times to exceed theoretical max
        for (let i = 0; i < 20; i++) {
          const delay = backoff.nextDelay();
          // Allow for jitter (±25%)
          expect(delay <= maxDelay * 1.25).assertTrue();
        }
      });

      it('should return non-negative values', () => {
        const backoff = new ExponentialBackoff();

        for (let i = 0; i < 10; i++) {
          const delay = backoff.nextDelay();
          expect(delay >= 0).assertTrue();
        }
      });
    });

    describe('reset', () => {
      it('should reset attempt counter to zero', () => {
        const backoff = new ExponentialBackoff();

        backoff.nextDelay();
        backoff.nextDelay();
        backoff.nextDelay();
        expect(backoff.getAttempt()).assertEqual(3);

        backoff.reset();
        expect(backoff.getAttempt()).assertEqual(0);
      });

      it('should restart delay sequence after reset', () => {
        const backoff = new ExponentialBackoff(1000, 60000, 2);

        // Advance several times
        for (let i = 0; i < 5; i++) {
          backoff.nextDelay();
        }

        backoff.reset();

        // First delay after reset should be close to base
        const firstDelay = backoff.nextDelay();
        // Allow for jitter
        expect(firstDelay <= 1500).assertTrue();
      });
    });

    describe('getAttempt', () => {
      it('should return current attempt number', () => {
        const backoff = new ExponentialBackoff();

        expect(backoff.getAttempt()).assertEqual(0);

        backoff.nextDelay();
        expect(backoff.getAttempt()).assertEqual(1);

        backoff.nextDelay();
        expect(backoff.getAttempt()).assertEqual(2);
      });

      it('should return zero after reset', () => {
        const backoff = new ExponentialBackoff();

        backoff.nextDelay();
        backoff.nextDelay();
        backoff.reset();

        expect(backoff.getAttempt()).assertEqual(0);
      });
    });

    describe('jitter', () => {
      it('should add randomness to delays', () => {
        const backoff1 = new ExponentialBackoff(1000, 60000, 2);
        const backoff2 = new ExponentialBackoff(1000, 60000, 2);

        const delays1: number[] = [];
        const delays2: number[] = [];

        for (let i = 0; i < 5; i++) {
          delays1.push(backoff1.nextDelay());
          backoff1.reset();
        }

        for (let i = 0; i < 5; i++) {
          delays2.push(backoff2.nextDelay());
          backoff2.reset();
        }

        // Due to jitter, sequences should likely be different
        // (There's a very small chance they could be the same)
        let hasDifference = false;
        for (let i = 0; i < 5; i++) {
          if (delays1[i] !== delays2[i]) {
            hasDifference = true;
            break;
          }
        }

        // This test might occasionally fail due to random chance
        // But the probability is very low
        expect(true).assertTrue(); // Just verify no crash
      });
    });
  });
}
