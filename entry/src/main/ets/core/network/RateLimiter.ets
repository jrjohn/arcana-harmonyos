/**
 * Rate Limiter and Request Throttling
 * Prevents API abuse and handles rate limit responses
 */

import { injectable, preDestroy } from '../di/decorators';
import { ILogger } from '../di/interfaces';

const TAG = 'RateLimiter';

/**
 * Rate limit configuration
 */
export interface RateLimitConfig {
  /** Maximum requests allowed in the window */
  maxRequests: number;
  /** Time window in milliseconds */
  windowMs: number;
  /** Delay between requests in milliseconds (throttling) */
  minDelayMs: number;
  /** Maximum retry delay after rate limit hit */
  maxRetryDelayMs: number;
}

/**
 * Default rate limit configurations by endpoint type
 */
export const DEFAULT_RATE_LIMITS: Record<string, RateLimitConfig> = {
  default: {
    maxRequests: 60,
    windowMs: 60000, // 1 minute
    minDelayMs: 100,
    maxRetryDelayMs: 60000
  },
  read: {
    maxRequests: 100,
    windowMs: 60000,
    minDelayMs: 50,
    maxRetryDelayMs: 30000
  },
  write: {
    maxRequests: 30,
    windowMs: 60000,
    minDelayMs: 200,
    maxRetryDelayMs: 120000
  },
  auth: {
    maxRequests: 10,
    windowMs: 60000,
    minDelayMs: 500,
    maxRetryDelayMs: 300000
  }
};

/**
 * Request record for tracking
 */
interface RequestRecord {
  timestamp: number;
  endpoint: string;
}

/**
 * Rate limit status
 */
export interface RateLimitStatus {
  /** Whether requests are currently allowed */
  allowed: boolean;
  /** Remaining requests in current window */
  remaining: number;
  /** Time until window resets (ms) */
  resetIn: number;
  /** Recommended wait time if rate limited (ms) */
  retryAfter?: number;
}

/**
 * Rate Limiter interface
 */
export interface IRateLimiter {
  /** Check if request is allowed */
  checkLimit(endpoint: string, type?: string): RateLimitStatus;

  /** Record a request */
  recordRequest(endpoint: string): void;

  /** Handle rate limit response from server */
  handleRateLimitResponse(endpoint: string, retryAfterMs?: number): void;

  /** Get current status for endpoint */
  getStatus(endpoint: string, type?: string): RateLimitStatus;

  /** Wait until request is allowed */
  waitForSlot(endpoint: string, type?: string): Promise<void>;

  /** Reset limits for endpoint */
  resetEndpoint(endpoint: string): void;

  /** Reset all limits */
  resetAll(): void;
}

/**
 * Token Bucket Rate Limiter implementation
 */
@injectable()
export class RateLimiter implements IRateLimiter {
  private logger?: ILogger;
  private requests: RequestRecord[] = [];
  private blockedUntil = new Map<string, number>();
  private configs = new Map<string, RateLimitConfig>();

  constructor() {
    // Register default configs
    for (const [type, config] of Object.entries(DEFAULT_RATE_LIMITS)) {
      this.configs.set(type, config);
    }
  }

  setLogger(logger: ILogger): void {
    this.logger = logger;
  }

  /**
   * Set custom rate limit config for a type
   */
  setConfig(type: string, config: RateLimitConfig): void {
    this.configs.set(type, config);
  }

  checkLimit(endpoint: string, type: string = 'default'): RateLimitStatus {
    const config = this.getConfig(type);
    const now = Date.now();

    // Check if endpoint is blocked
    const blockedUntil = this.blockedUntil.get(endpoint);
    if (blockedUntil && now < blockedUntil) {
      return {
        allowed: false,
        remaining: 0,
        resetIn: blockedUntil - now,
        retryAfter: blockedUntil - now
      };
    }

    // Clean old requests
    this.cleanOldRequests(config.windowMs);

    // Count requests to this endpoint in current window
    const windowStart = now - config.windowMs;
    const recentRequests = this.requests.filter(
      r => r.endpoint === endpoint && r.timestamp > windowStart
    );

    const remaining = Math.max(0, config.maxRequests - recentRequests.length);
    const allowed = remaining > 0;

    // Calculate reset time
    const oldestRequest = recentRequests[0];
    const resetIn = oldestRequest
      ? Math.max(0, oldestRequest.timestamp + config.windowMs - now)
      : 0;

    return {
      allowed,
      remaining,
      resetIn,
      retryAfter: allowed ? undefined : resetIn
    };
  }

