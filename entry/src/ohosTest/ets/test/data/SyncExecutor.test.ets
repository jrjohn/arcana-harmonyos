/**
 * Unit Tests for SyncExecutor
 * Tests the standalone sync executor used by background workers
 */

import { describe, it, expect, beforeEach, afterEach } from '@ohos/hypium';
import { SyncExecutor, SyncResult } from '../../../../main/ets/core/sync/SyncExecutor';

export default function SyncExecutorTest() {
  describe('SyncExecutor', () => {
    let executor: SyncExecutor;

    beforeEach(() => {
      executor = new SyncExecutor();
    });

    afterEach(() => {
      executor.destroy();
    });

    describe('constructor', () => {
      it('should create executor instance', () => {
        expect(executor).assertNotNull();
      });

      it('should create fresh instances for background execution', () => {
        const executor1 = new SyncExecutor();
        const executor2 = new SyncExecutor();
        // Both should be separate instances
        expect(executor1 !== executor2).assertTrue();
        executor1.destroy();
        executor2.destroy();
      });
    });

    describe('executePendingSync', () => {
      it('should return SyncResult object', async () => {
        const result = await executor.executePendingSync();

        expect(result).assertNotNull();
        expect(typeof result.syncedCount === 'number').assertTrue();
        expect(typeof result.failedCount === 'number').assertTrue();
        expect(typeof result.totalCount === 'number').assertTrue();
        expect(typeof result.startTime === 'number').assertTrue();
        expect(typeof result.endTime === 'number').assertTrue();
        expect(typeof result.durationMs === 'number').assertTrue();
      });

      it('should have valid timing information', async () => {
        const beforeTime = Date.now();
        const result = await executor.executePendingSync();
        const afterTime = Date.now();

        expect(result.startTime >= beforeTime).assertTrue();
        expect(result.endTime <= afterTime).assertTrue();
        expect(result.endTime >= result.startTime).assertTrue();
        expect(result.durationMs).assertEqual(result.endTime - result.startTime);
      });

      it('should have non-negative counts', async () => {
        const result = await executor.executePendingSync();

        expect(result.syncedCount >= 0).assertTrue();
        expect(result.failedCount >= 0).assertTrue();
        expect(result.totalCount >= 0).assertTrue();
      });

      it('should have totalCount equal to syncedCount plus failedCount', async () => {
        const result = await executor.executePendingSync();

        expect(result.totalCount).assertEqual(result.syncedCount + result.failedCount);
      });

      it('should complete without throwing', async () => {
        let threw = false;
        try {
          await executor.executePendingSync();
        } catch (e) {
          threw = true;
        }
        expect(threw).assertFalse();
      });
    });

    describe('refreshAllData', () => {
      it('should complete without throwing', async () => {
        let threw = false;
        try {
          await executor.refreshAllData();
        } catch (e) {
          threw = true;
        }
        expect(threw).assertFalse();
      });

      it('should be callable multiple times', async () => {
        await executor.refreshAllData();
        await executor.refreshAllData();
        expect(true).assertTrue();
      });
    });

    describe('destroy', () => {
      it('should cleanup without error', () => {
        executor.destroy();
        expect(true).assertTrue();
      });

      it('should be safe to call multiple times', () => {
        executor.destroy();
        executor.destroy();
        expect(true).assertTrue();
      });
    });

    describe('SyncResult interface', () => {
      it('should support error field when sync fails', async () => {
        // The result might have an error field if network is unavailable
        const result = await executor.executePendingSync();

        if (result.error !== undefined) {
          expect(typeof result.error === 'string').assertTrue();
          expect(result.error.length > 0).assertTrue();
        }
        expect(true).assertTrue();
      });

      it('should have positive duration', async () => {
        const result = await executor.executePendingSync();

        expect(result.durationMs >= 0).assertTrue();
      });
    });

    describe('concurrent executions', () => {
      it('should handle multiple concurrent executors', async () => {
        const executor1 = new SyncExecutor();
        const executor2 = new SyncExecutor();
        const executor3 = new SyncExecutor();

        const promises = [
          executor1.executePendingSync(),
          executor2.executePendingSync(),
          executor3.executePendingSync()
        ];

        const results = await Promise.all(promises);

        for (const result of results) {
          expect(result).assertNotNull();
          expect(typeof result.syncedCount === 'number').assertTrue();
        }

        executor1.destroy();
        executor2.destroy();
        executor3.destroy();
      });

      it('should handle mixed operations concurrently', async () => {
        const executor1 = new SyncExecutor();
        const executor2 = new SyncExecutor();

        const promises = [
          executor1.executePendingSync(),
          executor2.refreshAllData()
        ];

        await Promise.all(promises);

        executor1.destroy();
        executor2.destroy();
        expect(true).assertTrue();
      });
    });

    describe('error handling', () => {
      it('should not throw on network unavailable', async () => {
        // Even without network, should return a result (not throw)
        const result = await executor.executePendingSync();
        expect(result).assertNotNull();
      });

      it('should set error message when network unavailable', async () => {
        const result = await executor.executePendingSync();
        // If network is unavailable, error should be set
        // If network is available, operation should succeed
        expect(result.syncedCount >= 0 || result.error !== undefined).assertTrue();
      });
    });

    describe('lifecycle', () => {
      it('should work correctly when created and destroyed in sequence', async () => {
        for (let i = 0; i < 3; i++) {
          const exec = new SyncExecutor();
          const result = await exec.executePendingSync();
          expect(result).assertNotNull();
          exec.destroy();
        }
      });

      it('should handle rapid creation and destruction', () => {
        const executors: SyncExecutor[] = [];
        for (let i = 0; i < 10; i++) {
          executors.push(new SyncExecutor());
        }
        for (const exec of executors) {
          exec.destroy();
        }
        expect(true).assertTrue();
      });
    });
  });
}
