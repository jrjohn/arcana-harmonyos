/**
 * Dependency Injection Module
 * InversifyJS-style DI container for ArkTS/HarmonyOS
 *
 * Usage:
 * ```
 * // 1. Define interfaces in interfaces.ets
 * // 2. Define tokens in tokens.ets
 * // 3. Create injectable services with decorators
 *
 * @injectable()
 * class MyService implements IMyService {
 *   constructor(
 *     @inject(TYPES.Logger) private logger: ILogger
 *   ) {}
 * }
 *
 * // 4. Bind services in ContainerInitializer or modules
 * container.bind<IMyService>(TYPES.MyService)
 *   .to(MyService)
 *   .inSingletonScope();
 *
 * // 5. Resolve services
 * const myService = container.get<IMyService>(TYPES.MyService);
 * ```
 */

// Types and interfaces
export {
  ServiceIdentifier,
  BindingScope,
  Binding,
  Factory,
  AsyncFactory,
  IContainer,
  IBindingTo,
  IBindingIn,
  IBindingWhen,
  IBindingInWhen,
  IRequest,
  IDisposable,
  InjectableMetadata,
  PropertyInjectionMetadata,
  IContainerModule,
  IAsyncContainerModule,
  INJECTABLE_METADATA_KEY,
  PROPERTY_INJECTION_KEY
} from './types';

// Container
export { Container, createContainer } from './Container';

// Decorators
export {
  injectable,
  inject,
  injectProperty,
  named,
  optional,
  multiInject,
  postConstruct,
  preDestroy,
  getInjectableMetadata,
  getPropertyInjections,
  isOptionalParam,
  getMultiInjectIdentifier,
  getPostConstructMethod,
  getPreDestroyMethod,
  clearAllMetadata
} from './decorators';

// Tokens
export { TYPES, NAMED, TAGS, MODULES } from './tokens';

// Service interfaces
export {
  INetworkMonitor,
  ILogger,
  ISyncManager,
  IAnalyticsService,
  IUserRepositoryService,
  IUserApiService,
  IUserLocalDataSource,
  IContextProvider,
  ICacheManager
} from './interfaces';

// Container initializer and global access
export {
  ContainerInitializer,
  setGlobalContainer,
  getGlobalContainer,
  resolve,
  getLogger,
  getNetworkMonitor,
  getSyncManager,
  getAnalyticsService,
  getUserRepository
} from './ContainerInitializer';
