/**
 * Deep Link Router
 * Handles URI-based navigation with pattern matching
 */

import { injectable, preDestroy } from '../di/decorators';
import { ILogger } from '../di/interfaces';
import {
  AppRoute,
  Routes,
  UserListRoute,
  UserDetailRoute,
  CreateUserRoute,
  EditUserRoute
} from './Routes';
import { INavigator, Navigator } from './Navigator';

const TAG = 'DeepLinkRouter';

/**
 * URI pattern definition
 */
export interface UriPattern {
  /** Pattern regex or path template */
  pattern: RegExp;
  /** Parameter names in order of capture groups */
  paramNames: string[];
  /** Route builder function */
  builder: (params: Record<string, string>) => AppRoute;
}

/**
 * Deep link handling result
 */
export interface DeepLinkResult {
  /** Whether the link was handled */
  handled: boolean;
  /** The matched route if any */
  route?: AppRoute;
  /** Error message if failed */
  error?: string;
}

/**
 * Deep link callback
 */
export type DeepLinkCallback = (result: DeepLinkResult) => void;

/**
 * Deep Link Router interface
 */
export interface IDeepLinkRouter {
  /** Register a URI pattern */
  registerPattern(pattern: UriPattern): void;

  /** Handle a deep link URI */
  handleUri(uri: string): Promise<DeepLinkResult>;

  /** Handle and navigate */
  handleAndNavigate(uri: string, navigator: INavigator): Promise<DeepLinkResult>;

  /** Check if URI matches any pattern */
  canHandle(uri: string): boolean;

  /** Subscribe to deep link events */
  subscribe(callback: DeepLinkCallback): () => void;

  /** Get all registered patterns */
  getPatterns(): UriPattern[];
}

/**
 * Deep Link Router implementation
 */
@injectable()
export class DeepLinkRouter implements IDeepLinkRouter {
  private logger?: ILogger;
  private patterns: UriPattern[] = [];
  private callbacks: Set<DeepLinkCallback> = new Set();

  // Default URI scheme
  private static readonly SCHEME = 'arcana';
  private static readonly HOST = 'app';

  constructor() {
    this.registerDefaultPatterns();
  }

  setLogger(logger: ILogger): void {
    this.logger = logger;
  }

  /**
   * Register default application patterns
   */
  private registerDefaultPatterns(): void {
    // Home / User List
    // arcana://app/users
    // arcana://app/home
    this.registerPattern({
      pattern: /^arcana:\/\/app\/(users|home)\/?$/,
      paramNames: [],
      builder: () => Routes.userList()
    });

    // User Detail
    // arcana://app/users/123
    // arcana://app/user/123
    this.registerPattern({
      pattern: /^arcana:\/\/app\/users?\/(\d+)\/?$/,
      paramNames: ['userId'],
      builder: (params) => Routes.userDetail(parseInt(params['userId'], 10))
    });

    // Create User
    // arcana://app/users/new
    // arcana://app/user/create
    this.registerPattern({
      pattern: /^arcana:\/\/app\/users?\/(new|create)\/?$/,
      paramNames: [],
      builder: () => Routes.createUser()
    });

    // Edit User
    // arcana://app/users/123/edit
    // arcana://app/user/123/edit
    this.registerPattern({
      pattern: /^arcana:\/\/app\/users?\/(\d+)\/edit\/?$/,
      paramNames: ['userId'],
      builder: (params) => Routes.editUser(parseInt(params['userId'], 10))
    });

    // HTTP/HTTPS links (web fallback)
    // https://arcana.app/users/123
    this.registerPattern({
      pattern: /^https?:\/\/arcana\.app\/users?\/(\d+)\/?$/,
      paramNames: ['userId'],
      builder: (params) => Routes.userDetail(parseInt(params['userId'], 10))
    });

    this.log('Default URI patterns registered');
  }

  registerPattern(pattern: UriPattern): void {
    this.patterns.push(pattern);
    this.log(`Registered pattern: ${pattern.pattern.source}`);
  }

  async handleUri(uri: string): Promise<DeepLinkResult> {
    this.log(`Handling URI: ${uri}`);

    try {
      // Normalize URI
      const normalizedUri = this.normalizeUri(uri);

      // Find matching pattern
      for (const pattern of this.patterns) {
        const match = normalizedUri.match(pattern.pattern);

        if (match) {
          // Extract parameters
          const params: Record<string, string> = {};
          pattern.paramNames.forEach((name, index) => {
            params[name] = match[index + 1] || '';
          });

          // Build route
          try {
            const route = pattern.builder(params);
            const result: DeepLinkResult = { handled: true, route };

            this.notifyCallbacks(result);
            this.log(`Matched pattern: ${pattern.pattern.source} -> ${route.type}`);

            return result;
          } catch (error) {
            const result: DeepLinkResult = {
              handled: false,
              error: `Failed to build route: ${error}`
            };
            this.notifyCallbacks(result);
            return result;
          }
        }
      }

      // No pattern matched
      const result: DeepLinkResult = {
        handled: false,
        error: `No matching pattern for URI: ${uri}`
      };
      this.notifyCallbacks(result);
      this.logError(result.error!);
      return result;

    } catch (error) {
      const result: DeepLinkResult = {
        handled: false,
        error: `Failed to handle URI: ${error}`
      };
      this.notifyCallbacks(result);
      return result;
    }
  }

