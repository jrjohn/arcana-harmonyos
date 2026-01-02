/**
 * ApiClient - Declarative HTTP Client for HarmonyOS ArkTS
 *
 * A Retrofit/Ktorfit-inspired declarative HTTP client that works within
 * ArkTS limitations (no runtime reflection/decorators).
 *
 * Features:
 * - Type-safe request/response handling
 * - Automatic JSON serialization/deserialization
 * - Built-in Result pattern error handling
 * - Request/Response interceptors
 * - Configurable timeouts and headers
 */

import { http } from '@kit.NetworkKit';
import { Result, ResultFactory } from '../../domain/models/Result';
import { AppError, AppErrorFactory } from '../../domain/models/AppError';
import { HttpInterceptor, HttpRequestInfo, HttpResponseInfo } from '../network/HttpInterceptor';

/**
 * HTTP methods supported by the client
 */
export enum HttpMethod {
  GET = 'GET',
  POST = 'POST',
  PUT = 'PUT',
  PATCH = 'PATCH',
  DELETE = 'DELETE'
}

/**
 * API client configuration
 */
export class ApiClientConfig {
  readonly baseUrl: string;
  readonly timeout: number;
  readonly headers: Map<string, string>;
  readonly enableLogging: boolean;

  constructor(
    baseUrl: string,
    timeout: number = 30000,
    headers: Map<string, string> = new Map(),
    enableLogging: boolean = true
  ) {
    this.baseUrl = baseUrl;
    this.timeout = timeout;
    this.headers = headers;
    this.enableLogging = enableLogging;
  }
}

/**
 * Request configuration for a single API call
 */
export class RequestConfig<TBody> {
  readonly method: HttpMethod;
  readonly path: string;
  readonly pathParams: Map<string, string>;
  readonly queryParams: Map<string, string>;
  readonly headers: Map<string, string>;
  readonly body: TBody | undefined;

  constructor(
    method: HttpMethod,
    path: string,
    pathParams: Map<string, string> = new Map(),
    queryParams: Map<string, string> = new Map(),
    headers: Map<string, string> = new Map(),
    body: TBody | undefined = undefined
  ) {
    this.method = method;
    this.path = path;
    this.pathParams = pathParams;
    this.queryParams = queryParams;
    this.headers = headers;
    this.body = body;
  }
}

/**
 * Response mapper function type
 */
export type ResponseMapper<TRaw, TResult> = (raw: TRaw) => TResult;

/**
 * Request interceptor function type
 */
export type RequestInterceptor = (config: RequestConfig<Object>) => RequestConfig<Object>;

/**
 * Response interceptor function type
 */
export type ResponseInterceptor = (response: http.HttpResponse) => http.HttpResponse;

/**
 * Core API Client implementation
 */
export class ApiClient {
  private config: ApiClientConfig;
  private httpRequest: http.HttpRequest;
  private requestInterceptors: RequestInterceptor[] = [];
  private responseInterceptors: ResponseInterceptor[] = [];

  constructor(config: ApiClientConfig) {
    this.config = config;
    this.httpRequest = http.createHttp();
  }

  /**
   * Creates a new ApiClient with the given base URL
   */
  static create(baseUrl: string): ApiClientBuilder {
    return new ApiClientBuilder(baseUrl);
  }

  /**
   * Adds a request interceptor
   */
  addRequestInterceptor(interceptor: RequestInterceptor): void {
    this.requestInterceptors.push(interceptor);
  }

  /**
   * Adds a response interceptor
   */
  addResponseInterceptor(interceptor: ResponseInterceptor): void {
    this.responseInterceptors.push(interceptor);
  }

  /**
   * Executes a GET request
   */
  async get<TResponse>(
    path: string,
    mapper: ResponseMapper<Object, TResponse>,
    queryParams: Map<string, string> = new Map(),
    pathParams: Map<string, string> = new Map()
  ): Promise<Result<TResponse, AppError>> {
    const config = new RequestConfig<undefined>(
      HttpMethod.GET,
      path,
      pathParams,
      queryParams,
      new Map(),
      undefined
    );
    return this.execute(config, mapper);
  }

  /**
   * Executes a POST request
   */
  async post<TBody, TResponse>(
    path: string,
    body: TBody,
    mapper: ResponseMapper<Object, TResponse>,
    queryParams: Map<string, string> = new Map(),
    pathParams: Map<string, string> = new Map()
  ): Promise<Result<TResponse, AppError>> {
    const config = new RequestConfig<TBody>(
      HttpMethod.POST,
      path,
      pathParams,
      queryParams,
      new Map(),
      body
    );
    return this.execute(config, mapper);
  }

  /**
   * Executes a PUT request
   */
  async put<TBody, TResponse>(
    path: string,
    body: TBody,
    mapper: ResponseMapper<Object, TResponse>,
    queryParams: Map<string, string> = new Map(),
    pathParams: Map<string, string> = new Map()
  ): Promise<Result<TResponse, AppError>> {
    const config = new RequestConfig<TBody>(
      HttpMethod.PUT,
      path,
      pathParams,
      queryParams,
      new Map(),
      body
    );
    return this.execute(config, mapper);
  }

