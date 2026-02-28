/**
 * Injectable Analytics Service
 * Implements IAnalyticsService interface for DI container
 */

import { injectable, inject, postConstruct, preDestroy } from '../di/decorators';
import { IAnalyticsService, ILogger } from '../di/interfaces';
import { TYPES } from '../di/tokens';
import { AnalyticsEventType, AnalyticsEvent, ScreenTrackingData } from './AnalyticsService';

const TAG = 'AnalyticsServiceImpl';

/**
 * Injectable analytics service implementation
 */
@injectable()
export class AnalyticsServiceImpl implements IAnalyticsService {
  private events: AnalyticsEvent[] = [];
  private currentScreen: ScreenTrackingData | null = null;
  private sessionId: string = '';
  private sessionStartTime: number = 0;
  private isInitialized: boolean = false;
  private logger?: ILogger;

  // Configuration
  private readonly maxQueueSize = 100;
  private readonly flushIntervalMs = 30000;
  private flushTimeoutId: number | null = null;

  constructor() {
    // Logger will be set via setLogger or property injection
  }

  /**
   * Sets the logger (for manual injection)
   */
  setLogger(logger: ILogger): void {
    this.logger = logger;
  }

  @postConstruct()
  async onPostConstruct(): Promise<void> {
    // Initialize will be called separately
  }

  async initialize(): Promise<void> {
    if (this.isInitialized) return;

    this.sessionId = this.generateSessionId();
    this.sessionStartTime = Date.now();
    this.isInitialized = true;

    this.startPeriodicFlush();

    this.log(`Analytics initialized, session: ${this.sessionId}`);

    this.trackEvent('session_start', {
      session_id: this.sessionId
    });
  }

  trackScreen(screenName: string, screenClass: string = ''): void {
    if (this.currentScreen) {
      this.endScreenTracking();
    }

    this.currentScreen = {
      screenName,
      screenClass: screenClass || screenName,
      enterTime: Date.now()
    };

    this.queueEvent({
      type: AnalyticsEventType.SCREEN_VIEW,
      name: 'screen_view',
      timestamp: Date.now(),
      properties: {
        screen_name: screenName,
        screen_class: screenClass || screenName
      },
      screenName
    });

    this.log(`Screen tracked: ${screenName}`);
  }

  private endScreenTracking(): void {
    if (!this.currentScreen) return;

    const duration = Date.now() - this.currentScreen.enterTime;

    this.queueEvent({
      type: AnalyticsEventType.PERFORMANCE,
      name: 'screen_duration',
      timestamp: Date.now(),
      properties: {
        screen_name: this.currentScreen.screenName,
        duration_ms: duration
      },
      screenName: this.currentScreen.screenName
    });

    this.log(`Screen ${this.currentScreen.screenName} duration: ${duration}ms`);
    this.currentScreen = null;
  }

  trackEvent(name: string, properties: Record<string, string | number | boolean> = {}): void {
    this.queueEvent({
      type: AnalyticsEventType.CUSTOM,
      name,
      timestamp: Date.now(),
      properties: {
        ...properties,
        session_id: this.sessionId
      },
      screenName: this.currentScreen?.screenName
    });

    this.log(`Event tracked: ${name}`);
  }

  trackAction(action: string, target: string, properties: Record<string, string | number | boolean> = {}): void {
    this.queueEvent({
      type: AnalyticsEventType.USER_ACTION,
      name: action,
      timestamp: Date.now(),
      properties: {
        ...properties,
        target,
        session_id: this.sessionId
      },
      screenName: this.currentScreen?.screenName
    });

    this.log(`Action tracked: ${action} on ${target}`);
  }

  trackError(errorCode: string, errorMessage: string, properties: Record<string, string | number | boolean> = {}): void {
    this.queueEvent({
      type: AnalyticsEventType.ERROR,
      name: 'error',
      timestamp: Date.now(),
      properties: {
        ...properties,
        error_code: errorCode,
        error_message: errorMessage,
        session_id: this.sessionId
      },
      screenName: this.currentScreen?.screenName
    });

    this.log(`Error tracked: ${errorCode} - ${errorMessage}`);
  }

  trackPerformance(metric: string, value: number, unit: string = 'ms'): void {
    this.queueEvent({
      type: AnalyticsEventType.PERFORMANCE,
      name: metric,
      timestamp: Date.now(),
      properties: {
        value,
        unit,
        session_id: this.sessionId
      },
      screenName: this.currentScreen?.screenName
    });

    this.log(`Performance tracked: ${metric} = ${value}${unit}`);
  }

  startTiming(operationName: string): () => void {
    const startTime = Date.now();
    return () => {
      const duration = Date.now() - startTime;
      this.trackPerformance(operationName, duration, 'ms');
    };
  }

  private queueEvent(event: AnalyticsEvent): void {
    this.events.push(event);

    if (this.events.length >= this.maxQueueSize) {
      this.flush();
    }
  }

  async flush(): Promise<void> {
    if (this.events.length === 0) return;

    const eventsToSend = [...this.events];
    this.events = [];

    this.log(`Flushing ${eventsToSend.length} events`);

    // In production, send to analytics backend
    eventsToSend.forEach(event => {
      this.logJson(`Analytics Event: ${event.name}`, event);
    });
  }

  private startPeriodicFlush(): void {
    this.flushTimeoutId = setInterval(() => {
      this.flush();
    }, this.flushIntervalMs) as unknown as number;
  }

  getSessionDuration(): number {
    return Date.now() - this.sessionStartTime;
  }

  getCurrentScreen(): string | undefined {
    return this.currentScreen?.screenName;
  }

  private generateSessionId(): string {
    return `${Date.now()}-${Math.random().toString(36).substring(2, 9)}`;
  }

  @preDestroy()
  destroy(): void {
    this.trackEvent('session_end', {
      session_duration_ms: this.getSessionDuration()
    });

    this.endScreenTracking();
    this.flush();

    if (this.flushTimeoutId !== null) {
      clearInterval(this.flushTimeoutId);
      this.flushTimeoutId = null;
    }

    this.isInitialized = false;
    this.log('AnalyticsServiceImpl destroyed');
  }

  private log(message: string): void {
    if (this.logger) {
      this.logger.d(TAG, message);
    }
  }

  private logJson(label: string, data: object): void {
    if (this.logger) {
      this.logger.json(TAG, label, data);
    }
  }
}
