/**
 * Type-Safe Navigation Routes
 * Defines all application routes with compile-time type safety
 *
 * Pattern inspired by Jetpack Compose Navigation Safe Args
 * but adapted for HarmonyOS ArkTS with stronger typing
 */

// ===== Route Parameter Types =====

/**
 * Base interface for all route parameters
 */
export interface RouteParams {
  /** Serializes params to URL query string */
  toQueryString(): string;
}

/**
 * Empty params for routes without arguments
 */
export class EmptyParams implements RouteParams {
  toQueryString(): string {
    return '';
  }
}

/**
 * User detail route parameters
 */
export class UserDetailParams implements RouteParams {
  readonly userId: number;

  constructor(userId: number) {
    this.userId = userId;
  }

  toQueryString(): string {
    return `?userId=${this.userId}`;
  }

  static fromRecord(record: Record<string, string>): UserDetailParams {
    const userId = parseInt(record['userId'] || '0', 10);
    if (isNaN(userId) || userId <= 0) {
      throw new Error(`Invalid userId: ${record['userId']}`);
    }
    return new UserDetailParams(userId);
  }
}

/**
 * Edit user route parameters
 */
export class EditUserParams implements RouteParams {
  readonly userId: number;

  constructor(userId: number) {
    this.userId = userId;
  }

  toQueryString(): string {
    return `?userId=${this.userId}`;
  }

  static fromRecord(record: Record<string, string>): EditUserParams {
    const userId = parseInt(record['userId'] || '0', 10);
    if (isNaN(userId) || userId <= 0) {
      throw new Error(`Invalid userId: ${record['userId']}`);
    }
    return new EditUserParams(userId);
  }
}

// ===== Route Definitions =====

/**
 * Route type discriminator
 */
export type RouteType =
  | 'Main'
  | 'Home'
  | 'UserList'
  | 'UserDetail'
  | 'CreateUser'
  | 'EditUser';

/**
 * Base route interface
 */
export interface Route<P extends RouteParams = EmptyParams> {
  /** Route type for discrimination */
  readonly type: RouteType;
  /** Page URL path */
  readonly path: string;
  /** Route parameters */
  readonly params: P;
  /** Full URL including params */
  readonly url: string;
}

/**
 * Main Route (Entry point with bottom tabs)
 */
export class MainRoute implements Route<EmptyParams> {
  readonly type: RouteType = 'Main';
  readonly path: string = 'pages/MainPage';
  readonly params: EmptyParams = new EmptyParams();

  get url(): string {
    return this.path;
  }
}

/**
 * Home Route (Home tab content)
 */
export class HomeRoute implements Route<EmptyParams> {
  readonly type: RouteType = 'Home';
  readonly path: string = 'pages/HomePage';
  readonly params: EmptyParams = new EmptyParams();

  get url(): string {
    return this.path;
  }
}

/**
 * User List Route
 */
export class UserListRoute implements Route<EmptyParams> {
  readonly type: RouteType = 'UserList';
  readonly path: string = 'pages/UserListPage';
  readonly params: EmptyParams = new EmptyParams();

  get url(): string {
    return this.path;
  }
}

/**
 * User Detail Route
 */
export class UserDetailRoute implements Route<UserDetailParams> {
  readonly type: RouteType = 'UserDetail';
  readonly path: string = 'pages/UserDetailPage';
  readonly params: UserDetailParams;

  constructor(params: UserDetailParams) {
    this.params = params;
  }

  get url(): string {
    return this.path + this.params.toQueryString();
  }

  static create(userId: number): UserDetailRoute {
    return new UserDetailRoute(new UserDetailParams(userId));
  }
}

/**
 * Create User Route
 */
export class CreateUserRoute implements Route<EmptyParams> {
  readonly type: RouteType = 'CreateUser';
  readonly path: string = 'pages/CreateUserPage';
  readonly params: EmptyParams = new EmptyParams();

  get url(): string {
    return this.path;
  }
}

/**
 * Edit User Route
 */
export class EditUserRoute implements Route<EditUserParams> {
  readonly type: RouteType = 'EditUser';
  readonly path: string = 'pages/EditUserPage';
  readonly params: EditUserParams;

