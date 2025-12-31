/**
 * Type-Safe Navigator
 * Handles all navigation operations with compile-time type safety
 */

import { router } from '@kit.ArkUI';
import { injectable, inject, preDestroy } from '../di/decorators';
import { IAnalyticsService, ILogger } from '../di/interfaces';
import { TYPES } from '../di/tokens';
import {
  AppRoute,
  Routes,
  UserListRoute,
  UserDetailRoute,
  CreateUserRoute,
  EditUserRoute,
  RouteType
} from './Routes';

const TAG = 'Navigator';

/**
 * Navigation result
 */
export interface NavigationResult {
  success: boolean;
  error?: string;
}

/**
 * Navigation options
 */
export interface NavigationOptions {
  /** Replace current page instead of pushing */
  replace?: boolean;
  /** Clear back stack */
  clearStack?: boolean;
  /** Animation mode */
  animation?: 'default' | 'none' | 'fade' | 'slide';
}

/**
 * Navigation state callback
 */
export type NavigationCallback = (route: AppRoute) => void;

/**
 * Navigator interface for DI
 */
export interface INavigator {
  /** Navigate to a route */
  navigate(route: AppRoute, options?: NavigationOptions): Promise<NavigationResult>;

  /** Navigate back */
  back(): Promise<NavigationResult>;

  /** Navigate back to a specific route */
  backTo(routeType: RouteType): Promise<NavigationResult>;

  /** Clear back stack and navigate */
  navigateAndClear(route: AppRoute): Promise<NavigationResult>;

  /** Replace current route */
  replace(route: AppRoute): Promise<NavigationResult>;

  /** Check if can go back */
  canGoBack(): boolean;

  /** Get current route info */
  getCurrentRoute(): AppRoute | undefined;

  /** Subscribe to navigation changes */
  subscribe(callback: NavigationCallback): () => void;
}

/**
 * Navigator implementation
 */
@injectable()
export class Navigator implements INavigator {
  private logger?: ILogger;
  private analytics?: IAnalyticsService;
  private callbacks: Set<NavigationCallback> = new Set();
  private currentRoute?: AppRoute;
  private backStackDepth: number = 0;

  constructor() {}

  /**
   * Sets dependencies (for manual injection)
   */
  setDependencies(logger: ILogger, analytics: IAnalyticsService): void {
    this.logger = logger;
    this.analytics = analytics;
  }

  async navigate(route: AppRoute, options: NavigationOptions = {}): Promise<NavigationResult> {
    this.log(`Navigating to: ${route.type} (${route.url})`);

    try {
      const routerOptions: router.RouterOptions = {
        url: route.path,
        params: this.extractParams(route)
      };

      if (options.clearStack) {
        await router.clear();
        this.backStackDepth = 0;
      }

      if (options.replace) {
        await router.replaceUrl(routerOptions);
      } else {
        await router.pushUrl(routerOptions);
        this.backStackDepth++;
      }

      this.currentRoute = route;
      this.trackNavigation(route);
      this.notifySubscribers(route);

      return { success: true };
    } catch (error) {
      this.logError(`Navigation failed: ${error}`);
      return { success: false, error: String(error) };
    }
  }

  async back(): Promise<NavigationResult> {
    this.log('Navigating back');

    try {
      await router.back();
      this.backStackDepth = Math.max(0, this.backStackDepth - 1);
      return { success: true };
    } catch (error) {
      this.logError(`Back navigation failed: ${error}`);
      return { success: false, error: String(error) };
    }
  }

  async backTo(routeType: RouteType): Promise<NavigationResult> {
    this.log(`Navigating back to: ${routeType}`);

    try {
      // Get the path for the route type
      const path = this.getPathForRouteType(routeType);
      if (!path) {
        return { success: false, error: `Unknown route type: ${routeType}` };
      }

      await router.back({ url: path });
      return { success: true };
    } catch (error) {
      this.logError(`Back to navigation failed: ${error}`);
      return { success: false, error: String(error) };
    }
  }

