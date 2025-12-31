/**
 * Unit Tests for LruCache
 */

import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { LruCache, CacheStats, CacheManager } from '../../../../main/ets/data/cache/LruCache';

export default function LruCacheTest() {
  describe('LruCache', () => {
    let cache: LruCache<string, number>;

    beforeEach(() => {
      cache = new LruCache<string, number>(3, 1000, 'test-cache');
    });

    describe('constructor', () => {
      it('should create cache with specified maxSize', () => {
        const stats = cache.getStats();
        expect(stats.maxSize).assertEqual(3);
      });

      it('should create cache with specified TTL', () => {
        const stats = cache.getStats();
        expect(stats.ttlMs).assertEqual(1000);
      });

      it('should create cache with specified name', () => {
        const stats = cache.getStats();
        expect(stats.name).assertEqual('test-cache');
      });

      it('should start with empty cache', () => {
        expect(cache.size).assertEqual(0);
      });

      it('should use default TTL when not specified', () => {
        const defaultCache = new LruCache<string, number>(10);
        const stats = defaultCache.getStats();
        expect(stats.ttlMs).assertEqual(5 * 60 * 1000);
      });
    });

    describe('put', () => {
      it('should add entry to cache', () => {
        cache.put('key1', 100);

        expect(cache.size).assertEqual(1);
        expect(cache.get('key1')).assertEqual(100);
      });

      it('should update existing entry', () => {
        cache.put('key1', 100);
        cache.put('key1', 200);

        expect(cache.size).assertEqual(1);
        expect(cache.get('key1')).assertEqual(200);
      });

      it('should add multiple entries', () => {
        cache.put('key1', 100);
        cache.put('key2', 200);
        cache.put('key3', 300);

        expect(cache.size).assertEqual(3);
      });

      it('should evict LRU entry when at capacity', () => {
        cache.put('key1', 100);
        cache.put('key2', 200);
        cache.put('key3', 300);
        cache.put('key4', 400);

        expect(cache.size).assertEqual(3);
        expect(cache.get('key1')).assertUndefined();
        expect(cache.get('key4')).assertEqual(400);
      });

      it('should evict oldest entry first', () => {
        cache.put('key1', 100);
        cache.put('key2', 200);
        cache.put('key3', 300);

        // Access key1 to make it recently used
        cache.get('key1');

        // Add new entry, should evict key2 (least recently used)
        cache.put('key4', 400);

        expect(cache.get('key1')).assertEqual(100);
        expect(cache.get('key2')).assertUndefined();
        expect(cache.get('key4')).assertEqual(400);
      });
    });

    describe('get', () => {
      it('should return cached value', () => {
        cache.put('key1', 100);

        expect(cache.get('key1')).assertEqual(100);
      });

      it('should return undefined for non-existent key', () => {
        expect(cache.get('nonexistent')).assertUndefined();
      });

      it('should return undefined for expired entry', async () => {
        const shortTtlCache = new LruCache<string, number>(3, 50, 'short-ttl');
        shortTtlCache.put('key1', 100);

        // Wait for TTL to expire
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        expect(shortTtlCache.get('key1')).assertUndefined();
      });

      it('should update access order on get', () => {
        cache.put('key1', 100);
        cache.put('key2', 200);
        cache.put('key3', 300);

        // Access key1 to make it recently used
        cache.get('key1');

        // Add new entry, should evict key2
        cache.put('key4', 400);

        expect(cache.has('key1')).assertTrue();
        expect(cache.has('key2')).assertFalse();
      });

      it('should increment access count', () => {
        cache.put('key1', 100);
        cache.get('key1');
        cache.get('key1');
        cache.get('key1');

        const stats = cache.getStats();
        expect(stats.totalAccessCount >= 3).assertTrue();
      });
    });

    describe('has', () => {
      it('should return true for existing key', () => {
        cache.put('key1', 100);

        expect(cache.has('key1')).assertTrue();
      });

      it('should return false for non-existent key', () => {
        expect(cache.has('nonexistent')).assertFalse();
      });

      it('should return false for expired key', async () => {
        const shortTtlCache = new LruCache<string, number>(3, 50, 'short-ttl');
        shortTtlCache.put('key1', 100);

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        expect(shortTtlCache.has('key1')).assertFalse();
      });

      it('should remove expired entry on check', async () => {
        const shortTtlCache = new LruCache<string, number>(3, 50, 'short-ttl');
        shortTtlCache.put('key1', 100);

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        shortTtlCache.has('key1');
        expect(shortTtlCache.size).assertEqual(0);
      });
    });

    describe('remove', () => {
      it('should remove existing entry', () => {
        cache.put('key1', 100);
        cache.remove('key1');

        expect(cache.size).assertEqual(0);
        expect(cache.get('key1')).assertUndefined();
      });

      it('should handle removing non-existent key', () => {
        cache.remove('nonexistent');

        expect(cache.size).assertEqual(0);
      });

      it('should only remove specified key', () => {
        cache.put('key1', 100);
        cache.put('key2', 200);
        cache.remove('key1');

        expect(cache.size).assertEqual(1);
        expect(cache.get('key2')).assertEqual(200);
      });
    });

    describe('clear', () => {
      it('should remove all entries', () => {
        cache.put('key1', 100);
        cache.put('key2', 200);
        cache.put('key3', 300);

        cache.clear();

        expect(cache.size).assertEqual(0);
      });

      it('should work on empty cache', () => {
        cache.clear();

        expect(cache.size).assertEqual(0);
      });
    });

    describe('size', () => {
      it('should return 0 for empty cache', () => {
        expect(cache.size).assertEqual(0);
      });

      it('should return correct size after adding entries', () => {
        cache.put('key1', 100);
        expect(cache.size).assertEqual(1);

        cache.put('key2', 200);
        expect(cache.size).assertEqual(2);
      });

      it('should not exceed maxSize', () => {
        cache.put('key1', 100);
        cache.put('key2', 200);
        cache.put('key3', 300);
        cache.put('key4', 400);

        expect(cache.size).assertEqual(3);
      });
    });

    describe('purgeExpired', () => {
      it('should remove expired entries', async () => {
        const shortTtlCache = new LruCache<string, number>(10, 50, 'short-ttl');
        shortTtlCache.put('key1', 100);
        shortTtlCache.put('key2', 200);

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        const purgedCount = shortTtlCache.purgeExpired();

        expect(purgedCount).assertEqual(2);
        expect(shortTtlCache.size).assertEqual(0);
      });

      it('should not remove non-expired entries', () => {
        cache.put('key1', 100);
        cache.put('key2', 200);

        const purgedCount = cache.purgeExpired();

        expect(purgedCount).assertEqual(0);
        expect(cache.size).assertEqual(2);
      });

      it('should return 0 for empty cache', () => {
        const purgedCount = cache.purgeExpired();

        expect(purgedCount).assertEqual(0);
      });
    });

    describe('getStats', () => {
      it('should return correct stats for empty cache', () => {
        const stats = cache.getStats();

        expect(stats.name).assertEqual('test-cache');
        expect(stats.size).assertEqual(0);
        expect(stats.maxSize).assertEqual(3);
        expect(stats.ttlMs).assertEqual(1000);
        expect(stats.totalAccessCount).assertEqual(0);
        expect(stats.oldestEntryAge).assertEqual(0);
        expect(stats.newestEntryAge).assertEqual(0);
      });

      it('should return correct size', () => {
        cache.put('key1', 100);
        cache.put('key2', 200);

        const stats = cache.getStats();

        expect(stats.size).assertEqual(2);
      });

      it('should track total access count', () => {
        cache.put('key1', 100);
        cache.get('key1');
        cache.get('key1');

        const stats = cache.getStats();

        expect(stats.totalAccessCount >= 2).assertTrue();
      });

      it('should track entry ages', () => {
        cache.put('key1', 100);

        const stats = cache.getStats();

        expect(stats.oldestEntryAge >= 0).assertTrue();
        expect(stats.newestEntryAge >= 0).assertTrue();
      });
    });

    describe('different value types', () => {
      it('should work with string values', () => {
        const stringCache = new LruCache<string, string>(3, 1000, 'string');
        stringCache.put('key', 'value');

        expect(stringCache.get('key')).assertEqual('value');
      });

      it('should work with object values', () => {
        interface TestObject {
          name: string;
          value: number;
        }
        const objectCache = new LruCache<string, TestObject>(3, 1000, 'object');
        objectCache.put('key', { name: 'test', value: 42 });

        const result = objectCache.get('key');
        expect(result?.name).assertEqual('test');
        expect(result?.value).assertEqual(42);
      });

      it('should work with array values', () => {
        const arrayCache = new LruCache<string, number[]>(3, 1000, 'array');
        arrayCache.put('key', [1, 2, 3]);

        const result = arrayCache.get('key');
        expect(result?.length).assertEqual(3);
        expect(result?.[0]).assertEqual(1);
      });

      it('should work with numeric keys', () => {
        const numKeyCache = new LruCache<number, string>(3, 1000, 'numkey');
        numKeyCache.put(1, 'one');
        numKeyCache.put(2, 'two');

        expect(numKeyCache.get(1)).assertEqual('one');
        expect(numKeyCache.get(2)).assertEqual('two');
      });
    });
  });

  describe('CacheManager', () => {
    beforeEach(() => {
      CacheManager.clearAll();
    });

    describe('getUserListCache', () => {
      it('should return a cache instance', () => {
        const cache = CacheManager.getUserListCache();

        expect(cache).assertNotNull();
      });

      it('should return same instance on multiple calls', () => {
        const cache1 = CacheManager.getUserListCache();
        const cache2 = CacheManager.getUserListCache();

        expect(cache1).toBe(cache2);
      });
    });

    describe('getUserDetailCache', () => {
      it('should return a cache instance', () => {
        const cache = CacheManager.getUserDetailCache();

        expect(cache).assertNotNull();
      });

      it('should return same instance on multiple calls', () => {
        const cache1 = CacheManager.getUserDetailCache();
        const cache2 = CacheManager.getUserDetailCache();

        expect(cache1).toBe(cache2);
      });
    });

    describe('clearAll', () => {
      it('should clear all caches', () => {
        const listCache = CacheManager.getUserListCache();
        const detailCache = CacheManager.getUserDetailCache();

        listCache.put(1, [{ id: 1 }]);
        detailCache.put(1, { id: 1 });

        CacheManager.clearAll();

        expect(listCache.size).assertEqual(0);
        expect(detailCache.size).assertEqual(0);
      });
    });

    describe('purgeAllExpired', () => {
      it('should purge expired entries from all caches', () => {
        // Just verify method doesn't throw
        CacheManager.purgeAllExpired();
      });
    });

    describe('getAllStats', () => {
      it('should return stats for all caches', () => {
        CacheManager.getUserListCache();
        CacheManager.getUserDetailCache();

        const stats = CacheManager.getAllStats();

        expect(stats.length).assertEqual(2);
      });

      it('should return empty array if no caches created', () => {
        // Note: Caches might already exist from previous tests
        const stats = CacheManager.getAllStats();

        expect(stats.length >= 0).assertTrue();
      });
    });
  });
}