  constructor(params: EditUserParams) {
    this.params = params;
  }

  get url(): string {
    return this.path + this.params.toQueryString();
  }

  static create(userId: number): EditUserRoute {
    return new EditUserRoute(new EditUserParams(userId));
  }
}

// ===== Route Union Type =====

/**
 * Union of all routes for type-safe navigation
 */
export type AppRoute =
  | MainRoute
  | HomeRoute
  | UserListRoute
  | UserDetailRoute
  | CreateUserRoute
  | EditUserRoute;

// ===== Route Factory =====

/**
 * Route factory interface
 */
interface RouteFactory {
  main(): MainRoute;
  home(): HomeRoute;
  userList(): UserListRoute;
  userDetail(userId: number): UserDetailRoute;
  createUser(): CreateUserRoute;
  editUser(userId: number): EditUserRoute;
  fromPath(path: string, params?: Record<string, string>): AppRoute | undefined;
}

/**
 * Type-safe route factory implementation
 */
class RouteFactoryImpl implements RouteFactory {
  /** Navigate to main (entry with tabs) */
  main(): MainRoute {
    return new MainRoute();
  }

  /** Navigate to home */
  home(): HomeRoute {
    return new HomeRoute();
  }

  /** Navigate to user list */
  userList(): UserListRoute {
    return new UserListRoute();
  }

  /** Navigate to user detail */
  userDetail(userId: number): UserDetailRoute {
    return UserDetailRoute.create(userId);
  }

  /** Navigate to create user */
  createUser(): CreateUserRoute {
    return new CreateUserRoute();
  }

  /** Navigate to edit user */
  editUser(userId: number): EditUserRoute {
    return EditUserRoute.create(userId);
  }

  /** Parse route from URL path */
  fromPath(path: string, params?: Record<string, string>): AppRoute | undefined {
    if (path.includes('MainPage')) {
      return new MainRoute();
    }
    if (path.includes('HomePage')) {
      return new HomeRoute();
    }
    if (path.includes('UserListPage')) {
      return new UserListRoute();
    }
    if (path.includes('UserDetailPage') && params) {
      return new UserDetailRoute(UserDetailParams.fromRecord(params));
    }
    if (path.includes('CreateUserPage')) {
      return new CreateUserRoute();
    }
    if (path.includes('EditUserPage') && params) {
      return new EditUserRoute(EditUserParams.fromRecord(params));
    }
    return undefined;
  }
}

export const Routes: RouteFactory = new RouteFactoryImpl();

// ===== Route Type Guards =====

/**
 * Type guard for MainRoute
 */
export function isMainRoute(route: AppRoute): boolean {
  return route.type === 'Main';
}

/**
 * Type guard for HomeRoute
 */
export function isHomeRoute(route: AppRoute): boolean {
  return route.type === 'Home';
}

/**
 * Type guard for UserListRoute
 */
export function isUserListRoute(route: AppRoute): boolean {
  return route.type === 'UserList';
}

/**
 * Type guard for UserDetailRoute
 */
export function isUserDetailRoute(route: AppRoute): boolean {
  return route.type === 'UserDetail';
}

/**
 * Type guard for CreateUserRoute
 */
export function isCreateUserRoute(route: AppRoute): boolean {
  return route.type === 'CreateUser';
}

/**
 * Type guard for EditUserRoute
 */
export function isEditUserRoute(route: AppRoute): boolean {
  return route.type === 'EditUser';
}

// ===== Screen Names for Analytics =====

/**
 * Maps route types to human-readable screen names
 */
class RouteScreenNamesImpl {
  private screenNames: Map<RouteType, string> = new Map([
    ['Main', 'Main'],
    ['Home', 'Home'],
    ['UserList', 'User List'],
    ['UserDetail', 'User Detail'],
    ['CreateUser', 'Create User'],
    ['EditUser', 'Edit User']
  ]);

  get(routeType: RouteType): string {
    return this.screenNames.get(routeType) || 'Unknown';
  }
}

export const RouteScreenNames = new RouteScreenNamesImpl();
