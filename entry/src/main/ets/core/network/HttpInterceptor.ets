import { http } from '@kit.NetworkKit';
import { Logger } from '../logging/Logger';

const TAG = 'HttpInterceptor';

/**
 * HTTP request information for logging
 */
export interface HttpRequestInfo {
  method: string;
  url: string;
  headers?: Record<string, string>;
  body?: string;
}

/**
 * HTTP response information for logging
 */
export interface HttpResponseInfo {
  statusCode: number;
  headers?: Record<string, string>;
  body?: string;
  duration: number;
}

/**
 * HTTP Interceptor configuration
 */
export interface HttpInterceptorConfig {
  /** Enable/disable interceptor logging */
  enabled: boolean;
  /** Log request headers */
  logRequestHeaders: boolean;
  /** Log request body */
  logRequestBody: boolean;
  /** Log response headers */
  logResponseHeaders: boolean;
  /** Log response body */
  logResponseBody: boolean;
  /** Maximum body length to log (truncate if longer) */
  maxBodyLength: number;
  /** Sensitive headers to mask (e.g., Authorization, x-api-key) */
  sensitiveHeaders: string[];
}

// Module-level configuration
let interceptorConfig: HttpInterceptorConfig = {
  enabled: true,  // Enable by default for debug builds
  logRequestHeaders: true,
  logRequestBody: true,
  logResponseHeaders: true,  // Show all headers
  logResponseBody: true,
  maxBodyLength: 8192,  // Larger body for debugging
  sensitiveHeaders: ['authorization', 'cookie', 'set-cookie']  // Don't mask x-api-key for debugging
};

/**
 * HTTP Interceptor for logging requests and responses in debug mode.
 * Provides detailed logging of HTTP traffic for debugging purposes.
 */
export class HttpInterceptor {
  /**
   * Configure the interceptor
   */
  static configure(config: Partial<HttpInterceptorConfig>): void {
    if (config.enabled !== undefined) interceptorConfig.enabled = config.enabled;
    if (config.logRequestHeaders !== undefined) interceptorConfig.logRequestHeaders = config.logRequestHeaders;
    if (config.logRequestBody !== undefined) interceptorConfig.logRequestBody = config.logRequestBody;
    if (config.logResponseHeaders !== undefined) interceptorConfig.logResponseHeaders = config.logResponseHeaders;
    if (config.logResponseBody !== undefined) interceptorConfig.logResponseBody = config.logResponseBody;
    if (config.maxBodyLength !== undefined) interceptorConfig.maxBodyLength = config.maxBodyLength;
    if (config.sensitiveHeaders !== undefined) interceptorConfig.sensitiveHeaders = config.sensitiveHeaders;
  }

  /**
   * Enable interceptor logging
   */
  static enable(): void {
    interceptorConfig.enabled = true;
    Logger.i(TAG, 'HTTP Interceptor enabled');
  }

  /**
   * Disable interceptor logging
   */
  static disable(): void {
    interceptorConfig.enabled = false;
    Logger.i(TAG, 'HTTP Interceptor disabled');
  }

  /**
   * Check if interceptor is enabled
   */
  static isEnabled(): boolean {
    return interceptorConfig.enabled;
  }

  /**
   * Log HTTP request
   */
  static logRequest(info: HttpRequestInfo): void {
    if (!interceptorConfig.enabled) return;

    const separator = '═'.repeat(70);
    Logger.i(TAG, '');
    Logger.i(TAG, separator);
    Logger.i(TAG, `  → REQUEST: ${info.method}`);
    Logger.i(TAG, `  → URL: ${info.url}`);
    Logger.i(TAG, separator);

    if (interceptorConfig.logRequestHeaders && info.headers) {
      Logger.i(TAG, '  → REQUEST HEADERS:');
      const maskedHeaders = HttpInterceptor.maskSensitiveHeaders(info.headers);
      for (const key of Object.keys(maskedHeaders)) {
        Logger.i(TAG, `       ${key}: ${maskedHeaders[key]}`);
      }
    }

    if (interceptorConfig.logRequestBody && info.body) {
      Logger.i(TAG, '  → REQUEST BODY:');
      HttpInterceptor.logJsonBody(info.body);
    }
  }