  /**
   * Executes a PATCH request
   */
  async patch<TBody, TResponse>(
    path: string,
    body: TBody,
    mapper: ResponseMapper<Object, TResponse>,
    queryParams: Map<string, string> = new Map(),
    pathParams: Map<string, string> = new Map()
  ): Promise<Result<TResponse, AppError>> {
    const config = new RequestConfig<TBody>(
      HttpMethod.PATCH,
      path,
      pathParams,
      queryParams,
      new Map(),
      body
    );
    return this.execute(config, mapper);
  }

  /**
   * Executes a DELETE request
   */
  async delete(
    path: string,
    pathParams: Map<string, string> = new Map(),
    queryParams: Map<string, string> = new Map()
  ): Promise<Result<void, AppError>> {
    const config = new RequestConfig<undefined>(
      HttpMethod.DELETE,
      path,
      pathParams,
      queryParams,
      new Map(),
      undefined
    );
    return this.executeVoid(config);
  }

  /**
   * Core execution method with response mapping
   */
  private async execute<TBody, TResponse>(
    requestConfig: RequestConfig<TBody>,
    mapper: ResponseMapper<Object, TResponse>
  ): Promise<Result<TResponse, AppError>> {
    const startTime = Date.now();
    const url = this.buildUrl(requestConfig);

    // Apply request interceptors
    let finalConfig: RequestConfig<Object> = requestConfig as RequestConfig<Object>;
    for (const interceptor of this.requestInterceptors) {
      finalConfig = interceptor(finalConfig);
    }

    const headers = this.buildHeaders(finalConfig);
    const requestInfo: HttpRequestInfo = {
      method: finalConfig.method,
      url: url,
      headers: headers,
      body: finalConfig.body ? JSON.stringify(finalConfig.body) : undefined
    };

    if (this.config.enableLogging) {
      HttpInterceptor.logRequest(requestInfo);
    }

    try {
      const httpMethod = this.toHttpMethod(finalConfig.method);
      const options: http.HttpRequestOptions = {
        method: httpMethod,
        header: headers,
        connectTimeout: this.config.timeout,
        readTimeout: this.config.timeout
      };

      if (finalConfig.body) {
        options.extraData = JSON.stringify(finalConfig.body);
      }

      let response = await this.httpRequest.request(url, options);

      // Apply response interceptors
      for (const interceptor of this.responseInterceptors) {
        response = interceptor(response);
      }

      const duration = Date.now() - startTime;

      if (this.config.enableLogging) {
        const responseInfo: HttpResponseInfo = {
          statusCode: response.responseCode,
          headers: response.header as Record<string, string>,
          body: typeof response.result === 'string' ? response.result : JSON.stringify(response.result),
          duration: duration
        };
        HttpInterceptor.logResponse(requestInfo, responseInfo);
      }

      return this.handleResponse(response, mapper);
    } catch (error) {
      const duration = Date.now() - startTime;
      if (this.config.enableLogging) {
        HttpInterceptor.logError(requestInfo, error instanceof Error ? error : new Error(String(error)), duration);
      }
      return ResultFactory.failure(this.handleError(error));
    }
  }

  /**
   * Execution method for void responses (DELETE, etc.)
   */
  private async executeVoid<TBody>(
    requestConfig: RequestConfig<TBody>
  ): Promise<Result<void, AppError>> {
    const startTime = Date.now();
    const url = this.buildUrl(requestConfig);

    let finalConfig: RequestConfig<Object> = requestConfig as RequestConfig<Object>;
    for (const interceptor of this.requestInterceptors) {
      finalConfig = interceptor(finalConfig);
    }

    const headers = this.buildHeaders(finalConfig);
    const requestInfo: HttpRequestInfo = {
      method: finalConfig.method,
      url: url,
      headers: headers,
      body: undefined
    };

    if (this.config.enableLogging) {
      HttpInterceptor.logRequest(requestInfo);
    }

    try {
      const httpMethod = this.toHttpMethod(finalConfig.method);
      let response = await this.httpRequest.request(url, {
        method: httpMethod,
        header: headers,
        connectTimeout: this.config.timeout,
        readTimeout: this.config.timeout
      });

      for (const interceptor of this.responseInterceptors) {
        response = interceptor(response);
      }

      const duration = Date.now() - startTime;

      if (this.config.enableLogging) {
        const responseInfo: HttpResponseInfo = {
          statusCode: response.responseCode,
          headers: response.header as Record<string, string>,
          body: undefined,
          duration: duration
        };
        HttpInterceptor.logResponse(requestInfo, responseInfo);
      }

      if (response.responseCode >= 200 && response.responseCode < 300) {
        return ResultFactory.success(undefined);
      } else if (response.responseCode === 404) {
        return ResultFactory.failure(AppErrorFactory.apiNotFound('Resource'));
      } else {
        return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
      }
    } catch (error) {
      const duration = Date.now() - startTime;
      if (this.config.enableLogging) {
        HttpInterceptor.logError(requestInfo, error instanceof Error ? error : new Error(String(error)), duration);
      }
      return ResultFactory.failure(this.handleError(error));
    }
  }

