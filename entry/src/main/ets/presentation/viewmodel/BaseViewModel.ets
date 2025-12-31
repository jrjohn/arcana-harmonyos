import { Logger } from '../../core/logging/Logger';

const TAG = 'BaseViewModel';

/**
 * Base interface for ViewModel Input events
 */
export interface BaseInput {}

/**
 * Base interface for ViewModel Output
 */
export interface BaseOutput {
  state: BaseState;
}

/**
 * Base interface for ViewModel State
 */
export interface BaseState {
  isLoading: boolean;
  error: string | undefined;
}

/**
 * Base interface for one-time Effects
 */
export interface BaseEffect {}

/**
 * State change callback type
 */
export type StateCallback<S> = (state: S) => void;

/**
 * Effect callback type
 */
export type EffectCallback<E> = (effect: E) => void;

/**
 * Unsubscribe callback class for state subscriptions
 */
export class StateUnsubscribe<S> {
  private callback: StateCallback<S>;
  private callbacks: Set<StateCallback<S>>;

  constructor(callback: StateCallback<S>, callbacks: Set<StateCallback<S>>) {
    this.callback = callback;
    this.callbacks = callbacks;
  }

  unsubscribe(): void {
    this.callbacks.delete(this.callback);
  }
}

/**
 * Unsubscribe callback class for effect subscriptions
 */
export class EffectUnsubscribe<E> {
  private callback: EffectCallback<E>;
  private callbacks: Set<EffectCallback<E>>;

  constructor(callback: EffectCallback<E>, callbacks: Set<EffectCallback<E>>) {
    this.callback = callback;
    this.callbacks = callbacks;
  }

  unsubscribe(): void {
    this.callbacks.delete(this.callback);
  }
}

/**
 * Abstract base class for ViewModels implementing the Input/Output pattern.
 * This pattern separates:
 * - Input: User actions and events
 * - Output.State: UI state (observable)
 * - Output.Effect: One-time side effects (navigation, snackbars, etc.)
 */
export abstract class BaseViewModel<I extends BaseInput, S extends BaseState, E extends BaseEffect> {
  protected _state: S;
  private stateCallbacks: Set<StateCallback<S>> = new Set();
  private effectCallbacks: Set<EffectCallback<E>> = new Set();
  private isDestroyed: boolean = false;

  constructor(initialState: S) {
    this._state = initialState;
  }

  /**
   * Gets the current state
   */
  get state(): S {
    return this._state;
  }

  /**
   * Handles an input event from the UI
   */
  abstract onEvent(input: I): void;

  /**
   * Subscribes to state changes
   */
  subscribeToState(callback: StateCallback<S>): StateUnsubscribe<S> {
    this.stateCallbacks.add(callback);

    // Immediately emit current state
    callback(this._state);

    return new StateUnsubscribe(callback, this.stateCallbacks);
  }

  /**
   * Subscribes to one-time effects
   */
  subscribeToEffects(callback: EffectCallback<E>): EffectUnsubscribe<E> {
    this.effectCallbacks.add(callback);

    return new EffectUnsubscribe(callback, this.effectCallbacks);
  }

  /**
   * Updates the state and notifies subscribers
   * Subclasses should implement specific state update methods
   */
  protected abstract updateState(state: S): void;

  /**
   * Replaces the entire state
   */
  protected replaceState(newState: S): void {
    if (this.isDestroyed) {
      Logger.w(TAG, 'Attempting to replace state after destruction');
      return;
    }

    this._state = newState;
    this.notifyStateChange();
  }

  /**
   * Sets the state directly (used by subclasses)
   */
  protected setStateDirectly(newState: S): void {
    if (this.isDestroyed) {
      Logger.w(TAG, 'Attempting to update state after destruction');
      return;
    }

    this._state = newState;
    this.notifyStateChange();
  }

  /**
   * Emits a one-time effect
   */
  protected emitEffect(effect: E): void {
    if (this.isDestroyed) {
      Logger.w(TAG, 'Attempting to emit effect after destruction');
      return;
    }

    this.effectCallbacks.forEach(callback => {
      try {
        callback(effect);
      } catch (error) {
        Logger.e(TAG, `Error in effect callback: ${error}`);
      }
    });
  }

  /**
   * Sets loading state (subclasses should override if needed)
   */
  protected abstract setLoading(isLoading: boolean): void;

  /**
   * Sets error state (subclasses should override if needed)
   */
  protected abstract setError(error: string | undefined): void;

  /**
   * Clears error state (subclasses should override if needed)
   */
  protected abstract clearError(): void;

  /**
   * Notifies all state subscribers
   */
  private notifyStateChange(): void {
    this.stateCallbacks.forEach(callback => {
      try {
        callback(this._state);
      } catch (error) {
        Logger.e(TAG, `Error in state callback: ${error}`);
      }
    });
  }

  /**
   * Cleanup resources
   */
  destroy(): void {
    this.isDestroyed = true;
    this.stateCallbacks.clear();
    this.effectCallbacks.clear();
    Logger.d(TAG, 'ViewModel destroyed');
  }
}
