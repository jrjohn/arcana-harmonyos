import { Logger } from '../logging/Logger';

const TAG = 'AnalyticsService';

/**
 * Class for building analytics properties
 */
export class AnalyticsProps {
  private data: Map<string, string | number | boolean> = new Map();

  set(key: string, value: string | number | boolean): AnalyticsProps {
    this.data.set(key, value);
    return this;
  }

  get(key: string): string | number | boolean | undefined {
    return this.data.get(key);
  }

  keys(): string[] {
    const result: string[] = [];
    this.data.forEach((_, key) => result.push(key));
    return result;
  }

  toRecord(): Record<string, string | number | boolean> {
    const result: Record<string, string | number | boolean> = {};
    this.data.forEach((value, key) => {
      result[key] = value;
    });
    return result;
  }

  static empty(): AnalyticsProps {
    return new AnalyticsProps();
  }

  static of(key: string, value: string | number | boolean): AnalyticsProps {
    return new AnalyticsProps().set(key, value);
  }
}

/**
 * Timing callback class to avoid standalone this in closures
 */
export class AnalyticsTimingCallback {
  private operationName: string;
  private startTime: number;
  private analyticsService: AnalyticsService;

  constructor(operationName: string, startTime: number, analyticsService: AnalyticsService) {
    this.operationName = operationName;
    this.startTime = startTime;
    this.analyticsService = analyticsService;
  }

  end(): void {
    const duration = Date.now() - this.startTime;
    this.analyticsService.trackPerformance(this.operationName, duration, 'ms');
  }
}

/**
 * Analytics event types
 */
export enum AnalyticsEventType {
  SCREEN_VIEW = 'screen_view',
  USER_ACTION = 'user_action',
  ERROR = 'error',
  PERFORMANCE = 'performance',
  CUSTOM = 'custom'
}

/**
 * Analytics event data
 */
export interface AnalyticsEvent {
  type: AnalyticsEventType;
  name: string;
  timestamp: number;
  properties: AnalyticsProps;
  screenName: string | undefined;
}

/**
 * Screen tracking decorator data
 */
export interface ScreenTrackingData {
  screenName: string;
  screenClass: string;
  enterTime: number;
}

/**
 * Analytics service for tracking user behavior and app performance.
 * Follows the AOP pattern from the Android app with screen tracking.
 */
export class AnalyticsService {
  private events: AnalyticsEvent[] = [];
  private currentScreen: ScreenTrackingData | null = null;
  private sessionId: string = '';
  private sessionStartTime: number = 0;
  private isInitialized: boolean = false;

  // Configuration
  private readonly maxQueueSize = 100;
  private readonly flushIntervalMs = 30000;
  private flushTimeoutId: number | null = null;

  /**
   * Initializes the analytics service
   */
  async initialize(): Promise<void> {
    if (this.isInitialized) return;

    this.sessionId = this.generateSessionId();
    this.sessionStartTime = Date.now();
    this.isInitialized = true;

    // Start periodic flush
    this.startPeriodicFlush();

    Logger.d(TAG, `Analytics initialized, session: ${this.sessionId}`);

    // Track session start
    const sessionProps = AnalyticsProps.of('session_id', this.sessionId);
    this.trackEvent('session_start', sessionProps);
  }

  /**
   * Tracks a screen view
   */
  trackScreen(screenName: string, screenClass: string = ''): void {
    // End previous screen tracking
    if (this.currentScreen) {
      this.endScreenTracking();
    }

    // Start new screen tracking
    this.currentScreen = {
      screenName,
      screenClass: screenClass || screenName,
      enterTime: Date.now()
    };

    const screenViewProps = AnalyticsProps.empty()
      .set('screen_name', screenName)
      .set('screen_class', screenClass || screenName);
    this.queueEventDirect(AnalyticsEventType.SCREEN_VIEW, 'screen_view', screenViewProps, screenName);

    Logger.d(TAG, `Screen tracked: ${screenName}`);
  }

  /**
   * Ends tracking for the current screen
   */
  private endScreenTracking(): void {
    if (!this.currentScreen) return;

    const duration = Date.now() - this.currentScreen.enterTime;

    const durationProps = AnalyticsProps.empty()
      .set('screen_name', this.currentScreen.screenName)
      .set('duration_ms', duration);
    this.queueEventDirect(AnalyticsEventType.PERFORMANCE, 'screen_duration', durationProps, this.currentScreen.screenName);

    Logger.d(TAG, `Screen ${this.currentScreen.screenName} duration: ${duration}ms`);
    this.currentScreen = null;
  }

  /**
   * Tracks a custom event
   */
  trackEvent(name: string, properties: AnalyticsProps = AnalyticsProps.empty()): void {
    const eventProperties = this.mergeProperties(properties, this.sessionId);
    const screenName = this.currentScreen !== null ? this.currentScreen.screenName : undefined;
    this.queueEventDirect(AnalyticsEventType.CUSTOM, name, eventProperties, screenName);
    Logger.d(TAG, `Event tracked: ${name}`);
  }

  /**
   * Tracks a user action
   */
  trackAction(action: string, target: string, properties: AnalyticsProps = AnalyticsProps.empty()): void {
    const eventProperties = this.mergePropertiesWithTarget(properties, target, this.sessionId);
    const screenName = this.currentScreen !== null ? this.currentScreen.screenName : undefined;
    this.queueEventDirect(AnalyticsEventType.USER_ACTION, action, eventProperties, screenName);
    Logger.d(TAG, `Action tracked: ${action} on ${target}`);
  }

