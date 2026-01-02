/**
 * Observable Cache with Subscription Support
 * Like Android's MutableStateFlow<Map<K, V>> for caching.
 *
 * Features:
 * - LRU eviction with TTL support
 * - Subscribe to all cache changes
 * - Subscribe to specific key changes (like getUserFlow(id))
 * - Immediate emission on subscribe
 */

import { Logger } from '../../core/logging/Logger';

const TAG = 'ObservableCache';

/**
 * Cache change event types
 */
export enum CacheChangeType {
  PUT = 'put',
  UPDATE = 'update',
  REMOVE = 'remove',
  CLEAR = 'clear'
}

/**
 * Cache change event
 */
export interface CacheChangeEvent<K, V> {
  type: CacheChangeType;
  key?: K;
  value?: V;
  previousValue?: V;
}

/**
 * Cache entry with metadata
 */
interface CacheEntry<V> {
  value: V;
  timestamp: number;
  accessCount: number;
}

/**
 * Cache change callback type
 */
export type CacheChangeCallback<K, V> = (event: CacheChangeEvent<K, V>) => void;

/**
 * Single-value change callback type
 */
export type ValueChangeCallback<V> = (value: V | undefined) => void;

/**
 * Unsubscribe class for cache subscriptions
 */
export class CacheUnsubscribe<K, V> {
  private callback: CacheChangeCallback<K, V>;
  private callbacks: Set<CacheChangeCallback<K, V>>;

  constructor(callback: CacheChangeCallback<K, V>, callbacks: Set<CacheChangeCallback<K, V>>) {
    this.callback = callback;
    this.callbacks = callbacks;
  }

  unsubscribe(): void {
    this.callbacks.delete(this.callback);
  }
}

/**
 * Unsubscribe class for single-value subscriptions
 */
export class ValueUnsubscribe<V> {
  private callback: ValueChangeCallback<V>;
  private callbacks: Set<ValueChangeCallback<V>>;

  constructor(callback: ValueChangeCallback<V>, callbacks: Set<ValueChangeCallback<V>>) {
    this.callback = callback;
    this.callbacks = callbacks;
  }

  unsubscribe(): void {
    this.callbacks.delete(this.callback);
  }
}

/**
 * Observable cache with TTL and LRU eviction.
 * Provides reactive subscriptions for cache changes.
 */
export class ObservableCache<K, V> {
  private cache: Map<K, CacheEntry<V>>;
  private readonly maxSize: number;
  private readonly ttlMs: number;
  private readonly name: string;

  // Global cache change subscribers
  private cacheCallbacks: Set<CacheChangeCallback<K, V>> = new Set();

  // Per-key subscribers (like Android's getUserFlow(id))
  private keyCallbacks: Map<K, Set<ValueChangeCallback<V>>> = new Map();

  constructor(maxSize: number, ttlMs: number = 5 * 60 * 1000, name: string = 'cache') {
    this.cache = new Map();
    this.maxSize = maxSize;
    this.ttlMs = ttlMs;
    this.name = name;
  }

  /**
   * Gets a value from the cache
   */
  get(key: K): V | undefined {
    const entry = this.cache.get(key);
    if (!entry || this.isExpired(entry)) {
      if (entry) {
        this.cache.delete(key);
      }
      return undefined;
    }

    // LRU: Move to end by re-inserting
    entry.accessCount++;
    this.cache.delete(key);
    this.cache.set(key, entry);

    return entry.value;
  }

  /**
   * Checks if key exists and is not expired
   */
  has(key: K): boolean {
    const entry = this.cache.get(key);
    if (!entry || this.isExpired(entry)) {
      if (entry) {
        this.cache.delete(key);
      }
      return false;
    }
    return true;
  }

