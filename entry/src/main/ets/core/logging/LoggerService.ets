/**
 * Injectable Logger Service
 * Implements ILogger interface for DI container
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { injectable, postConstruct } from '../di/decorators';
import { ILogger } from '../di/interfaces';
import { LogLevel } from './Logger';

/**
 * Injectable logger service implementation
 */
@injectable()
export class LoggerService implements ILogger {
  private readonly DOMAIN = 0x0001;
  private currentLevel: LogLevel = LogLevel.DEBUG;
  private isEnabled: boolean = true;

  @postConstruct()
  initialize(): void {
    // Logger is ready to use immediately
  }

  setLevel(level: LogLevel): void {
    this.currentLevel = level;
  }

  setEnabled(enabled: boolean): void {
    this.isEnabled = enabled;
  }

  d(tag: string, message: string, ...args: Object[]): void {
    if (this.shouldLog(LogLevel.DEBUG)) {
      hilog.debug(this.DOMAIN, tag, this.formatMessage(message, args));
    }
  }

  i(tag: string, message: string, ...args: Object[]): void {
    if (this.shouldLog(LogLevel.INFO)) {
      hilog.info(this.DOMAIN, tag, this.formatMessage(message, args));
    }
  }

  w(tag: string, message: string, ...args: Object[]): void {
    if (this.shouldLog(LogLevel.WARN)) {
      hilog.warn(this.DOMAIN, tag, this.formatMessage(message, args));
    }
  }

  e(tag: string, message: string, ...args: Object[]): void {
    if (this.shouldLog(LogLevel.ERROR)) {
      hilog.error(this.DOMAIN, tag, this.formatMessage(message, args));
    }
  }

  f(tag: string, message: string, ...args: Object[]): void {
    if (this.shouldLog(LogLevel.FATAL)) {
      hilog.fatal(this.DOMAIN, tag, this.formatMessage(message, args));
    }
  }

  log(level: LogLevel, tag: string, message: string, ...args: Object[]): void {
    switch (level) {
      case LogLevel.DEBUG:
        this.d(tag, message, ...args);
        break;
      case LogLevel.INFO:
        this.i(tag, message, ...args);
        break;
      case LogLevel.WARN:
        this.w(tag, message, ...args);
        break;
      case LogLevel.ERROR:
        this.e(tag, message, ...args);
        break;
      case LogLevel.FATAL:
        this.f(tag, message, ...args);
        break;
    }
  }

  exception(tag: string, message: string, error: Error): void {
    const errorMessage = `${message}\nError: ${error.message}\nStack: ${error.stack || 'N/A'}`;
    this.e(tag, errorMessage);
  }

  json(tag: string, label: string, data: object): void {
    if (this.shouldLog(LogLevel.DEBUG)) {
      try {
        const json = JSON.stringify(data, null, 2);
        this.d(tag, `${label}: ${json}`);
      } catch {
        this.d(tag, `${label}: [Unable to stringify]`);
      }
    }
  }

  time(tag: string, label: string): () => void {
    const start = Date.now();
    return () => {
      const duration = Date.now() - start;
      this.d(tag, `${label} completed in ${duration}ms`);
    };
  }

  private shouldLog(level: LogLevel): boolean {
    return this.isEnabled && level >= this.currentLevel;
  }

  private formatMessage(message: string, args: Object[]): string {
    if (args.length === 0) {
      return message;
    }

    let result = message;
    args.forEach((arg, index) => {
      const placeholder = `{${index}}`;
      if (result.includes(placeholder)) {
        result = result.replace(placeholder, String(arg));
      }
    });

    return result;
  }
}
