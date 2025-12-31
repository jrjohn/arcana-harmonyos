/**
 * API configuration for the Arcana application.
 * Uses reqres.in as the test API backend.
 */

/**
 * Endpoint paths
 */
export class ApiEndpoints {
  static readonly USERS: string = '/users';

  static userById(id: number): string {
    return `/users/${id}`;
  }
}

/**
 * HTTP Headers
 */
export class ApiHeaders {
  static readonly CONTENT_TYPE: string = 'application/json';
  static readonly ACCEPT: string = 'application/json';
  static readonly API_KEY_HEADER: string = 'x-api-key';
}

/**
 * API Configuration
 */
export class ApiConfig {
  /** Base URL for the API */
  static readonly BASE_URL: string = 'https://reqres.in/api';

  /** API Key for authentication */
  static readonly API_KEY: string = 'reqres_30bb4b25423642c18ddde61de8cadc40';

  /** Request timeout in milliseconds */
  static readonly TIMEOUT: number = 30000;

  /** Number of items per page */
  static readonly PAGE_SIZE: number = 6;

  /** Maximum retry attempts */
  static readonly MAX_RETRIES: number = 3;

  /** Retry delay in milliseconds (with exponential backoff) */
  static readonly RETRY_DELAY: number = 1000;

  /** Cache TTL in milliseconds (5 minutes) */
  static readonly CACHE_TTL: number = 5 * 60 * 1000;
}

/**
 * HTTP status codes
 */
export enum HttpStatus {
  OK = 200,
  CREATED = 201,
  NO_CONTENT = 204,
  BAD_REQUEST = 400,
  UNAUTHORIZED = 401,
  FORBIDDEN = 403,
  NOT_FOUND = 404,
  CONFLICT = 409,
  UNPROCESSABLE_ENTITY = 422,
  TOO_MANY_REQUESTS = 429,
  INTERNAL_SERVER_ERROR = 500,
  BAD_GATEWAY = 502,
  SERVICE_UNAVAILABLE = 503,
  GATEWAY_TIMEOUT = 504
}