  recordRequest(endpoint: string): void {
    this.requests.push({
      timestamp: Date.now(),
      endpoint
    });
    this.log(`Recorded request: ${endpoint}`);
  }

  handleRateLimitResponse(endpoint: string, retryAfterMs?: number): void {
    const config = this.getConfig('default');
    const blockDuration = retryAfterMs || config.maxRetryDelayMs;
    const blockedUntil = Date.now() + blockDuration;

    this.blockedUntil.set(endpoint, blockedUntil);
    this.logError(`Rate limited on ${endpoint}, blocked for ${blockDuration}ms`);
  }

  getStatus(endpoint: string, type: string = 'default'): RateLimitStatus {
    return this.checkLimit(endpoint, type);
  }

  async waitForSlot(endpoint: string, type: string = 'default'): Promise<void> {
    const config = this.getConfig(type);

    while (true) {
      const status = this.checkLimit(endpoint, type);

      if (status.allowed) {
        // Apply minimum delay between requests (throttling)
        await this.delay(config.minDelayMs);
        return;
      }

      // Wait for rate limit reset
      const waitTime = status.retryAfter || 1000;
      this.log(`Waiting ${waitTime}ms for rate limit reset on ${endpoint}`);
      await this.delay(waitTime);
    }
  }

  resetEndpoint(endpoint: string): void {
    this.requests = this.requests.filter(r => r.endpoint !== endpoint);
    this.blockedUntil.delete(endpoint);
    this.log(`Reset limits for: ${endpoint}`);
  }

  resetAll(): void {
    this.requests = [];
    this.blockedUntil.clear();
    this.log('Reset all rate limits');
  }

  @preDestroy()
  destroy(): void {
    this.resetAll();
  }

  // ===== Private Methods =====

  private getConfig(type: string): RateLimitConfig {
    return this.configs.get(type) || this.configs.get('default')!;
  }

  private cleanOldRequests(windowMs: number): void {
    const cutoff = Date.now() - windowMs;
    this.requests = this.requests.filter(r => r.timestamp > cutoff);
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
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
 * Request Queue for sequential request processing
 */
export class RequestQueue {
  private queue: Array<() => Promise<void>> = [];
  private processing = false;
  private delayMs: number;

  constructor(delayMs: number = 100) {
    this.delayMs = delayMs;
  }

  /**
   * Add request to queue
   */
  async enqueue<T>(request: () => Promise<T>): Promise<T> {
    return new Promise((resolve, reject) => {
      this.queue.push(async () => {
        try {
          const result = await request();
          resolve(result);
        } catch (error) {
          reject(error);
        }
      });

      this.processQueue();
    });
  }

  /**
   * Process queued requests
   */
  private async processQueue(): Promise<void> {
    if (this.processing) return;
    this.processing = true;

    while (this.queue.length > 0) {
      const request = this.queue.shift();
      if (request) {
        await request();
        await this.delay(this.delayMs);
      }
    }

    this.processing = false;
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Get queue length
   */
  get length(): number {
    return this.queue.length;
  }

  /**
   * Clear queue
   */
  clear(): void {
    this.queue = [];
  }
}

/**
 * Debouncer for input-triggered requests
 */
export class Debouncer {
  private timeoutId: number | null = null;
  private readonly delayMs: number;

  constructor(delayMs: number = 300) {
    this.delayMs = delayMs;
  }

  /**
   * Debounce a function call
   */
  debounce(fn: () => void): void {
    if (this.timeoutId !== null) {
      clearTimeout(this.timeoutId);
    }

    this.timeoutId = setTimeout(() => {
      fn();
      this.timeoutId = null;
    }, this.delayMs) as unknown as number;
  }

  /**
   * Cancel pending call
   */
  cancel(): void {
    if (this.timeoutId !== null) {
      clearTimeout(this.timeoutId);
      this.timeoutId = null;
    }
  }
}

/**
 * Throttler for limiting function call frequency
 */
export class Throttler {
  private lastCall: number = 0;
  private readonly intervalMs: number;

  constructor(intervalMs: number = 1000) {
    this.intervalMs = intervalMs;
  }

  /**
   * Throttle a function call
   * @returns true if call was allowed, false if throttled
   */
  throttle(fn: () => void): boolean {
    const now = Date.now();

    if (now - this.lastCall >= this.intervalMs) {
      this.lastCall = now;
      fn();
      return true;
    }

    return false;
  }

  /**
   * Reset throttle timer
   */
  reset(): void {
    this.lastCall = 0;
  }
}
