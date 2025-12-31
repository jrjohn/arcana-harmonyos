/**
 * Dependency Injection Tokens
 * Service identifiers for all injectable services
 *
 * Using symbols for type-safe dependency identification
 * Similar to InversifyJS TYPES pattern
 */

/**
 * Service tokens for dependency injection
 *
 * Usage:
 * ```
 * // Binding
 * container.bind(TYPES.Logger).to(LoggerImpl).inSingletonScope();
 *
 * // Injection
 * @injectable()
 * class MyService {
 *   constructor(@inject(TYPES.Logger) private logger: ILogger) {}
 * }
 *
 * // Resolution
 * const logger = container.get<ILogger>(TYPES.Logger);
 * ```
 */
export const TYPES = {
  // ===== Core Services =====

  /** Application context provider */
  ContextProvider: Symbol.for('ContextProvider'),

  /** Logging service */
  Logger: Symbol.for('Logger'),

  /** Network monitoring service */
  NetworkMonitor: Symbol.for('NetworkMonitor'),

  /** Synchronization manager */
  SyncManager: Symbol.for('SyncManager'),

  /** Analytics service */
  AnalyticsService: Symbol.for('AnalyticsService'),

  // ===== Data Layer =====

  /** User repository (main data access) */
  UserRepository: Symbol.for('UserRepository'),

  /** User API service (network layer) */
  UserApiService: Symbol.for('UserApiService'),

  /** User local data source (persistence layer) */
  UserLocalDataSource: Symbol.for('UserLocalDataSource'),

  // ===== Cache =====

  /** Page cache for paginated results */
  PageCache: Symbol.for('PageCache'),

  /** User cache for individual users */
  UserCache: Symbol.for('UserCache'),

  // ===== Domain Services =====

  /** User validation service */
  UserValidator: Symbol.for('UserValidator'),

  /** User service (business logic) */
  UserService: Symbol.for('UserService'),

  // ===== Presentation =====

  /** User list view model */
  UserListViewModel: Symbol.for('UserListViewModel'),

  /** User detail view model */
  UserDetailViewModel: Symbol.for('UserDetailViewModel'),

  /** User form view model */
  UserFormViewModel: Symbol.for('UserFormViewModel'),

  // ===== Navigation =====

  /** Type-safe navigator */
  Navigator: Symbol.for('Navigator'),

  // ===== Infrastructure =====

  /** HTTP client */
  HttpClient: Symbol.for('HttpClient'),

  /** Preferences storage */
  PreferencesStorage: Symbol.for('PreferencesStorage'),

  /** Secure storage (encrypted) */
  SecureStorage: Symbol.for('SecureStorage'),

  /** Work scheduler for background tasks */
  WorkScheduler: Symbol.for('WorkScheduler'),
} as const;

/**
 * Type helper for extracting token type
 */
export type TokenType = typeof TYPES;
export type TokenKey = keyof TokenType;
export type TokenValue = TokenType[TokenKey];

/**
 * Named binding identifiers
 * Used with @named decorator for multiple bindings of same type
 */
export const NAMED = {
  // Logger variants
  FileLogger: 'FileLogger',
  ConsoleLogger: 'ConsoleLogger',
  RemoteLogger: 'RemoteLogger',

  // Cache variants
  MemoryCache: 'MemoryCache',
  DiskCache: 'DiskCache',

  // Storage variants
  UserStorage: 'UserStorage',
  SettingsStorage: 'SettingsStorage',
} as const;

/**
 * Tag identifiers for conditional bindings
 * Used with @tagged decorator
 */
export const TAGS = {
  /** Development environment */
  Development: 'development',

  /** Production environment */
  Production: 'production',

  /** Testing environment */
  Testing: 'testing',

  /** Mock implementation */
  Mock: 'mock',
} as const;

/**
 * Module identifiers for container modules
 */
export const MODULES = {
  /** Core services module */
  Core: 'CoreModule',

  /** Data layer module */
  Data: 'DataModule',

  /** Domain layer module */
  Domain: 'DomainModule',

  /** Presentation layer module */
  Presentation: 'PresentationModule',

  /** Testing module (mocks) */
  Testing: 'TestingModule',
} as const;
