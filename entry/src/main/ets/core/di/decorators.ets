/**
 * Dependency Injection Decorators
 * InversifyJS-style decorators for ArkTS
 *
 * Note: ArkTS has limited reflection capabilities compared to TypeScript,
 * so we use a metadata registry approach instead of reflect-metadata.
 */

import {
  ServiceIdentifier,
  InjectableMetadata,
  PropertyInjectionMetadata,
  INJECTABLE_METADATA_KEY,
  PROPERTY_INJECTION_KEY
} from './types';

/**
 * Global metadata registry for injectable classes
 * Maps class constructors to their injection metadata
 */
const injectableRegistry = new Map<Object, InjectableMetadata>();

/**
 * Global metadata registry for property injections
 * Maps class constructors to their property injection metadata
 */
const propertyInjectionRegistry = new Map<Object, PropertyInjectionMetadata[]>();

/**
 * @injectable decorator
 * Marks a class as available for dependency injection.
 *
 * Usage:
 * ```
 * @injectable()
 * class UserService {
 *   constructor(private repo: IUserRepository) {}
 * }
 * ```
 */
export function injectable(): ClassDecorator {
  return <T extends Function>(target: T): T => {
    // Initialize metadata if not exists
    if (!injectableRegistry.has(target)) {
      injectableRegistry.set(target, {
        dependencies: [],
        parameterIndices: []
      });
    }
    return target;
  };
}

/**
 * @inject decorator for constructor parameters
 * Specifies the service identifier for a dependency.
 *
 * Usage:
 * ```
 * @injectable()
 * class UserService {
 *   constructor(
 *     @inject(TYPES.UserRepository) private repo: IUserRepository,
 *     @inject(TYPES.Logger) private logger: ILogger
 *   ) {}
 * }
 * ```
 */
export function inject(serviceIdentifier: ServiceIdentifier): ParameterDecorator {
  const decorator = (target: Object, propertyKey: string | undefined, parameterIndex: number): void => {
    // Get the constructor (target is prototype for instance methods)
    const constructor = propertyKey === undefined ? target : target.constructor;

    // Get or create metadata
    let metadata = injectableRegistry.get(constructor);
    if (!metadata) {
      metadata = {
        dependencies: [],
        parameterIndices: []
      };
      injectableRegistry.set(constructor, metadata);
    }

    // Store dependency at the correct index
    metadata.dependencies[parameterIndex] = serviceIdentifier;
    metadata.parameterIndices.push(parameterIndex);
  };
  return decorator as ParameterDecorator;
}

/**
 * @injectProperty decorator for property injection
 * Injects a dependency into a class property.
 *
 * Usage:
 * ```
 * @injectable()
 * class UserService {
 *   @injectProperty(TYPES.Logger)
 *   private logger!: ILogger;
 * }
 * ```
 */
export function injectProperty(serviceIdentifier: ServiceIdentifier): PropertyDecorator {
  const decorator = (target: Object, propertyKey: string): void => {
    const constructor = target.constructor;

    // Get or create property injection metadata
    let injections = propertyInjectionRegistry.get(constructor);
    if (!injections) {
      injections = [];
      propertyInjectionRegistry.set(constructor, injections);
    }

    injections.push({
      propertyKey: String(propertyKey),
      identifier: serviceIdentifier
    });
  };
  return decorator as PropertyDecorator;
}

/**
 * @named decorator for named bindings
 * Used to distinguish between multiple bindings of the same type.
 *
 * Usage:
 * ```
 * constructor(
 *   @inject(TYPES.Logger) @named('file') private fileLogger: ILogger,
 *   @inject(TYPES.Logger) @named('console') private consoleLogger: ILogger
 * ) {}
 * ```
 */
export function named(name: string): ParameterDecorator {
  const decorator = (_target: Object, _propertyKey: string | undefined, _parameterIndex: number): void => {
    // Store named binding info - can be extended for named resolution
    // For now, this is a marker decorator
  };
  return decorator as ParameterDecorator;
}

/**
 * @optional decorator for optional dependencies
 * Allows a dependency to be undefined if not bound.
 *
 * Usage:
 * ```
 * constructor(
 *   @inject(TYPES.Analytics) @optional() private analytics?: IAnalytics
 * ) {}
 * ```
 */
