import { Logger } from '../../core/logging/Logger';

const TAG = 'LruCache';

/**
 * Cache entry with value and metadata
 */
interface CacheEntry<T> {
  value: T;
  timestamp: number;
  accessCount: number;
}

/**
 * LRU (Least Recently Used) Cache implementation with TTL support.
 * Provides efficient in-memory caching with automatic expiration.
 */
export class LruCache<K, V> {
  private cache: Map<K, CacheEntry<V>>;
  private readonly maxSize: number;
  private readonly ttlMs: number;
  private readonly name: string;

  /**
   * Creates a new LRU cache
   * @param maxSize - Maximum number of entries
   * @param ttlMs - Time-to-live in milliseconds (default: 5 minutes)
   * @param name - Cache name for logging
   */
  constructor(maxSize: number, ttlMs: number = 5 * 60 * 1000, name: string = 'cache') {
    this.cache = new Map();
    this.maxSize = maxSize;
    this.ttlMs = ttlMs;
    this.name = name;
    Logger.d(TAG, `Created ${name} cache with maxSize=${maxSize}, ttl=${ttlMs}ms`);
  }

  /**
   * Gets a value from the cache
   * @param key - Cache key
   * @returns The cached value or undefined if not found/expired
   */
  get(key: K): V | undefined {
    const entry = this.cache.get(key);

    if (!entry) {
      Logger.d(TAG, `[${this.name}] Cache miss for key`);
      return undefined;
    }

    // Check if expired
    if (this.isExpired(entry)) {
      Logger.d(TAG, `[${this.name}] Cache entry expired`);
      this.cache.delete(key);
      return undefined;
    }

    // Update access metadata (LRU behavior)
    entry.accessCount++;

    // Move to end (most recently used)
    this.cache.delete(key);
    this.cache.set(key, entry);

    Logger.d(TAG, `[${this.name}] Cache hit`);
    return entry.value;
  }

  /**
   * Puts a value in the cache
   * @param key - Cache key
   * @param value - Value to cache
   */
  put(key: K, value: V): void {
    // Remove existing entry if present
    if (this.cache.has(key)) {
      this.cache.delete(key);
    }

    // Evict LRU entries if at capacity
    while (this.cache.size >= this.maxSize) {
      const keysIterator = this.cache.keys();
      const firstResult = keysIterator.next();
      if (!firstResult.done) {
        const firstKey: K = firstResult.value as K;
        this.cache.delete(firstKey);
        Logger.d(TAG, `[${this.name}] Evicted LRU entry`);
      } else {
        break;
      }
    }

    // Add new entry
    this.cache.set(key, {
      value,
      timestamp: Date.now(),
      accessCount: 1
    });

    Logger.d(TAG, `[${this.name}] Cached entry, size=${this.cache.size}`);
  }

  /**
   * Checks if a key exists and is not expired
   * @param key - Cache key
   * @returns true if key exists and is valid
   */
  has(key: K): boolean {
    const entry = this.cache.get(key);
    if (!entry) return false;
    if (this.isExpired(entry)) {
      this.cache.delete(key);
      return false;
    }
    return true;
  }

  /**
   * Removes a key from the cache
   * @param key - Cache key
   */
  remove(key: K): void {
    this.cache.delete(key);
    Logger.d(TAG, `[${this.name}] Removed entry`);
  }

  /**
   * Clears all entries from the cache
   */
  clear(): void {
    const size = this.cache.size;
    this.cache.clear();
    Logger.d(TAG, `[${this.name}] Cleared ${size} entries`);
  }

  /**
   * Gets the current size of the cache
   */
  get size(): number {
    return this.cache.size;
  }

  /**
   * Removes all expired entries
   */
  purgeExpired(): number {
    let purgedCount = 0;
    const now = Date.now();
    const keysToDelete: K[] = [];

    this.cache.forEach((entry, key) => {
      if (now - entry.timestamp > this.ttlMs) {
        keysToDelete.push(key);
      }
    });

    for (const key of keysToDelete) {
      this.cache.delete(key);
      purgedCount++;
    }

    if (purgedCount > 0) {
      Logger.d(TAG, `[${this.name}] Purged ${purgedCount} expired entries`);
    }
    return purgedCount;
  }

  /**
   * Gets cache statistics
   */
  getStats(): CacheStats {
    let totalAccessCount = 0;
    let oldestTimestamp = Date.now();
    let newestTimestamp = 0;

    for (const entry of this.cache.values()) {
      totalAccessCount += entry.accessCount;
      if (entry.timestamp < oldestTimestamp) oldestTimestamp = entry.timestamp;
      if (entry.timestamp > newestTimestamp) newestTimestamp = entry.timestamp;
    }

    return {
      name: this.name,
      size: this.cache.size,
      maxSize: this.maxSize,
      ttlMs: this.ttlMs,
      totalAccessCount,
      oldestEntryAge: this.cache.size > 0 ? Date.now() - oldestTimestamp : 0,
      newestEntryAge: this.cache.size > 0 ? Date.now() - newestTimestamp : 0
    };
  }

  /**
   * Checks if an entry is expired
   */
  private isExpired(entry: CacheEntry<V>): boolean {
    return Date.now() - entry.timestamp > this.ttlMs;
  }
}

/**
 * Cache statistics
 */
export interface CacheStats {
  name: string;
  size: number;
  maxSize: number;
  ttlMs: number;
  totalAccessCount: number;
  oldestEntryAge: number;
  newestEntryAge: number;
}

// Module-level cache instances to avoid this in static methods
let cacheManagerUserListCache: LruCache<number, object[]> | null = null;
let cacheManagerUserDetailCache: LruCache<number, object> | null = null;

/**
 * Pre-configured cache instances for the application
 */
export class CacheManager {
  /**
   * Gets the user list cache (page -> users)
   */
  static getUserListCache(): LruCache<number, object[]> {
    if (!cacheManagerUserListCache) {
      cacheManagerUserListCache = new LruCache(10, 5 * 60 * 1000, 'userList');
    }
    return cacheManagerUserListCache;
  }

  /**
   * Gets the user detail cache (userId -> user)
   */
  static getUserDetailCache(): LruCache<number, object> {
    if (!cacheManagerUserDetailCache) {
      cacheManagerUserDetailCache = new LruCache(50, 5 * 60 * 1000, 'userDetail');
    }
    return cacheManagerUserDetailCache;
  }

  /**
   * Clears all caches
   */
  static clearAll(): void {
    if (cacheManagerUserListCache) {
      cacheManagerUserListCache.clear();
    }
    if (cacheManagerUserDetailCache) {
      cacheManagerUserDetailCache.clear();
    }
    Logger.d(TAG, 'Cleared all caches');
  }

  /**
   * Purges expired entries from all caches
   */
  static purgeAllExpired(): void {
    if (cacheManagerUserListCache) {
      cacheManagerUserListCache.purgeExpired();
    }
    if (cacheManagerUserDetailCache) {
      cacheManagerUserDetailCache.purgeExpired();
    }
  }

  /**
   * Gets statistics for all caches
   */
  static getAllStats(): CacheStats[] {
    const stats: CacheStats[] = [];
    if (cacheManagerUserListCache) stats.push(cacheManagerUserListCache.getStats());
    if (cacheManagerUserDetailCache) stats.push(cacheManagerUserDetailCache.getStats());
    return stats;
  }
}