  /**
   * Builds the full URL with path and query parameters
   */
  private buildUrl<TBody>(config: RequestConfig<TBody>): string {
    let path = config.path;

    // Replace path parameters
    config.pathParams.forEach((value, key) => {
      path = path.replace(`{${key}}`, encodeURIComponent(value));
    });

    let url = `${this.config.baseUrl}${path}`;

    // Add query parameters
    if (config.queryParams.size > 0) {
      const queryParts: string[] = [];
      config.queryParams.forEach((value, key) => {
        queryParts.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`);
      });
      url = `${url}?${queryParts.join('&')}`;
    }

    return url;
  }

  /**
   * Builds headers combining config defaults and request-specific headers
   */
  private buildHeaders<TBody>(config: RequestConfig<TBody>): Record<string, string> {
    const headers: Record<string, string> = {};

    // Add default headers
    this.config.headers.forEach((value, key) => {
      headers[key] = value;
    });

    // Add Content-Type for requests with body
    if (config.body) {
      headers['Content-Type'] = 'application/json';
    }

    // Add request-specific headers
    config.headers.forEach((value, key) => {
      headers[key] = value;
    });

    return headers;
  }

  /**
   * Converts HttpMethod enum to HarmonyOS http.RequestMethod
   */
  private toHttpMethod(method: HttpMethod): http.RequestMethod {
    switch (method) {
      case HttpMethod.GET:
        return http.RequestMethod.GET;
      case HttpMethod.POST:
        return http.RequestMethod.POST;
      case HttpMethod.PUT:
        return http.RequestMethod.PUT;
      case HttpMethod.PATCH:
        return http.RequestMethod.PATCH;
      case HttpMethod.DELETE:
        return http.RequestMethod.DELETE;
      default:
        return http.RequestMethod.GET;
    }
  }

  /**
   * Handles HTTP response and maps to Result
   */
  private handleResponse<TResponse>(
    response: http.HttpResponse,
    mapper: ResponseMapper<Object, TResponse>
  ): Result<TResponse, AppError> {
    if (response.responseCode >= 200 && response.responseCode < 300) {
      try {
        const data = JSON.parse(response.result as string) as Object;
        const mapped = mapper(data);
        return ResultFactory.success(mapped);
      } catch (parseError) {
        return ResultFactory.failure(AppErrorFactory.parseError(String(parseError)));
      }
    } else if (response.responseCode === 404) {
      return ResultFactory.failure(AppErrorFactory.apiNotFound('Resource'));
    } else {
      return ResultFactory.failure(AppErrorFactory.fromHttpStatus(response.responseCode));
    }
  }

  /**
   * Converts errors to AppError
   */
  private handleError(error: Error | Object): AppError {
    if (error instanceof Error) {
      const message = error.message.toLowerCase();
      if (message.includes('timeout')) {
        return AppErrorFactory.networkTimeout();
      } else if (message.includes('network') || message.includes('connection')) {
        return AppErrorFactory.noConnection();
      }
      return AppErrorFactory.networkError(error.message, error);
    }
    return AppErrorFactory.unknown();
  }

  /**
   * Destroys the HTTP client and releases resources
   */
  destroy(): void {
    this.httpRequest.destroy();
  }
}

/**
 * Builder for ApiClient configuration
 */
export class ApiClientBuilder {
  private baseUrl: string;
  private timeout: number = 30000;
  private headers: Map<string, string> = new Map();
  private enableLogging: boolean = true;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }

  /**
   * Sets the request timeout in milliseconds
   */
  setTimeout(timeout: number): ApiClientBuilder {
    this.timeout = timeout;
    return this;
  }

  /**
   * Adds a default header to all requests
   */
  addHeader(key: string, value: string): ApiClientBuilder {
    this.headers.set(key, value);
    return this;
  }

  /**
   * Sets the Content-Type header
   */
  contentType(type: string): ApiClientBuilder {
    return this.addHeader('Content-Type', type);
  }

  /**
   * Sets the Accept header
   */
  accept(type: string): ApiClientBuilder {
    return this.addHeader('Accept', type);
  }

  /**
   * Adds Bearer token authentication
   */
  bearerToken(token: string): ApiClientBuilder {
    return this.addHeader('Authorization', `Bearer ${token}`);
  }

  /**
   * Adds API key authentication
   */
  apiKey(headerName: string, key: string): ApiClientBuilder {
    return this.addHeader(headerName, key);
  }

  /**
   * Enables or disables request/response logging
   */
  logging(enabled: boolean): ApiClientBuilder {
    this.enableLogging = enabled;
    return this;
  }

  /**
   * Builds the ApiClient instance
   */
  build(): ApiClient {
    const config = new ApiClientConfig(
      this.baseUrl,
      this.timeout,
      this.headers,
      this.enableLogging
    );
    return new ApiClient(config);
  }
}
