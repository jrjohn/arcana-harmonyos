/**
 * Structured error codes for the application.
 * Following the pattern from the Android app (E1000-E9999 ranges).
 */
export enum ErrorCode {
  // Network Errors (E1000-E1999)
  NETWORK_ERROR = 'E1000',
  NETWORK_TIMEOUT = 'E1001',
  NETWORK_NO_CONNECTION = 'E1002',
  NETWORK_SERVER_ERROR = 'E1003',
  NETWORK_CLIENT_ERROR = 'E1004',

  // API Errors (E2000-E2999)
  API_ERROR = 'E2000',
  API_NOT_FOUND = 'E2001',
  API_UNAUTHORIZED = 'E2002',
  API_FORBIDDEN = 'E2003',
  API_RATE_LIMITED = 'E2004',
  API_VALIDATION_ERROR = 'E2005',

  // Database Errors (E3000-E3999)
  DATABASE_ERROR = 'E3000',
  DATABASE_NOT_FOUND = 'E3001',
  DATABASE_CONSTRAINT_VIOLATION = 'E3002',
  DATABASE_MIGRATION_ERROR = 'E3003',

  // Validation Errors (E4000-E4999)
  VALIDATION_ERROR = 'E4000',
  VALIDATION_REQUIRED = 'E4001',
  VALIDATION_FORMAT = 'E4002',
  VALIDATION_LENGTH = 'E4003',
  VALIDATION_RANGE = 'E4004',

  // Sync Errors (E5000-E5999)
  SYNC_ERROR = 'E5000',
  SYNC_CONFLICT = 'E5001',
  SYNC_TIMEOUT = 'E5002',
  SYNC_QUEUE_FULL = 'E5003',

  // Parse Errors (E6000-E6999)
  PARSE_ERROR = 'E6000',

  // Unknown Error
  UNKNOWN = 'E9999'
}

/**
 * Options for AppError constructor
 */
export interface AppErrorOptions {
  debugInfo?: string;
  cause?: Error;
  recoverable?: boolean;
}

/**
 * Application-specific error with structured information
 */
export class AppError extends Error {
  readonly code: ErrorCode;
  readonly userMessage: string;
  readonly debugInfo?: string;
  readonly cause?: Error;
  readonly timestamp: number;
  readonly recoverable: boolean;

  constructor(
    code: ErrorCode,
    message: string,
    userMessage?: string,
    options?: AppErrorOptions
  ) {
    super(message);
    this.name = 'AppError';
    this.code = code;
    this.userMessage = userMessage !== undefined ? userMessage : this.getDefaultUserMessage(code);
    this.debugInfo = options?.debugInfo;
    this.cause = options?.cause;
    this.timestamp = Date.now();
    this.recoverable = options?.recoverable !== undefined ? options.recoverable : this.isRecoverableByDefault(code);
  }

  private getDefaultUserMessage(code: ErrorCode): string {
    switch (code) {
      case ErrorCode.NETWORK_ERROR:
      case ErrorCode.NETWORK_TIMEOUT:
        return 'Network error. Please check your connection and try again.';
      case ErrorCode.NETWORK_NO_CONNECTION:
        return 'No internet connection. Your changes will be saved locally.';
      case ErrorCode.NETWORK_SERVER_ERROR:
        return 'Server error. Please try again later.';
      case ErrorCode.API_NOT_FOUND:
        return 'The requested resource was not found.';
      case ErrorCode.API_UNAUTHORIZED:
      case ErrorCode.API_FORBIDDEN:
        return 'You are not authorized to perform this action.';
      case ErrorCode.API_RATE_LIMITED:
        return 'Too many requests. Please wait a moment and try again.';
      case ErrorCode.DATABASE_ERROR:
        return 'Failed to save data locally. Please try again.';
      case ErrorCode.VALIDATION_ERROR:
        return 'Please check your input and try again.';
      case ErrorCode.SYNC_ERROR:
        return 'Failed to sync data. Will retry automatically.';
      case ErrorCode.SYNC_CONFLICT:
        return 'Data conflict detected. Please refresh and try again.';
      case ErrorCode.PARSE_ERROR:
        return 'Failed to process server response. Please try again.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  private isRecoverableByDefault(code: ErrorCode): boolean {
    switch (code) {
      case ErrorCode.NETWORK_ERROR:
      case ErrorCode.NETWORK_TIMEOUT:
      case ErrorCode.NETWORK_NO_CONNECTION:
      case ErrorCode.NETWORK_SERVER_ERROR:
      case ErrorCode.API_RATE_LIMITED:
      case ErrorCode.SYNC_ERROR:
      case ErrorCode.SYNC_TIMEOUT:
        return true;
      default:
        return false;
    }
  }

  /**
   * Creates a string representation for logging
   */
  toLogString(): string {
    let log = `[${this.code}] ${this.message}`;
    if (this.debugInfo) {
      log += ` | Debug: ${this.debugInfo}`;
    }
    if (this.cause) {
      log += ` | Cause: ${this.cause.message}`;
    }
    return log;
  }
}

/**
 * Factory class for common errors
 */
export class AppErrorFactory {
  static networkError(message: string, cause?: Error): AppError {
    const options: AppErrorOptions = { cause: cause, recoverable: true };
    return new AppError(ErrorCode.NETWORK_ERROR, message, undefined, options);
  }