  /**
   * Puts a value in the cache and notifies subscribers
   */
  put(key: K, value: V): void {
    const previousEntry = this.cache.get(key);
    const previousValue = previousEntry?.value;

    // Remove existing entry if present
    if (previousEntry) {
      this.cache.delete(key);
    }

    // Evict LRU entries if at capacity
    while (this.cache.size >= this.maxSize) {
      const keysIterator = this.cache.keys();
      const firstResult = keysIterator.next();
      if (!firstResult.done) {
        const evictedKey = firstResult.value as K;
        this.cache.delete(evictedKey);
        this.notifyKeySubscribers(evictedKey, undefined);
        Logger.d(TAG, `[${this.name}] Evicted key due to capacity`);
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

    // Notify subscribers
    const eventType = previousEntry ? CacheChangeType.UPDATE : CacheChangeType.PUT;
    this.notifyCacheChange({ type: eventType, key, value, previousValue });
    this.notifyKeySubscribers(key, value);
  }

  /**
   * Removes a value from the cache
   */
  remove(key: K): boolean {
    const entry = this.cache.get(key);
    if (entry) {
      this.cache.delete(key);
      this.notifyCacheChange({ type: CacheChangeType.REMOVE, key, previousValue: entry.value });
      this.notifyKeySubscribers(key, undefined);
      return true;
    }
    return false;
  }

  /**
   * Clears all entries
   */
  clear(): void {
    const hadEntries = this.cache.size > 0;
    this.cache.clear();

    if (hadEntries) {
      this.notifyCacheChange({ type: CacheChangeType.CLEAR });

      // Notify all key subscribers
      this.keyCallbacks.forEach((callbacks, _key) => {
        callbacks.forEach(callback => {
          try {
            callback(undefined);
          } catch (error) {
            Logger.e(TAG, `[${this.name}] Error in key callback: ${error}`);
          }
        });
      });
    }
  }

  /**
   * Subscribes to all cache changes
   * Equivalent to observing the entire StateFlow<Map<K,V>>
   */
  subscribe(callback: CacheChangeCallback<K, V>): CacheUnsubscribe<K, V> {
    this.cacheCallbacks.add(callback);
    return new CacheUnsubscribe(callback, this.cacheCallbacks);
  }

  /**
   * Subscribes to changes for a specific key
   * Equivalent to Android's getUserFlow(id)
   */
  subscribeToKey(key: K, callback: ValueChangeCallback<V>): ValueUnsubscribe<V> {
    let keySet = this.keyCallbacks.get(key);
    if (!keySet) {
      keySet = new Set();
      this.keyCallbacks.set(key, keySet);
    }
    keySet.add(callback);

    // Immediately emit current value
    const currentValue = this.get(key);
    try {
      callback(currentValue);
    } catch (error) {
      Logger.e(TAG, `[${this.name}] Error in initial callback: ${error}`);
    }

    return new ValueUnsubscribe(callback, keySet);
  }

  /**
   * Gets all current values as a map
   */
  getAll(): Map<K, V> {
    const result = new Map<K, V>();
    this.cache.forEach((entry, key) => {
      if (!this.isExpired(entry)) {
        result.set(key, entry.value);
      }
    });
    return result;
  }

  /**
   * Gets current size (including potentially expired entries)
   */
  size(): number {
    return this.cache.size;
  }

  /**
   * Deletes a key (alias for remove)
   */
  delete(key: K): boolean {
    return this.remove(key);
  }

  private isExpired(entry: CacheEntry<V>): boolean {
    return Date.now() - entry.timestamp > this.ttlMs;
  }

  private notifyCacheChange(event: CacheChangeEvent<K, V>): void {
    this.cacheCallbacks.forEach(callback => {
      try {
        callback(event);
      } catch (error) {
        Logger.e(TAG, `[${this.name}] Error in cache callback: ${error}`);
      }
    });
  }

  private notifyKeySubscribers(key: K, value: V | undefined): void {
    const keySet = this.keyCallbacks.get(key);
    if (keySet) {
      keySet.forEach(callback => {
        try {
          callback(value);
        } catch (error) {
          Logger.e(TAG, `[${this.name}] Error in key callback: ${error}`);
        }
      });
    }
  }

  /**
   * Cleanup - removes all subscribers
   */
  destroy(): void {
    this.cache.clear();
    this.cacheCallbacks.clear();
    this.keyCallbacks.clear();
  }
}