  async handleAndNavigate(uri: string, navigator: INavigator): Promise<DeepLinkResult> {
    const result = await this.handleUri(uri);

    if (result.handled && result.route) {
      await navigator.navigate(result.route);
    }

    return result;
  }

  canHandle(uri: string): boolean {
    const normalizedUri = this.normalizeUri(uri);
    return this.patterns.some(pattern => pattern.pattern.test(normalizedUri));
  }

  subscribe(callback: DeepLinkCallback): () => void {
    this.callbacks.add(callback);
    return () => this.callbacks.delete(callback);
  }

  getPatterns(): UriPattern[] {
    return [...this.patterns];
  }

  @preDestroy()
  destroy(): void {
    this.callbacks.clear();
    this.patterns = [];
  }

  // ===== URI Building Helpers =====

  /**
   * Build a deep link URI for a route
   */
  static buildUri(route: AppRoute): string {
    switch (route.type) {
      case 'UserList':
        return `${DeepLinkRouter.SCHEME}://${DeepLinkRouter.HOST}/users`;

      case 'UserDetail':
        const detailRoute = route as UserDetailRoute;
        return `${DeepLinkRouter.SCHEME}://${DeepLinkRouter.HOST}/users/${detailRoute.params.userId}`;

      case 'CreateUser':
        return `${DeepLinkRouter.SCHEME}://${DeepLinkRouter.HOST}/users/new`;

      case 'EditUser':
        const editRoute = route as EditUserRoute;
        return `${DeepLinkRouter.SCHEME}://${DeepLinkRouter.HOST}/users/${editRoute.params.userId}/edit`;

      default:
        return `${DeepLinkRouter.SCHEME}://${DeepLinkRouter.HOST}`;
    }
  }

  /**
   * Build a shareable web URL for a route
   */
  static buildWebUrl(route: AppRoute): string {
    switch (route.type) {
      case 'UserList':
        return 'https://arcana.app/users';

      case 'UserDetail':
        const detailRoute = route as UserDetailRoute;
        return `https://arcana.app/users/${detailRoute.params.userId}`;

      case 'CreateUser':
        return 'https://arcana.app/users/new';

      case 'EditUser':
        const editRoute = route as EditUserRoute;
        return `https://arcana.app/users/${editRoute.params.userId}/edit`;

      default:
        return 'https://arcana.app';
    }
  }

  // ===== Private Methods =====

  private normalizeUri(uri: string): string {
    // Trim whitespace
    let normalized = uri.trim();

    // Remove trailing slashes
    while (normalized.endsWith('/')) {
      normalized = normalized.slice(0, -1);
    }

    // Lowercase scheme and host
    const schemeMatch = normalized.match(/^([a-zA-Z]+):\/\/([^/]+)/);
    if (schemeMatch) {
      const scheme = schemeMatch[1].toLowerCase();
      const host = schemeMatch[2].toLowerCase();
      normalized = `${scheme}://${host}${normalized.slice(schemeMatch[0].length)}`;
    }

    return normalized;
  }

  private notifyCallbacks(result: DeepLinkResult): void {
    this.callbacks.forEach(callback => {
      try {
        callback(result);
      } catch (error) {
        this.logError(`Callback error: ${error}`);
      }
    });
  }

  private log(message: string): void {
    if (this.logger) {
      this.logger.d(TAG, message);
    }
  }

  private logError(message: string): void {
    if (this.logger) {
      this.logger.e(TAG, message);
    }
  }
}

/**
 * URI Query parameter parser
 */
export class UriQueryParser {
  /**
   * Parse query string into key-value pairs
   */
  static parse(uri: string): Record<string, string> {
    const result: Record<string, string> = {};

    const queryStart = uri.indexOf('?');
    if (queryStart === -1) return result;

    const queryString = uri.slice(queryStart + 1);
    const pairs = queryString.split('&');

    for (const pair of pairs) {
      const [key, value] = pair.split('=');
      if (key) {
        result[decodeURIComponent(key)] = decodeURIComponent(value || '');
      }
    }

    return result;
  }

  /**
   * Build query string from key-value pairs
   */
  static build(params: Record<string, string | number | boolean>): string {
    const pairs: string[] = [];

    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== null) {
        pairs.push(`${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`);
      }
    }

    return pairs.length > 0 ? `?${pairs.join('&')}` : '';
  }
}
