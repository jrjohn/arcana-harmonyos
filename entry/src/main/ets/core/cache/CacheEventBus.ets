/**
 * Cache Event Bus
 * Global event bus for cache invalidation and cross-component coordination.
 *
 * Similar to Android's CacheEventBus pattern.
 *
 * Usage:
 * - SyncManager emits SyncCompleted after sync
 * - Repository emits UserUpdated/UserDeleted on mutations
 * - ViewModels subscribe to relevant events for UI updates
 */

import { Logger } from '../logging/Logger';

const TAG = 'CacheEventBus';

/**
 * Cache event types for cross-component coordination
 */
export enum CacheEventType {
  SYNC_COMPLETED = 'sync_completed',
  USER_UPDATED = 'user_updated',
  USER_CREATED = 'user_created',
  USER_DELETED = 'user_deleted',
  INVALIDATE_ALL = 'invalidate_all',
  INVALIDATE_PAGE = 'invalidate_page'
}

/**
 * Cache event payload
 */
export interface CacheEventPayload {
  userId?: number;
  page?: number;
  syncedCount?: number;
  failedCount?: number;
}

/**
 * Cache event
 */
export interface CacheEvent {
  type: CacheEventType;
  payload?: CacheEventPayload;
  timestamp: number;
}

/**
 * Event callback type
 */
export type CacheEventCallback = (event: CacheEvent) => void;

/**
 * Unsubscribe class for event bus
 */
export class EventUnsubscribe {
  private callback: CacheEventCallback;
  private callbacks: Set<CacheEventCallback>;

  constructor(callback: CacheEventCallback, callbacks: Set<CacheEventCallback>) {
    this.callback = callback;
    this.callbacks = callbacks;
  }

  unsubscribe(): void {
    this.callbacks.delete(this.callback);
  }
}

// Module-level state to avoid this in static methods
let eventCallbacks: Set<CacheEventCallback> = new Set();
let filteredCallbacks: Map<CacheEventType, Set<CacheEventCallback>> = new Map();
let recentEvents: CacheEvent[] = [];
const MAX_RECENT_EVENTS = 50;

/**
 * Global event bus for cache invalidation and cross-component coordination.
 */
export class CacheEventBus {

  /**
   * Subscribes to all cache events
   */
  static subscribe(callback: CacheEventCallback): EventUnsubscribe {
    eventCallbacks.add(callback);
    return new EventUnsubscribe(callback, eventCallbacks);
  }

  /**
   * Subscribes to specific event types
   */
  static subscribeToType(type: CacheEventType, callback: CacheEventCallback): EventUnsubscribe {
    let typeSet = filteredCallbacks.get(type);
    if (!typeSet) {
      typeSet = new Set();
      filteredCallbacks.set(type, typeSet);
    }
    typeSet.add(callback);

    return new EventUnsubscribe(callback, typeSet);
  }

  /**
   * Emits an event to all subscribers
   */
  static emit(type: CacheEventType, payload?: CacheEventPayload): void {
    const event: CacheEvent = {
      type,
      payload,
      timestamp: Date.now()
    };

    Logger.d(TAG, `Emitting event: ${type}`);

    // Store in recent events
    recentEvents.push(event);
    if (recentEvents.length > MAX_RECENT_EVENTS) {
      recentEvents.shift();
    }

    // Notify global subscribers
    eventCallbacks.forEach(callback => {
      try {
        callback(event);
      } catch (error) {
        Logger.e(TAG, `Error in event callback: ${error}`);
      }
    });

    // Notify filtered subscribers
    const typeCallbacks = filteredCallbacks.get(type);
    if (typeCallbacks) {
      typeCallbacks.forEach(callback => {
        try {
          callback(event);
        } catch (error) {
          Logger.e(TAG, `Error in filtered callback: ${error}`);
        }
      });
    }
  }

  // ===== Convenience Emitters =====

  /**
   * Emits sync completed event
   */
  static emitSyncCompleted(syncedCount: number, failedCount: number): void {
    CacheEventBus.emit(CacheEventType.SYNC_COMPLETED, { syncedCount, failedCount });
  }

  /**
   * Emits user updated event
   */
  static emitUserUpdated(userId: number): void {
    CacheEventBus.emit(CacheEventType.USER_UPDATED, { userId });
  }

  /**
   * Emits user created event
   */
  static emitUserCreated(userId: number): void {
    CacheEventBus.emit(CacheEventType.USER_CREATED, { userId });
  }

  /**
   * Emits user deleted event
   */
  static emitUserDeleted(userId: number): void {
    CacheEventBus.emit(CacheEventType.USER_DELETED, { userId });
  }

  /**
   * Emits invalidate all caches event
   */
  static emitInvalidateAll(): void {
    CacheEventBus.emit(CacheEventType.INVALIDATE_ALL);
  }

  /**
   * Emits invalidate specific page event
   */
  static emitInvalidatePage(page: number): void {
    CacheEventBus.emit(CacheEventType.INVALIDATE_PAGE, { page });
  }

  /**
   * Gets recent events for debugging
   */
  static getRecentEvents(): CacheEvent[] {
    return [...recentEvents];
  }

  /**
   * Clears all subscriptions (for testing/cleanup)
   */
  static clear(): void {
    eventCallbacks.clear();
    filteredCallbacks.clear();
    recentEvents = [];
  }
}