  static networkTimeout(): AppError {
    return new AppError(ErrorCode.NETWORK_TIMEOUT, 'Request timed out');
  }

  static noConnection(): AppError {
    return new AppError(ErrorCode.NETWORK_NO_CONNECTION, 'No network connection');
  }

  static serverError(statusCode: number, message?: string): AppError {
    const options: AppErrorOptions = { debugInfo: `HTTP ${statusCode}` };
    return new AppError(
      ErrorCode.NETWORK_SERVER_ERROR,
      `Server error: ${statusCode}`,
      message,
      options
    );
  }

  static apiNotFound(resource: string): AppError {
    return new AppError(ErrorCode.API_NOT_FOUND, `${resource} not found`);
  }

  static validationError(field: string, message: string): AppError {
    const options: AppErrorOptions = { recoverable: false };
    return new AppError(
      ErrorCode.VALIDATION_ERROR,
      `Validation failed for ${field}: ${message}`,
      message,
      options
    );
  }

  static databaseError(operation: string, cause?: Error): AppError {
    const options: AppErrorOptions = { cause: cause };
    return new AppError(
      ErrorCode.DATABASE_ERROR,
      `Database ${operation} failed`,
      undefined,
      options
    );
  }

  static syncError(message: string, cause?: Error): AppError {
    const options: AppErrorOptions = { cause: cause, recoverable: true };
    return new AppError(ErrorCode.SYNC_ERROR, message, undefined, options);
  }

  static syncConflict(resourceId: string): AppError {
    const options: AppErrorOptions = { debugInfo: `Resource ID: ${resourceId}` };
    return new AppError(
      ErrorCode.SYNC_CONFLICT,
      `Sync conflict for resource: ${resourceId}`,
      undefined,
      options
    );
  }

  static parseError(message: string): AppError {
    const options: AppErrorOptions = { recoverable: false };
    return new AppError(
      ErrorCode.PARSE_ERROR,
      `Parse error: ${message}`,
      'Failed to parse server response',
      options
    );
  }

  static fromHttpStatus(status: number, message?: string): AppError {
    if (status === 404) {
      return new AppError(ErrorCode.API_NOT_FOUND, message !== undefined ? message : 'Not found');
    } else if (status === 401) {
      return new AppError(ErrorCode.API_UNAUTHORIZED, message !== undefined ? message : 'Unauthorized');
    } else if (status === 403) {
      return new AppError(ErrorCode.API_FORBIDDEN, message !== undefined ? message : 'Forbidden');
    } else if (status === 429) {
      return new AppError(ErrorCode.API_RATE_LIMITED, message !== undefined ? message : 'Rate limited');
    } else if (status >= 500) {
      return AppErrorFactory.serverError(status, message);
    } else if (status >= 400) {
      return new AppError(ErrorCode.NETWORK_CLIENT_ERROR, message !== undefined ? message : `Client error: ${status}`);
    }
    return new AppError(ErrorCode.UNKNOWN, message !== undefined ? message : 'Unknown error');
  }

  static unknown(cause?: Error): AppError {
    const options: AppErrorOptions = { cause: cause };
    return new AppError(
      ErrorCode.UNKNOWN,
      cause?.message !== undefined ? cause.message : 'Unknown error',
      undefined,
      options
    );
  }
}
