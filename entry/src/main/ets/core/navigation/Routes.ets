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
  constructor(
    public readonly userId: number
  ) {}

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
  constructor(
    public readonly userId: number
  ) {}

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
 * User List Route (Home)
 */
export class UserListRoute implements Route<EmptyParams> {
  readonly type: RouteType = 'UserList';
  readonly path = 'pages/UserListPage';
  readonly params = new EmptyParams();

  get url(): string {
    return this.path;
  }
}

/**
 * User Detail Route
 */
export class UserDetailRoute implements Route<UserDetailParams> {
  readonly type: RouteType = 'UserDetail';
  readonly path = 'pages/UserDetailPage';

  constructor(public readonly params: UserDetailParams) {}

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
  readonly path = 'pages/CreateUserPage';
  readonly params = new EmptyParams();

  get url(): string {
    return this.path;
  }
}

/**
 * Edit User Route
 */
export class EditUserRoute implements Route<EditUserParams> {
  readonly type: RouteType = 'EditUser';
  readonly path = 'pages/EditUserPage';

  constructor(public readonly params: EditUserParams) {}

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
  | UserListRoute
  | UserDetailRoute
  | CreateUserRoute
  | EditUserRoute;

// ===== Route Factory =====

/**
 * Type-safe route factory
 * Provides compile-time checking for route creation
 */
export const Routes = {
  /** Navigate to user list (home) */
  userList(): UserListRoute {
    return new UserListRoute();
  },

  /** Navigate to user detail */
  userDetail(userId: number): UserDetailRoute {
    return UserDetailRoute.create(userId);
  },

  /** Navigate to create user */
  createUser(): CreateUserRoute {
    return new CreateUserRoute();
  },

  /** Navigate to edit user */
  editUser(userId: number): EditUserRoute {
    return EditUserRoute.create(userId);
  },

  /** Parse route from URL path */
  fromPath(path: string, params?: Record<string, string>): AppRoute | undefined {
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
} as const;

// ===== Route Type Guards =====

/**
 * Type guard for UserListRoute
 */
export function isUserListRoute(route: AppRoute): route is UserListRoute {
  return route.type === 'UserList';
}

/**
 * Type guard for UserDetailRoute
 */
export function isUserDetailRoute(route: AppRoute): route is UserDetailRoute {
  return route.type === 'UserDetail';
}

/**
 * Type guard for CreateUserRoute
 */
export function isCreateUserRoute(route: AppRoute): route is CreateUserRoute {
  return route.type === 'CreateUser';
}

/**
 * Type guard for EditUserRoute
 */
export function isEditUserRoute(route: AppRoute): route is EditUserRoute {
  return route.type === 'EditUser';
}