  /**
   * Log JSON body with proper formatting
   */
  private static logJsonBody(body: string): void {
    try {
      const parsed: object = JSON.parse(body) as object;
      const pretty = JSON.stringify(parsed, null, 2);
      const lines = pretty.split('\n');
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (line.length > 0) {
          Logger.i(TAG, `       ${line}`);
        }
      }
    } catch {
      // Not JSON, log as-is
      const truncated = HttpInterceptor.truncateBody(body);
      const lines = truncated.split('\n');
      for (let i = 0; i < lines.length; i++) {
        Logger.i(TAG, `       ${lines[i]}`);
      }
    }
  }

  /**
   * Log HTTP response
   */
  static logResponse(request: HttpRequestInfo, response: HttpResponseInfo): void {
    if (!interceptorConfig.enabled) return;

    const statusEmoji = HttpInterceptor.getStatusEmoji(response.statusCode);
    const separator = '─'.repeat(70);

    Logger.i(TAG, separator);
    Logger.i(TAG, `  ← RESPONSE: ${statusEmoji} ${response.statusCode}`);
    Logger.i(TAG, `  ← DURATION: ${response.duration}ms`);
    Logger.i(TAG, separator);

    if (interceptorConfig.logResponseHeaders && response.headers) {
      Logger.i(TAG, '  ← RESPONSE HEADERS:');
      const maskedHeaders = HttpInterceptor.maskSensitiveHeaders(response.headers);
      for (const key of Object.keys(maskedHeaders)) {
        Logger.i(TAG, `       ${key}: ${maskedHeaders[key]}`);
      }
    }

    if (interceptorConfig.logResponseBody) {
      if (response.body && response.body.length > 0) {
        Logger.i(TAG, '  ← RESPONSE BODY:');
        HttpInterceptor.logJsonBody(response.body);
      } else {
        Logger.i(TAG, '  ← RESPONSE BODY: (empty)');
      }
    }

    const endSeparator = '═'.repeat(70);
    Logger.i(TAG, endSeparator);
    Logger.i(TAG, '');
  }

  /**
   * Log HTTP error
   */
  static logError(request: HttpRequestInfo, error: Error | string, duration: number): void {
    if (!interceptorConfig.enabled) return;

    const separator = '═'.repeat(70);
    const errorMessage = error instanceof Error ? error.message : String(error);

    Logger.e(TAG, '');
    Logger.e(TAG, separator);
    Logger.e(TAG, `  ✗ ERROR: ${request.method}`);
    Logger.e(TAG, `  ✗ URL: ${request.url}`);
    Logger.e(TAG, `  ✗ DURATION: ${duration}ms`);
    Logger.e(TAG, separator);
    Logger.e(TAG, `  ✗ ERROR MESSAGE:`);
    Logger.e(TAG, `       ${errorMessage}`);
    if (error instanceof Error && error.stack) {
      Logger.e(TAG, `  ✗ STACK TRACE:`);
      const stackLines = error.stack.split('\n');
      for (let i = 0; i < stackLines.length; i++) {
        Logger.e(TAG, `       ${stackLines[i]}`);
      }
    }
    Logger.e(TAG, separator);
    Logger.e(TAG, '');
  }

  /**
   * Mask sensitive headers
   */
  private static maskSensitiveHeaders(headers: Record<string, string>): Record<string, string> {
    const masked: Record<string, string> = {};
    for (const key of Object.keys(headers)) {
      const lowerKey = key.toLowerCase();
      if (interceptorConfig.sensitiveHeaders.includes(lowerKey)) {
        masked[key] = '***MASKED***';
      } else {
        masked[key] = headers[key];
      }
    }
    return masked;
  }

  /**
   * Truncate body if too long
   */
  private static truncateBody(body: string): string {
    if (body.length <= interceptorConfig.maxBodyLength) {
      return body;
    }
    return body.substring(0, interceptorConfig.maxBodyLength) + `... [truncated, ${body.length} total bytes]`;
  }

  /**
   * Get status emoji based on status code
   */
  private static getStatusEmoji(statusCode: number): string {
    if (statusCode >= 200 && statusCode < 300) return '✓';
    if (statusCode >= 300 && statusCode < 400) return '↪';
    if (statusCode >= 400 && statusCode < 500) return '✗';
    if (statusCode >= 500) return '⚠';
    return '?';
  }
}

/**
 * Wrapped HTTP client with interceptor support
 */
export class InterceptedHttpClient {
  private httpRequest: http.HttpRequest;

  constructor() {
    this.httpRequest = http.createHttp();
  }

  /**
   * Execute HTTP request with logging
   */
  async request(
    url: string,
    options: http.HttpRequestOptions
  ): Promise<http.HttpResponse> {
    const method = options.method?.toString() ?? 'GET';
    const headers = options.header as Record<string, string> | undefined;
    const body = typeof options.extraData === 'string' ? options.extraData : undefined;

    const requestInfo: HttpRequestInfo = {
      method: method,
      url: url,
      headers: headers,
      body: body
    };

    // Log request
    HttpInterceptor.logRequest(requestInfo);

    const startTime = Date.now();

    try {
      const response = await this.httpRequest.request(url, options);
      const duration = Date.now() - startTime;

      // Extract response body safely
      let responseBody: string | undefined = undefined;
      if (response.result !== null && response.result !== undefined) {
        if (typeof response.result === 'string') {
          responseBody = response.result;
        } else {
          try {
            responseBody = JSON.stringify(response.result);
          } catch {
            responseBody = String(response.result);
          }
        }
      }

      // Log response
      const responseInfo: HttpResponseInfo = {
        statusCode: response.responseCode,
        headers: response.header as Record<string, string> | undefined,
        body: responseBody,
        duration: duration
      };

      HttpInterceptor.logResponse(requestInfo, responseInfo);

      return response;
    } catch (error) {
      const duration = Date.now() - startTime;
      const errorObj = error instanceof Error ? error : new Error(String(error));
      HttpInterceptor.logError(requestInfo, errorObj, duration);
      throw errorObj;
    }
  }

  /**
   * Destroy HTTP client
   */
  destroy(): void {
    this.httpRequest.destroy();
  }
}