  async navigateAndClear(route: AppRoute): Promise<NavigationResult> {
    return this.navigate(route, { clearStack: true });
  }

  async replace(route: AppRoute): Promise<NavigationResult> {
    return this.navigate(route, { replace: true });
  }

  canGoBack(): boolean {
    return this.backStackDepth > 0;
  }

  getCurrentRoute(): AppRoute | undefined {
    return this.currentRoute;
  }

  subscribe(callback: NavigationCallback): () => void {
    this.callbacks.add(callback);
    return () => this.callbacks.delete(callback);
  }

  @preDestroy()
  destroy(): void {
    this.callbacks.clear();
  }

  // ===== Convenience Methods =====

  /** Navigate to user list */
  async toUserList(): Promise<NavigationResult> {
    return this.navigate(Routes.userList());
  }

  /** Navigate to user detail */
  async toUserDetail(userId: number): Promise<NavigationResult> {
    return this.navigate(Routes.userDetail(userId));
  }

  /** Navigate to create user */
  async toCreateUser(): Promise<NavigationResult> {
    return this.navigate(Routes.createUser());
  }

  /** Navigate to edit user */
  async toEditUser(userId: number): Promise<NavigationResult> {
    return this.navigate(Routes.editUser(userId));
  }

  // ===== Private Helpers =====

  private extractParams(route: AppRoute): Record<string, Object> {
    if (route instanceof UserDetailRoute) {
      return { userId: route.params.userId };
    }
    if (route instanceof EditUserRoute) {
      return { userId: route.params.userId };
    }
    return {};
  }

  private getPathForRouteType(routeType: RouteType): string | undefined {
    switch (routeType) {
      case 'UserList':
        return 'pages/UserListPage';
      case 'UserDetail':
        return 'pages/UserDetailPage';
      case 'CreateUser':
        return 'pages/CreateUserPage';
      case 'EditUser':
        return 'pages/EditUserPage';
      default:
        return undefined;
    }
  }

  private trackNavigation(route: AppRoute): void {
    if (this.analytics) {
      const screenName = this.getScreenNameForRoute(route);
      this.analytics.trackScreen(screenName, route.type);
    }
  }

  private getScreenNameForRoute(route: AppRoute): string {
    switch (route.type) {
      case 'UserList':
        return 'User List';
      case 'UserDetail':
        return 'User Detail';
      case 'CreateUser':
        return 'Create User';
      case 'EditUser':
        return 'Edit User';
      default:
        return 'Unknown';
    }
  }

  private notifySubscribers(route: AppRoute): void {
    this.callbacks.forEach(callback => {
      try {
        callback(route);
      } catch (error) {
        this.logError(`Error in navigation callback: ${error}`);
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

// ===== Navigation Extensions =====

/**
 * Navigation parameter extractor for pages
 * Use in aboutToAppear() to get typed parameters
 */
export class NavParams {
  /**
   * Gets userId from navigation parameters
   */
  static getUserId(): number | undefined {
    try {
      const params = router.getParams() as Record<string, Object> | undefined;
      if (params && 'userId' in params) {
        const userId = params['userId'];
        if (typeof userId === 'number') {
          return userId;
        }
        if (typeof userId === 'string') {
          return parseInt(userId, 10);
        }
      }
    } catch {
      // Ignore errors
    }
    return undefined;
  }

  /**
   * Gets all navigation parameters
   */
  static getAll<T extends Record<string, Object>>(): T | undefined {
    try {
      return router.getParams() as T | undefined;
    } catch {
      return undefined;
    }
  }

  /**
   * Gets a typed parameter by key
   */
  static get<T>(key: string, defaultValue?: T): T | undefined {
    try {
      const params = router.getParams() as Record<string, Object> | undefined;
      if (params && key in params) {
        return params[key] as T;
      }
    } catch {
      // Ignore errors
    }
    return defaultValue;
  }
}
