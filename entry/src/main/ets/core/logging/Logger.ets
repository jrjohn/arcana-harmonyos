import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * Timing callback class to avoid standalone this in closures
 */
export class TimingCallback {
  private tag: string;
  private label: string;
  private start: number;

  constructor(tag: string, label: string, start: number) {
    this.tag = tag;
    this.label = label;
    this.start = start;
  }

  end(): void {
    const duration = Date.now() - this.start;
    Logger.d(this.tag, `${this.label} completed in ${duration}ms`);
  }
}

/**
 * Log level enum
 */
export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3,
  FATAL = 4
}

/**
 * Application logger utility.
 * Wraps HarmonyOS hilog with additional functionality.
 */
// Module-level state to avoid static this references
let loggerCurrentLevel: LogLevel = LogLevel.DEBUG;
let loggerIsEnabled: boolean = true;
const LOGGER_DOMAIN = 0x0001;

/**
 * Application logger utility.
 * Wraps HarmonyOS hilog with additional functionality.
 */
export class Logger {
  /**
   * Sets the minimum log level
   */
  static setLevel(level: LogLevel): void {
    loggerCurrentLevel = level;
  }

  /**
   * Enables or disables logging
   */
  static setEnabled(enabled: boolean): void {
    loggerIsEnabled = enabled;
  }

  /**
   * Debug level log
   */
  static d(tag: string, message: string): void {
    if (loggerIsEnabled && LogLevel.DEBUG >= loggerCurrentLevel) {
      hilog.debug(LOGGER_DOMAIN, tag, message);
    }
  }

  /**
   * Info level log
   */
  static i(tag: string, message: string): void {
    if (loggerIsEnabled && LogLevel.INFO >= loggerCurrentLevel) {
      hilog.info(LOGGER_DOMAIN, tag, message);
    }
  }

  /**
   * Warning level log
   */
  static w(tag: string, message: string): void {
    if (loggerIsEnabled && LogLevel.WARN >= loggerCurrentLevel) {
      hilog.warn(LOGGER_DOMAIN, tag, message);
    }
  }

  /**
   * Error level log
   */
  static e(tag: string, message: string): void {
    if (loggerIsEnabled && LogLevel.ERROR >= loggerCurrentLevel) {
      hilog.error(LOGGER_DOMAIN, tag, message);
    }
  }

  /**
   * Fatal level log
   */
  static f(tag: string, message: string): void {
    if (loggerIsEnabled && LogLevel.FATAL >= loggerCurrentLevel) {
      hilog.fatal(LOGGER_DOMAIN, tag, message);
    }
  }

  /**
   * Logs with specified level
   */
  static log(level: LogLevel, tag: string, message: string): void {
    switch (level) {
      case LogLevel.DEBUG:
        Logger.d(tag, message);
        break;
      case LogLevel.INFO:
        Logger.i(tag, message);
        break;
      case LogLevel.WARN:
        Logger.w(tag, message);
        break;
      case LogLevel.ERROR:
        Logger.e(tag, message);
        break;
      case LogLevel.FATAL:
        Logger.f(tag, message);
        break;
    }
  }

  /**
   * Logs an exception with stack trace
   */
  static exception(tag: string, message: string, error: Error): void {
    const stack = error.stack !== undefined ? error.stack : 'N/A';
    const errorMessage = `${message}\nError: ${error.message}\nStack: ${stack}`;
    Logger.e(tag, errorMessage);
  }

  /**
   * Logs JSON data (pretty printed in debug)
   */
  static json(tag: string, label: string, data: object): void {
    if (loggerIsEnabled && LogLevel.DEBUG >= loggerCurrentLevel) {
      try {
        const json = JSON.stringify(data, null, 2);
        Logger.d(tag, `${label}: ${json}`);
      } catch (e) {
        Logger.d(tag, `${label}: [Unable to stringify]`);
      }
    }
  }

  /**
   * Performance timing log
   */
  static time(tag: string, label: string): TimingCallback {
    const start = Date.now();
    const callback = new TimingCallback(tag, label, start);
    return callback;
  }
}
