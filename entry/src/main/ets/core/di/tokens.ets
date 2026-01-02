/**
 * Dependency Injection Tokens
 * Service identifiers for all injectable services
 *
 * Using string identifiers for ArkTS compatibility
 * (ArkTS does not support Symbol API or "as const")
 */

/**
 * Service tokens interface for type safety
 */
export interface ServiceTokens {
  // Core Services
  ContextProvider: string;
  Logger: string;
  NetworkMonitor: string;
  SyncManager: string;
  AnalyticsService: string;

  // Data Layer
  UserRepository: string;
  UserApiService: string;
  UserLocalDataSource: string;

  // Cache
  PageCache: string;
  UserCache: string;

  // Domain Services
  UserValidator: string;
  UserService: string;

  // Presentation - ViewModels
  HomeViewModel: string;
  UserListViewModel: string;
  UserDetailViewModel: string;
  UserFormViewModel: string;

  // Navigation
  Navigator: string;

  // Infrastructure
  HttpClient: string;
  PreferencesStorage: string;
  SecureStorage: string;
  WorkScheduler: string;
}

/**
 * Service tokens for dependency injection
 */
class ServiceTokensImpl implements ServiceTokens {
  // Core Services
  readonly ContextProvider: string = 'ContextProvider';
  readonly Logger: string = 'Logger';
  readonly NetworkMonitor: string = 'NetworkMonitor';
  readonly SyncManager: string = 'SyncManager';
  readonly AnalyticsService: string = 'AnalyticsService';

  // Data Layer
  readonly UserRepository: string = 'UserRepository';
  readonly UserApiService: string = 'UserApiService';
  readonly UserLocalDataSource: string = 'UserLocalDataSource';

  // Cache
  readonly PageCache: string = 'PageCache';
  readonly UserCache: string = 'UserCache';

  // Domain Services
  readonly UserValidator: string = 'UserValidator';
  readonly UserService: string = 'UserService';

  // Presentation - ViewModels
  readonly HomeViewModel: string = 'HomeViewModel';
  readonly UserListViewModel: string = 'UserListViewModel';
  readonly UserDetailViewModel: string = 'UserDetailViewModel';
  readonly UserFormViewModel: string = 'UserFormViewModel';

  // Navigation
  readonly Navigator: string = 'Navigator';

  // Infrastructure
  readonly HttpClient: string = 'HttpClient';
  readonly PreferencesStorage: string = 'PreferencesStorage';
  readonly SecureStorage: string = 'SecureStorage';
  readonly WorkScheduler: string = 'WorkScheduler';
}

export const TYPES: ServiceTokens = new ServiceTokensImpl();

/**
 * Named binding identifiers interface
 */
export interface NamedTokens {
  FileLogger: string;
  ConsoleLogger: string;
  RemoteLogger: string;
  MemoryCache: string;
  DiskCache: string;
  UserStorage: string;
  SettingsStorage: string;
}

class NamedTokensImpl implements NamedTokens {
  readonly FileLogger: string = 'FileLogger';
  readonly ConsoleLogger: string = 'ConsoleLogger';
  readonly RemoteLogger: string = 'RemoteLogger';
  readonly MemoryCache: string = 'MemoryCache';
  readonly DiskCache: string = 'DiskCache';
  readonly UserStorage: string = 'UserStorage';
  readonly SettingsStorage: string = 'SettingsStorage';
}

export const NAMED: NamedTokens = new NamedTokensImpl();

/**
 * Tag identifiers interface
 */
export interface TagTokens {
  Development: string;
  Production: string;
  Testing: string;
  Mock: string;
}

class TagTokensImpl implements TagTokens {
  readonly Development: string = 'development';
  readonly Production: string = 'production';
  readonly Testing: string = 'testing';
  readonly Mock: string = 'mock';
}

export const TAGS: TagTokens = new TagTokensImpl();

/**
 * Module identifiers interface
 */
export interface ModuleTokens {
  Core: string;
  Data: string;
  Domain: string;
  Presentation: string;
  Testing: string;
}

class ModuleTokensImpl implements ModuleTokens {
  readonly Core: string = 'CoreModule';
  readonly Data: string = 'DataModule';
  readonly Domain: string = 'DomainModule';
  readonly Presentation: string = 'PresentationModule';
  readonly Testing: string = 'TestingModule';
}

export const MODULES: ModuleTokens = new ModuleTokensImpl();