  /**
   * Tracks an error
   */
  trackError(errorCode: string, errorMessage: string, properties: AnalyticsProps = AnalyticsProps.empty()): void {
    const eventProperties = this.mergePropertiesWithError(properties, errorCode, errorMessage, this.sessionId);
    const screenName = this.currentScreen !== null ? this.currentScreen.screenName : undefined;
    this.queueEventDirect(AnalyticsEventType.ERROR, 'error', eventProperties, screenName);
    Logger.d(TAG, `Error tracked: ${errorCode} - ${errorMessage}`);
  }

  /**
   * Creates and queues an event directly
   */
  private queueEventDirect(type: AnalyticsEventType, name: string, properties: AnalyticsProps, screenName: string | undefined): void {
    const event: AnalyticsEvent = {
      type: type,
      name: name,
      timestamp: Date.now(),
      properties: properties,
      screenName: screenName
    };
    this.queueEvent(event);
  }

  /**
   * Merges properties with session ID
   */
  private mergeProperties(properties: AnalyticsProps, sessionId: string): AnalyticsProps {
    const result = AnalyticsProps.empty();
    for (const key of properties.keys()) {
      const val = properties.get(key);
      if (val !== undefined) {
        result.set(key, val);
      }
    }
    result.set('session_id', sessionId);
    return result;
  }

  /**
   * Merges properties with target and session ID
   */
  private mergePropertiesWithTarget(properties: AnalyticsProps, target: string, sessionId: string): AnalyticsProps {
    const result = AnalyticsProps.empty();
    for (const key of properties.keys()) {
      const val = properties.get(key);
      if (val !== undefined) {
        result.set(key, val);
      }
    }
    result.set('target', target);
    result.set('session_id', sessionId);
    return result;
  }

  /**
   * Merges properties with error info and session ID
   */
  private mergePropertiesWithError(properties: AnalyticsProps, errorCode: string, errorMessage: string, sessionId: string): AnalyticsProps {
    const result = AnalyticsProps.empty();
    for (const key of properties.keys()) {
      const val = properties.get(key);
      if (val !== undefined) {
        result.set(key, val);
      }
    }
    result.set('error_code', errorCode);
    result.set('error_message', errorMessage);
    result.set('session_id', sessionId);
    return result;
  }

  /**
   * Tracks a performance metric
   */
  trackPerformance(metric: string, value: number, unit: string = 'ms'): void {
    const perfProps = AnalyticsProps.empty()
      .set('value', value)
      .set('unit', unit)
      .set('session_id', this.sessionId);
    const currentScreenName = this.currentScreen !== null ? this.currentScreen.screenName : undefined;
    this.queueEventDirect(AnalyticsEventType.PERFORMANCE, metric, perfProps, currentScreenName);
    Logger.d(TAG, `Performance tracked: ${metric} = ${value}${unit}`);
  }

  /**
   * Creates a timing utility for measuring operations
   */
  startTiming(operationName: string): AnalyticsTimingCallback {
    const startTime = Date.now();
    return new AnalyticsTimingCallback(operationName, startTime, this);
  }

  /**
   * Queues an event for sending
   */
  private queueEvent(event: AnalyticsEvent): void {
    this.events.push(event);

    // Flush if queue is full
    if (this.events.length >= this.maxQueueSize) {
      this.flush();
    }
  }

  /**
   * Flushes queued events to the backend
   */
  async flush(): Promise<void> {
    if (this.events.length === 0) return;

    const eventsToSend: AnalyticsEvent[] = [];
    for (const event of this.events) {
      eventsToSend.push(event);
    }
    this.events = [];

    Logger.d(TAG, `Flushing ${eventsToSend.length} events`);

    // In a real app, you would send these to an analytics backend
    // For now, we just log them
    for (const event of eventsToSend) {
      Logger.json(TAG, `Analytics Event: ${event.name}`, event);
    }
  }

  /**
   * Starts periodic flush timer
   */
  private startPeriodicFlush(): void {
    const intervalId: number = setInterval(() => {
      this.flush();
    }, this.flushIntervalMs);
    this.flushTimeoutId = intervalId;
  }

  /**
   * Gets session duration
   */
  getSessionDuration(): number {
    return Date.now() - this.sessionStartTime;
  }

  /**
   * Gets current screen name
   */
  getCurrentScreen(): string | undefined {
    return this.currentScreen?.screenName;
  }

  /**
   * Generates a unique session ID
   */
  private generateSessionId(): string {
    return `${Date.now()}-${Math.random().toString(36).substring(2, 9)}`;
  }

  /**
   * Cleanup resources
   */
  destroy(): void {
    // Track session end
    const endProps = AnalyticsProps.of('session_duration_ms', this.getSessionDuration());
    this.trackEvent('session_end', endProps);

    // End current screen
    this.endScreenTracking();

    // Flush remaining events
    this.flush();

    // Stop periodic flush
    if (this.flushTimeoutId !== null) {
      clearInterval(this.flushTimeoutId);
      this.flushTimeoutId = null;
    }

    this.isInitialized = false;
    Logger.d(TAG, 'AnalyticsService destroyed');
  }
}

/**
 * Decorator-style class for tracking screens.
 * Use this to wrap page entry.
 */
export class ScreenTracker {
  private analytics: AnalyticsService;
  private screenName: string;

  constructor(analytics: AnalyticsService, screenName: string) {
    this.analytics = analytics;
    this.screenName = screenName;
    this.analytics.trackScreen(screenName);
  }

  cleanup(): void {
    // Cleanup when screen is left
  }
}
