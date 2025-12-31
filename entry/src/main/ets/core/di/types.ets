/**
 * Dependency Injection Types
 * InversifyJS-style type definitions for ArkTS
 */

/**
 * Service identifier - can be a symbol or string
 * Symbols are preferred for type safety
 */
export type ServiceIdentifier<T = unknown> = symbol | string;

/**
 * Binding scope determines how instances are managed
 */
export enum BindingScope {
  /** New instance created for each resolution */
  TRANSIENT = 'transient',
  /** Single instance shared across all resolutions */
  SINGLETON = 'singleton',
  /** Single instance within a request context */
  REQUEST = 'request'
}

/**
 * Factory function type for creating instances
 */
export type Factory<T> = (container: IContainer) => T;

/**
 * Async factory function type
 */
export type AsyncFactory<T> = (container: IContainer) => Promise<T>;

/**
 * Binding configuration
 */
export interface Binding<T> {
  /** Service identifier */
  identifier: ServiceIdentifier<T>;
  /** Scope for instance management */
  scope: BindingScope;
  /** Factory function to create instance */
  factory?: Factory<T>;
  /** Async factory for services requiring initialization */
  asyncFactory?: AsyncFactory<T>;
  /** Cached singleton instance */
  instance?: T;
  /** Whether the binding has been initialized (for async) */
  initialized: boolean;
  /** Dependencies required by this service */
  dependencies: ServiceIdentifier[];
}

/**
 * Container interface
 */
export interface IContainer {
  /**
   * Binds a service identifier to a factory
   */
  bind<T>(identifier: ServiceIdentifier<T>): IBindingTo<T>;

  /**
   * Resolves a service by identifier
   */
  get<T>(identifier: ServiceIdentifier<T>): T;

  /**
   * Resolves a service asynchronously
   */
  getAsync<T>(identifier: ServiceIdentifier<T>): Promise<T>;

  /**
   * Checks if a binding exists
   */
  isBound(identifier: ServiceIdentifier): boolean;

  /**
   * Unbinds a service
   */
  unbind(identifier: ServiceIdentifier): void;

  /**
   * Rebinds a service (unbind + bind)
   */
  rebind<T>(identifier: ServiceIdentifier<T>): IBindingTo<T>;

  /**
   * Creates a child container with inherited bindings
   */
  createChild(): IContainer;

  /**
   * Gets the parent container if exists
   */
  getParent(): IContainer | undefined;

  /**
   * Disposes all singleton instances that implement IDisposable
   */
  dispose(): Promise<void>;
}

/**
 * Binding configuration fluent API - bind to
 */
export interface IBindingTo<T> {
  /**
   * Binds to a class/constructor
   */
  to(constructor: new (...args: ESObject[]) => T): IBindingInWhen<T>;

  /**
   * Binds to a constant value
   */
  toConstantValue(value: T): IBindingWhen<T>;

  /**
   * Binds to a dynamic value (factory)
   */
  toDynamicValue(factory: Factory<T>): IBindingInWhen<T>;

  /**
   * Binds to an async factory
   */
  toAsyncFactory(factory: AsyncFactory<T>): IBindingInWhen<T>;

  /**
   * Binds to self (same as to with same identifier)
   */
  toSelf(): IBindingInWhen<T>;
}

/**
 * Binding configuration fluent API - scope
 */
export interface IBindingIn<T> {
  /**
   * Singleton scope - one instance shared
   */
  inSingletonScope(): IBindingWhen<T>;

  /**
   * Transient scope - new instance each time
   */
  inTransientScope(): IBindingWhen<T>;

  /**
   * Request scope - one instance per request context
   */
  inRequestScope(): IBindingWhen<T>;
}

/**
 * Binding configuration fluent API - when (conditional)
 */
export interface IBindingWhen<T> {
  /**
   * Applies when condition is met
   */
  when(condition: (request: IRequest) => boolean): void;

  /**
   * No condition (always applies)
   */
  done(): void;
}

/**
 * Combined binding interface
 */
export interface IBindingInWhen<T> extends IBindingIn<T>, IBindingWhen<T> {}

/**
 * Request context for conditional bindings
 */
export interface IRequest {
  /** The service being requested */
  serviceIdentifier: ServiceIdentifier;
  /** Parent request if nested resolution */
  parentRequest?: IRequest;
  /** Target class name if available */
  targetName?: string;
}

/**
 * Disposable interface for cleanup
 */
export interface IDisposable {
  dispose(): void | Promise<void>;
}

/**
 * Injectable metadata stored on classes
 */
export interface InjectableMetadata {
  /** Dependencies to inject (by identifier) */
  dependencies: ServiceIdentifier[];
  /** Parameter indices for injection */
  parameterIndices: number[];
}

/**
 * Injection metadata key
 */
export const INJECTABLE_METADATA_KEY = '__injectable_metadata__';

/**
 * Property injection metadata
 */
export interface PropertyInjectionMetadata {
  propertyKey: string;
  identifier: ServiceIdentifier;
}

/**
 * Property injection metadata key
 */
export const PROPERTY_INJECTION_KEY = '__property_injections__';

/**
 * Module definition for organizing bindings
 */
export interface IContainerModule {
  /** Unique module identifier */
  id: string;
  /** Registry function that binds services */
  registry: (bind: <T>(id: ServiceIdentifier<T>) => IBindingTo<T>) => void;
}

/**
 * Async module for services requiring initialization
 */
export interface IAsyncContainerModule {
  /** Unique module identifier */
  id: string;
  /** Async registry function */
  registry: (bind: <T>(id: ServiceIdentifier<T>) => IBindingTo<T>) => Promise<void>;
}
