/**
 * Dependency Injection Container
 * Simplified IoC container for ArkTS compatibility
 *
 * ArkTS Limitations:
 * - No constructor function types (new (...args) => T)
 * - No Symbol API
 * - No any/unknown types
 *
 * This implementation uses factory functions and constant values only.
 */

import {
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
  IContainerModule,
  IAsyncContainerModule
} from './types';

/**
 * Binding builder for fluent API
 */
class BindingBuilder<T> implements IBindingTo<T>, IBindingInWhen<T> {
  private binding: Binding<T>;
  private container: Container;

  constructor(container: Container, identifier: ServiceIdentifier<T>) {
    this.container = container;
    this.binding = {
      identifier,
      scope: BindingScope.TRANSIENT,
      initialized: false,
      dependencies: []
    };
  }

  /**
   * Binds to a class/constructor (not supported in ArkTS - use toDynamicValue instead)
   */
  to(_constructor: Object): IBindingInWhen<T> {
    throw new Error('Constructor binding not supported in ArkTS. Use toDynamicValue() instead.');
  }

  /**
   * Binds to a constant value
   */
  toConstantValue(value: T): IBindingWhen<T> {
    this.binding.instance = value;
    this.binding.scope = BindingScope.SINGLETON;
    this.binding.initialized = true;
    this.container.registerBinding(this.binding);
    return this;
  }

  /**
   * Binds to a dynamic value (factory function)
   */
  toDynamicValue(factory: Factory<T>): IBindingInWhen<T> {
    this.binding.factory = factory;
    this.container.registerBinding(this.binding);
    return this;
  }

  /**
   * Binds to an async factory
   */
  toAsyncFactory(factory: AsyncFactory<T>): IBindingInWhen<T> {
    this.binding.asyncFactory = factory;
    this.container.registerBinding(this.binding);
    return this;
  }

  /**
   * Binds to self (not supported in ArkTS)
   */
  toSelf(): IBindingInWhen<T> {
    throw new Error('Self binding not supported in ArkTS. Use toDynamicValue() instead.');
  }

  /**
   * Sets singleton scope
   */
  inSingletonScope(): IBindingWhen<T> {
    this.binding.scope = BindingScope.SINGLETON;
    return this;
  }

  /**
   * Sets transient scope
   */
  inTransientScope(): IBindingWhen<T> {
    this.binding.scope = BindingScope.TRANSIENT;
    return this;
  }

  /**
   * Sets request scope
   */
  inRequestScope(): IBindingWhen<T> {
    this.binding.scope = BindingScope.REQUEST;
    return this;
  }

  /**
   * Conditional binding
   */
  when(_condition: (request: IRequest) => boolean): void {
    // Store condition for later evaluation
    // Currently simplified - can be extended
  }

  /**
   * Completes binding configuration
   */
  done(): void {
    // No-op, binding already registered
  }
}

/**
 * Main DI Container
 * Manages service bindings and resolution
 */
export class Container implements IContainer {
  private bindings = new Map<string, Binding<Object>[]>();
  private parent: Container | undefined = undefined;
  private requestScopeInstances = new Map<string, Object>();

  constructor(parent?: Container) {
    this.parent = parent;
  }

  /**
   * Starts binding configuration for a service identifier
   */
  bind<T>(identifier: ServiceIdentifier<T>): IBindingTo<T> {
    return new BindingBuilder<T>(this, identifier);
  }

  /**
   * Registers a binding (called by BindingBuilder)
   */
  registerBinding<T>(binding: Binding<T>): void {
    let bindingList = this.bindings.get(binding.identifier);
    if (!bindingList) {
      bindingList = [];
      this.bindings.set(binding.identifier, bindingList);
    }
    bindingList.push(binding as Binding<Object>);
  }

  /**
   * Resolves a service synchronously
   */
  get<T>(identifier: ServiceIdentifier<T>): T {
    const binding = this.getBinding<T>(identifier);

    if (!binding) {
      if (this.parent) {
        return this.parent.get(identifier);
      }
      throw new Error(`No binding found for: ${identifier}`);
    }

    return this.resolveBinding(binding) as T;
  }

  /**
   * Resolves a service asynchronously
   */
  async getAsync<T>(identifier: ServiceIdentifier<T>): Promise<T> {
    const binding = this.getBinding<T>(identifier);

    if (!binding) {
      if (this.parent) {
        return this.parent.getAsync(identifier);
      }
      throw new Error(`No binding found for: ${identifier}`);
    }

    return this.resolveBindingAsync(binding) as Promise<T>;
  }

  /**
   * Gets all bindings for an identifier (for multi-inject)
   */
  getAll<T>(identifier: ServiceIdentifier<T>): T[] {
    const bindings = this.getAllBindings<T>(identifier);
    return bindings.map(binding => this.resolveBinding(binding) as T);
  }

  /**
   * Checks if a binding exists
   */
  isBound(identifier: ServiceIdentifier): boolean {
    if (this.bindings.has(identifier)) {
      return true;
    }
    return this.parent?.isBound(identifier) || false;
  }

  /**
   * Removes a binding
   */
  unbind(identifier: ServiceIdentifier): void {
    this.bindings.delete(identifier);
  }

  /**
   * Removes and re-binds a service
   */
  rebind<T>(identifier: ServiceIdentifier<T>): IBindingTo<T> {
    this.unbind(identifier);
    return this.bind(identifier);
  }

