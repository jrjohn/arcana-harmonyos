/**
 * Navigation Module
 * Type-safe navigation for HarmonyOS ArkTS
 *
 * Usage:
 * ```
 * // Import routes and navigator
 * import { Routes, Navigator, NavParams } from './core/navigation';
 *
 * // Navigate with type safety
 * navigator.navigate(Routes.userDetail(123));
 * navigator.navigate(Routes.createUser());
 *
 * // Or use convenience methods
 * navigator.toUserDetail(123);
 * navigator.toCreateUser();
 *
 * // In pages, extract typed parameters
 * aboutToAppear() {
 *   const userId = NavParams.getUserId();
 *   if (userId) {
 *     this.loadUser(userId);
 *   }
 * }
 * ```
 */

// Routes
export {
  RouteParams,
  EmptyParams,
  UserDetailParams,
  EditUserParams,
  RouteType,
  Route,
  UserListRoute,
  UserDetailRoute,
  CreateUserRoute,
  EditUserRoute,
  AppRoute,
  Routes,
  isUserListRoute,
  isUserDetailRoute,
  isCreateUserRoute,
  isEditUserRoute
} from './Routes';

// Navigator
export {
  NavigationResult,
  NavigationOptions,
  NavigationCallback,
  INavigator,
  Navigator,
  NavParams
} from './Navigator';
