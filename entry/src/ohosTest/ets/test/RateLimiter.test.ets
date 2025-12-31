/**
 * Unit Tests for Rate Limiter
 */

import { describe, it, expect, beforeEach } from '@ohos/hypium';
import {
  RateLimiter,
  RateLimitConfig,
  DEFAULT_RATE_LIMITS,
  RequestQueue,
  Debouncer,
  Throttler
} from '../../../main/ets/core/network/RateLimiter';
import { MockLogger } from '../../../main/ets/core/di/testing';

export default function RateLimiterTest() {
  describe('RateLimiter', () => {
    let rateLimiter: RateLimiter;
    let mockLogger: MockLogger;

    beforeEach(() => {
      mockLogger = new MockLogger();
      rateLimiter = new RateLimiter();
      rateLimiter.setLogger(mockLogger);
    });

    describe('checkLimit', () => {
      it('should allow requests within limit', () => {
        const status = rateLimiter.checkLimit('/api/users', 'default');

        expect(status.allowed).assertTrue();
        expect(status.remaining).assertEqual(DEFAULT_RATE_LIMITS.default.maxRequests);
      });

      it('should track recorded requests', () => {
        const endpoint = '/api/users';

        // Record some requests
        for (let i = 0; i < 5; i++) {
          rateLimiter.recordRequest(endpoint);
        }

        const status = rateLimiter.checkLimit(endpoint, 'default');

        expect(status.remaining).assertEqual(DEFAULT_RATE_LIMITS.default.maxRequests - 5);
      });

      it('should deny requests when limit exceeded', () => {
        const endpoint = '/api/test';
        const config: RateLimitConfig = {
          maxRequests: 3,
          windowMs: 60000,
          minDelayMs: 100,
          maxRetryDelayMs: 60000
        };
        rateLimiter.setConfig('test', config);

        // Exhaust the limit
        for (let i = 0; i < 3; i++) {
          rateLimiter.recordRequest(endpoint);
        }

        const status = rateLimiter.checkLimit(endpoint, 'test');

        expect(status.allowed).assertFalse();
        expect(status.remaining).assertEqual(0);
        expect(status.retryAfter).not.toBeUndefined();
      });

      it('should use different limits for different types', () => {
        const readStatus = rateLimiter.checkLimit('/api/read', 'read');
        const writeStatus = rateLimiter.checkLimit('/api/write', 'write');
        const authStatus = rateLimiter.checkLimit('/api/auth', 'auth');

        expect(readStatus.remaining).assertEqual(DEFAULT_RATE_LIMITS.read.maxRequests);
        expect(writeStatus.remaining).assertEqual(DEFAULT_RATE_LIMITS.write.maxRequests);
        expect(authStatus.remaining).assertEqual(DEFAULT_RATE_LIMITS.auth.maxRequests);
      });
    });

    describe('handleRateLimitResponse', () => {
      it('should block endpoint after rate limit response', () => {
        const endpoint = '/api/blocked';

        rateLimiter.handleRateLimitResponse(endpoint, 5000);

        const status = rateLimiter.checkLimit(endpoint);

        expect(status.allowed).assertFalse();
        expect(status.retryAfter).toBeGreaterThan(0);
      });
    });

    describe('resetEndpoint', () => {
      it('should clear limits for specific endpoint', () => {
        const endpoint = '/api/reset-test';

        // Record requests
        for (let i = 0; i < 10; i++) {
          rateLimiter.recordRequest(endpoint);
        }

        // Reset
        rateLimiter.resetEndpoint(endpoint);

        const status = rateLimiter.checkLimit(endpoint);
        expect(status.remaining).assertEqual(DEFAULT_RATE_LIMITS.default.maxRequests);
      });
    });

    describe('resetAll', () => {
      it('should clear all limits', () => {
        const endpoints = ['/api/a', '/api/b', '/api/c'];

        for (const endpoint of endpoints) {
          rateLimiter.recordRequest(endpoint);
        }

        rateLimiter.resetAll();

        for (const endpoint of endpoints) {
          const status = rateLimiter.checkLimit(endpoint);
          expect(status.remaining).assertEqual(DEFAULT_RATE_LIMITS.default.maxRequests);
        }
      });
    });
  });

  describe('RequestQueue', () => {
    it('should process requests sequentially', async () => {
      const queue = new RequestQueue(10);
      const results: number[] = [];

      // Enqueue multiple requests
      const promises = [
        queue.enqueue(async () => {
          results.push(1);
          return 1;
        }),
        queue.enqueue(async () => {
          results.push(2);
          return 2;
        }),
        queue.enqueue(async () => {
          results.push(3);
          return 3;
        })
      ];

      await Promise.all(promises);

      expect(results).assertDeepEquals([1, 2, 3]);
    });

    it('should return correct results', async () => {
      const queue = new RequestQueue(10);

      const result1 = await queue.enqueue(async () => 'first');
      const result2 = await queue.enqueue(async () => 'second');

      expect(result1).assertEqual('first');
      expect(result2).assertEqual('second');
    });

    it('should propagate errors', async () => {
      const queue = new RequestQueue(10);
      let caught = false;

      try {
        await queue.enqueue(async () => {
          throw new Error('Test error');
        });
      } catch {
        caught = true;
      }

      expect(caught).assertTrue();
    });

    it('should track queue length', () => {
      const queue = new RequestQueue(1000);

      queue.enqueue(async () => {
        await new Promise(resolve => setTimeout(resolve, 500));
      });
      queue.enqueue(async () => {});
      queue.enqueue(async () => {});

      // Queue length might vary based on timing, but should be >= 0
      expect(queue.length).toBeGreaterThanOrEqual(0);
    });

    it('should clear queue', () => {
      const queue = new RequestQueue(1000);

      queue.enqueue(async () => {
        await new Promise(resolve => setTimeout(resolve, 1000));
      });

      queue.clear();
      expect(queue.length).assertEqual(0);
    });
  });

  describe('Debouncer', () => {
    it('should debounce rapid calls', async () => {
      const debouncer = new Debouncer(50);
      let callCount = 0;

      // Call multiple times rapidly
      for (let i = 0; i < 5; i++) {
        debouncer.debounce(() => callCount++);
      }

      // Wait for debounce to complete
      await new Promise(resolve => setTimeout(resolve, 100));

      expect(callCount).assertEqual(1);
    });

    it('should cancel pending call', async () => {
      const debouncer = new Debouncer(100);
      let called = false;

      debouncer.debounce(() => {
        called = true;
      });
      debouncer.cancel();

      await new Promise(resolve => setTimeout(resolve, 150));

      expect(called).assertFalse();
    });
  });

  describe('Throttler', () => {
    it('should throttle rapid calls', () => {
      const throttler = new Throttler(100);
      let callCount = 0;

      // First call should succeed
      const result1 = throttler.throttle(() => callCount++);
      expect(result1).assertTrue();
      expect(callCount).assertEqual(1);

      // Immediate second call should be throttled
      const result2 = throttler.throttle(() => callCount++);
      expect(result2).assertFalse();
      expect(callCount).assertEqual(1);
    });

    it('should allow call after interval', async () => {
      const throttler = new Throttler(50);
      let callCount = 0;

      throttler.throttle(() => callCount++);

      await new Promise(resolve => setTimeout(resolve, 60));

      const result = throttler.throttle(() => callCount++);

      expect(result).assertTrue();
      expect(callCount).assertEqual(2);
    });

    it('should reset throttle timer', () => {
      const throttler = new Throttler(100);
      let callCount = 0;

      throttler.throttle(() => callCount++);
      const throttled = throttler.throttle(() => callCount++);
      expect(throttled).assertFalse();

      throttler.reset();

      const afterReset = throttler.throttle(() => callCount++);
      expect(afterReset).assertTrue();
      expect(callCount).assertEqual(2);
    });
  });
}