  /**
   * Creates a child container
   */
  createChild(): IContainer {
    return new Container(this);
  }

  /**
   * Gets parent container
   */
  getParent(): IContainer | undefined {
    return this.parent;
  }

  /**
   * Loads a container module
   */
  load(module: IContainerModule): void {
    module.registry(<T>(id: ServiceIdentifier<T>) => this.bind(id));
  }

  /**
   * Loads an async container module
   */
  async loadAsync(module: IAsyncContainerModule): Promise<void> {
    await module.registry(<T>(id: ServiceIdentifier<T>) => this.bind(id));
  }

  /**
   * Unloads a container module
   */
  unload(_module: IContainerModule): void {
    // Module unloading would require tracking which bindings came from which module
    // For simplicity, this is a no-op in this implementation
  }

  /**
   * Begins a new request scope
   */
  beginRequestScope(): void {
    this.requestScopeInstances.clear();
  }

  /**
   * Ends the current request scope
   */
  endRequestScope(): void {
    this.requestScopeInstances.clear();
  }

  /**
   * Disposes all singleton instances
   */
  async dispose(): Promise<void> {
    for (const bindingList of this.bindings.values()) {
      for (const binding of bindingList) {
        if (binding.instance) {
          // Call dispose if implements IDisposable
          if (this.isDisposable(binding.instance)) {
            const disposable = binding.instance as IDisposable;
            await disposable.dispose();
          }

          binding.instance = undefined;
          binding.initialized = false;
        }
      }
    }
    this.requestScopeInstances.clear();
  }

  /**
   * Snapshots current bindings (for testing)
   */
  snapshot(): void {
    // Would store current state for restoration
  }

  /**
   * Restores bindings from snapshot (for testing)
   */
  restore(): void {
    // Would restore from stored state
  }

  // ===== Private Methods =====

  private getBinding<T>(identifier: ServiceIdentifier<T>): Binding<T> | undefined {
    const bindings = this.bindings.get(identifier);
    if (bindings && bindings.length > 0) {
      return bindings[bindings.length - 1] as Binding<T>; // Return last binding (allows override)
    }
    return undefined;
  }

  private getAllBindings<T>(identifier: ServiceIdentifier<T>): Binding<T>[] {
    const localBindingsRaw = this.bindings.get(identifier);
    const localBindings: Binding<T>[] = localBindingsRaw ? localBindingsRaw as Binding<T>[] : [];
    const parentBindings: Binding<T>[] = this.parent ? this.parent.getAllBindings(identifier) : [];
    const result: Binding<T>[] = [];
    for (const b of parentBindings) {
      result.push(b);
    }
    for (const b of localBindings) {
      result.push(b);
    }
    return result;
  }

  private resolveBinding<T>(binding: Binding<T>): T {
    switch (binding.scope) {
      case BindingScope.SINGLETON:
        if (!binding.initialized && binding.factory) {
          binding.instance = binding.factory(this);
          binding.initialized = true;
        }
        return binding.instance as T;

      case BindingScope.REQUEST:
        const cached = this.requestScopeInstances.get(binding.identifier);
        if (cached !== undefined) {
          return cached as T;
        }
        if (binding.factory) {
          const instance = binding.factory(this);
          this.requestScopeInstances.set(binding.identifier, instance as Object);
          return instance;
        }
        throw new Error(`No factory for request-scoped binding: ${binding.identifier}`);

      case BindingScope.TRANSIENT:
      default:
        if (binding.factory) {
          return binding.factory(this);
        }
        if (binding.instance !== undefined) {
          return binding.instance;
        }
        throw new Error(`No factory or instance for binding: ${binding.identifier}`);
    }
  }

  private async resolveBindingAsync<T>(binding: Binding<T>): Promise<T> {
    switch (binding.scope) {
      case BindingScope.SINGLETON:
        if (!binding.initialized) {
          if (binding.asyncFactory) {
            binding.instance = await binding.asyncFactory(this);
          } else if (binding.factory) {
            binding.instance = binding.factory(this);
          }
          binding.initialized = true;
        }
        return binding.instance as T;

      case BindingScope.REQUEST:
        const cached = this.requestScopeInstances.get(binding.identifier);
        if (cached !== undefined) {
          return cached as T;
        }
        let instance: T;
        if (binding.asyncFactory) {
          instance = await binding.asyncFactory(this);
        } else if (binding.factory) {
          instance = binding.factory(this);
        } else {
          throw new Error(`No factory for request-scoped binding: ${binding.identifier}`);
        }
        this.requestScopeInstances.set(binding.identifier, instance as Object);
        return instance;

      case BindingScope.TRANSIENT:
      default:
        if (binding.asyncFactory) {
          return await binding.asyncFactory(this);
        }
        if (binding.factory) {
          return binding.factory(this);
        }
        if (binding.instance !== undefined) {
          return binding.instance;
        }
        throw new Error(`No factory or instance for binding: ${binding.identifier}`);
    }
  }

  private isDisposable(obj: Object): boolean {
    if (obj === null || typeof obj !== 'object') {
      return false;
    }
    const disposable = obj as IDisposable;
    return typeof disposable.dispose === 'function';
  }
}

/**
 * Creates a new container instance
 */
export function createContainer(): Container {
  return new Container();
}