const optionalParams = new Map<Object, Set<number>>();

export function optional(): ParameterDecorator {
  const decorator = (target: Object, propertyKey: string | undefined, parameterIndex: number): void => {
    const constructor = propertyKey === undefined ? target : target.constructor;

    let optionalSet = optionalParams.get(constructor);
    if (!optionalSet) {
      optionalSet = new Set();
      optionalParams.set(constructor, optionalSet);
    }
    optionalSet.add(parameterIndex);
  };
  return decorator as ParameterDecorator;
}

/**
 * @multiInject decorator for injecting all bindings of a type
 * Returns an array of all bound instances.
 *
 * Usage:
 * ```
 * constructor(
 *   @multiInject(TYPES.Plugin) private plugins: IPlugin[]
 * ) {}
 * ```
 */
const multiInjectParams = new Map<Object, Map<number, ServiceIdentifier>>();

export function multiInject(serviceIdentifier: ServiceIdentifier): ParameterDecorator {
  const decorator = (target: Object, propertyKey: string | undefined, parameterIndex: number): void => {
    const constructor = propertyKey === undefined ? target : target.constructor;

    let multiMap = multiInjectParams.get(constructor);
    if (!multiMap) {
      multiMap = new Map();
      multiInjectParams.set(constructor, multiMap);
    }
    multiMap.set(parameterIndex, serviceIdentifier);
  };
  return decorator as ParameterDecorator;
}

/**
 * @postConstruct decorator for initialization after injection
 * Method is called after all dependencies are injected.
 *
 * Usage:
 * ```
 * @injectable()
 * class UserService {
 *   @postConstruct()
 *   initialize(): void {
 *     // Called after constructor and property injection
 *   }
 * }
 * ```
 */
const postConstructMethods = new Map<Object, string>();

export function postConstruct(): MethodDecorator {
  const decorator = (target: Object, propertyKey: string, _descriptor: PropertyDescriptor): void => {
    postConstructMethods.set(target.constructor, String(propertyKey));
  };
  return decorator as MethodDecorator;
}

/**
 * @preDestroy decorator for cleanup before disposal
 * Method is called when container disposes the instance.
 *
 * Usage:
 * ```
 * @injectable()
 * class UserService {
 *   @preDestroy()
 *   cleanup(): void {
 *     // Called before instance is disposed
 *   }
 * }
 * ```
 */
const preDestroyMethods = new Map<Object, string>();

export function preDestroy(): MethodDecorator {
  const decorator = (target: Object, propertyKey: string, _descriptor: PropertyDescriptor): void => {
    preDestroyMethods.set(target.constructor, String(propertyKey));
  };
  return decorator as MethodDecorator;
}

// ===== Metadata Access Functions =====

/**
 * Gets injectable metadata for a class
 */
export function getInjectableMetadata(target: Object): InjectableMetadata | undefined {
  return injectableRegistry.get(target);
}

/**
 * Gets property injection metadata for a class
 */
export function getPropertyInjections(target: Object): PropertyInjectionMetadata[] {
  return propertyInjectionRegistry.get(target) || [];
}

/**
 * Checks if a parameter is optional
 */
export function isOptionalParam(target: Object, paramIndex: number): boolean {
  const optionalSet = optionalParams.get(target);
  return optionalSet?.has(paramIndex) || false;
}

/**
 * Gets multi-inject identifier for a parameter
 */
export function getMultiInjectIdentifier(target: Object, paramIndex: number): ServiceIdentifier | undefined {
  const multiMap = multiInjectParams.get(target);
  return multiMap?.get(paramIndex);
}

/**
 * Gets post-construct method name for a class
 */
export function getPostConstructMethod(target: Object): string | undefined {
  return postConstructMethods.get(target);
}

/**
 * Gets pre-destroy method name for a class
 */
export function getPreDestroyMethod(target: Object): string | undefined {
  return preDestroyMethods.get(target);
}

/**
 * Clears all metadata (useful for testing)
 */
export function clearAllMetadata(): void {
  injectableRegistry.clear();
  propertyInjectionRegistry.clear();
  optionalParams.clear();
  multiInjectParams.clear();
  postConstructMethods.clear();
  preDestroyMethods.clear();
}
