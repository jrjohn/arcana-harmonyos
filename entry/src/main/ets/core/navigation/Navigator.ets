/**
 * Type-Safe Navigator
 * Handles all navigation operations with compile-time type safety
 *
 * Uses NavPathStack for navigation (recommended over deprecated router API)
 */

import { injectable, preDestroy } from '../di/decorators';
import { IAnalyticsService, ILogger } from '../di/interfaces';
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
  /** Set the NavPathStack instance */
  setNavPathStack(navPathStack: NavPathStack): void;

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
 * Navigation parameters for pages
 */
export class NavPageParam {
  userId: number;

  constructor(userId: number) {
    this.userId = userId;
  }
}

/**
 * Navigator implementation using NavPathStack
 */
@injectable()
export class Navigator implements INavigator {
  private logger?: ILogger;
  private analytics?: IAnalyticsService;
  private callbacks: Set<NavigationCallback> = new Set();
  private currentRoute?: AppRoute;
  private navPathStack?: NavPathStack;

  constructor() {}

  /**
   * Sets the NavPathStack instance from the Navigation component
   */
  setNavPathStack(navPathStack: NavPathStack): void {
    this.navPathStack = navPathStack;
  }

  /**
   * Sets dependencies (for manual injection)
   */
  setDependencies(logger: ILogger, analytics: IAnalyticsService): void {
    this.logger = logger;
    this.analytics = analytics;
  }

  async navigate(route: AppRoute, options: NavigationOptions = {}): Promise<NavigationResult> {
    this.log(`Navigating to: ${route.type} (${route.url})`);

    if (!this.navPathStack) {
      this.logError('NavPathStack not set. Call setNavPathStack first.');
      return { success: false, error: 'NavPathStack not initialized' };
    }

    try {
      const pageName = this.getPageName(route.type);
      const param = this.extractParam(route);

      if (options.clearStack) {
        this.navPathStack.clear();
      }

      if (options.replace) {
        this.navPathStack.replacePath({ name: pageName, param: param });
      } else {
        this.navPathStack.pushPath({ name: pageName, param: param });
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

    if (!this.navPathStack) {
      return { success: false, error: 'NavPathStack not initialized' };
    }

    try {
      this.navPathStack.pop();
      return { success: true };
    } catch (error) {
      this.logError(`Back navigation failed: ${error}`);
      return { success: false, error: String(error) };
    }
  }

  async backTo(routeType: RouteType): Promise<NavigationResult> {
    this.log(`Navigating back to: ${routeType}`);

    if (!this.navPathStack) {
      return { success: false, error: 'NavPathStack not initialized' };
    }

    try {
      const pageName = this.getPageName(routeType);
      this.navPathStack.popToName(pageName);
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
    if (!this.navPathStack) {
      return false;
    }
    return this.navPathStack.size() > 1;
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

  private getPageName(routeType: RouteType): string {
    switch (routeType) {
      case 'Main':
        return 'MainPage';
      case 'Home':
        return 'HomePage';
      case 'UserList':
        return 'UserListPage';
      case 'UserDetail':
        return 'UserDetailPage';
      case 'CreateUser':
        return 'CreateUserPage';
      case 'EditUser':
        return 'EditUserPage';
      default:
        return 'HomePage';
    }
  }

  private extractParam(route: AppRoute): NavPageParam | undefined {
    if (route instanceof UserDetailRoute) {
      return new NavPageParam(route.params.userId);
    }
    if (route instanceof EditUserRoute) {
      return new NavPageParam(route.params.userId);
    }
    return undefined;
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
 * Navigation parameter extractor for pages using NavPathStack
 * Use in onReady callback of NavDestination to get typed parameters
 */
export class NavParams {
  /**
   * Gets userId from NavPageParam
   */
  static getUserId(param: Object | undefined): number | undefined {
    if (param instanceof NavPageParam) {
      return param.userId;
    }
    return undefined;
  }

  /**
   * Extracts NavPageParam from route param
   */
  static getPageParam(param: Object | undefined): NavPageParam | undefined {
    if (param instanceof NavPageParam) {
      return param;
    }
    return undefined;
  }
}
