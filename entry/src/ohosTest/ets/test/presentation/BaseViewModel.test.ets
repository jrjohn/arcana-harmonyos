/**
 * Unit Tests for BaseViewModel
 */

import { describe, it, expect, beforeEach } from '@ohos/hypium';
import {
  BaseViewModel,
  BaseInput,
  BaseState,
  BaseEffect,
  StateCallback,
  EffectCallback,
  StateUnsubscribe,
  EffectUnsubscribe
} from '../../../../main/ets/presentation/viewmodel/BaseViewModel';

// Test implementation of BaseViewModel
interface TestInput extends BaseInput {
  type: string;
  value?: string;
}

interface TestState extends BaseState {
  count: number;
  message: string;
}

interface TestEffect extends BaseEffect {
  type: string;
  payload?: string;
}

class TestViewModel extends BaseViewModel<TestInput, TestState, TestEffect> {
  constructor() {
    super({
      isLoading: false,
      error: undefined,
      count: 0,
      message: ''
    });
  }

  onEvent(input: TestInput): void {
    switch (input.type) {
      case 'increment':
        this.incrementCount();
        break;
      case 'setMessage':
        this.setMessage(input.value ?? '');
        break;
      case 'triggerEffect':
        this.triggerEffect(input.value);
        break;
      case 'setLoadingTrue':
        this.setLoading(true);
        break;
      case 'setLoadingFalse':
        this.setLoading(false);
        break;
      case 'setError':
        this.setError(input.value);
        break;
      case 'clearError':
        this.clearError();
        break;
    }
  }

  protected updateState(state: TestState): void {
    this.setStateDirectly(state);
  }

  protected setLoading(isLoading: boolean): void {
    this._state.isLoading = isLoading;
    this.replaceState(this.copyState());
  }

  protected setError(error: string | undefined): void {
    this._state.error = error;
    this._state.isLoading = false;
    this.replaceState(this.copyState());
  }

  protected clearError(): void {
    this._state.error = undefined;
    this.replaceState(this.copyState());
  }

  private incrementCount(): void {
    this._state.count++;
    this.replaceState(this.copyState());
  }

  private setMessage(message: string): void {
    this._state.message = message;
    this.replaceState(this.copyState());
  }

  private triggerEffect(payload?: string): void {
    const effect: TestEffect = { type: 'testEffect', payload };
    this.emitEffect(effect);
  }

  private copyState(): TestState {
    return {
      isLoading: this._state.isLoading,
      error: this._state.error,
      count: this._state.count,
      message: this._state.message
    };
  }

  // Expose for testing
  testReplaceState(state: TestState): void {
    this.replaceState(state);
  }

  testEmitEffect(effect: TestEffect): void {
    this.emitEffect(effect);
  }
}

export default function BaseViewModelTest() {
  describe('BaseViewModel', () => {
    let viewModel: TestViewModel;

    beforeEach(() => {
      viewModel = new TestViewModel();
    });

    describe('initial state', () => {
      it('should have initial state', () => {
        expect(viewModel.state.isLoading).assertFalse();
        expect(viewModel.state.error).assertUndefined();
        expect(viewModel.state.count).assertEqual(0);
        expect(viewModel.state.message).assertEqual('');
      });
    });

    describe('subscribeToState', () => {
      it('should immediately emit current state', () => {
        let receivedState: TestState | null = null;

        viewModel.subscribeToState((state) => {
          receivedState = state;
        });

        expect(receivedState).assertNotNull();
        expect(receivedState?.count).assertEqual(0);
      });

      it('should emit state on changes', () => {
        let callCount = 0;
        let lastState: TestState | null = null;

        viewModel.subscribeToState((state) => {
          callCount++;
          lastState = state;
        });

        viewModel.onEvent({ type: 'increment' });

        expect(callCount).assertEqual(2); // Initial + update
        expect(lastState?.count).assertEqual(1);
      });

      it('should support multiple subscribers', () => {
        let count1 = 0;
        let count2 = 0;

        viewModel.subscribeToState(() => count1++);
        viewModel.subscribeToState(() => count2++);

        viewModel.onEvent({ type: 'increment' });

        expect(count1).assertEqual(2);
        expect(count2).assertEqual(2);
      });

      it('should return unsubscribe object', () => {
        const unsubscribe = viewModel.subscribeToState(() => {});

        expect(unsubscribe).assertNotNull();
        expect(typeof unsubscribe.unsubscribe).assertEqual('function');
      });
    });

    describe('unsubscribe', () => {
      it('should stop receiving updates after unsubscribe', () => {
        let callCount = 0;

        const unsubscribe = viewModel.subscribeToState(() => callCount++);

        unsubscribe.unsubscribe();
        viewModel.onEvent({ type: 'increment' });

        expect(callCount).assertEqual(1); // Only initial call
      });
    });

    describe('subscribeToEffects', () => {
      it('should receive effects', () => {
        let receivedEffect: TestEffect | null = null;

        viewModel.subscribeToEffects((effect) => {
          receivedEffect = effect;
        });

        viewModel.onEvent({ type: 'triggerEffect', value: 'test-payload' });

        expect(receivedEffect).assertNotNull();
        expect(receivedEffect?.type).assertEqual('testEffect');
        expect(receivedEffect?.payload).assertEqual('test-payload');
      });

      it('should not emit immediately on subscribe', () => {
        let callCount = 0;

        viewModel.subscribeToEffects(() => callCount++);

        expect(callCount).assertEqual(0);
      });

      it('should support multiple effect subscribers', () => {
        let count1 = 0;
        let count2 = 0;

        viewModel.subscribeToEffects(() => count1++);
        viewModel.subscribeToEffects(() => count2++);

        viewModel.onEvent({ type: 'triggerEffect' });

        expect(count1).assertEqual(1);
        expect(count2).assertEqual(1);
      });

      it('should return unsubscribe object', () => {
        const unsubscribe = viewModel.subscribeToEffects(() => {});

        expect(unsubscribe).assertNotNull();
        expect(typeof unsubscribe.unsubscribe).assertEqual('function');
      });
    });

    describe('effect unsubscribe', () => {
      it('should stop receiving effects after unsubscribe', () => {
        let callCount = 0;

        const unsubscribe = viewModel.subscribeToEffects(() => callCount++);

        unsubscribe.unsubscribe();
        viewModel.onEvent({ type: 'triggerEffect' });

        expect(callCount).assertEqual(0);
      });
    });

    describe('onEvent', () => {
      it('should handle increment event', () => {
        viewModel.onEvent({ type: 'increment' });

        expect(viewModel.state.count).assertEqual(1);
      });

      it('should handle multiple increment events', () => {
        viewModel.onEvent({ type: 'increment' });
        viewModel.onEvent({ type: 'increment' });
        viewModel.onEvent({ type: 'increment' });

        expect(viewModel.state.count).assertEqual(3);
      });

      it('should handle setMessage event', () => {
        viewModel.onEvent({ type: 'setMessage', value: 'Hello' });

        expect(viewModel.state.message).assertEqual('Hello');
      });

      it('should handle setLoading events', () => {
        viewModel.onEvent({ type: 'setLoadingTrue' });
        expect(viewModel.state.isLoading).assertTrue();

        viewModel.onEvent({ type: 'setLoadingFalse' });
        expect(viewModel.state.isLoading).assertFalse();
      });

      it('should handle setError event', () => {
        viewModel.onEvent({ type: 'setError', value: 'Test error' });

        expect(viewModel.state.error).assertEqual('Test error');
        expect(viewModel.state.isLoading).assertFalse();
      });

      it('should handle clearError event', () => {
        viewModel.onEvent({ type: 'setError', value: 'Test error' });
        viewModel.onEvent({ type: 'clearError' });

        expect(viewModel.state.error).assertUndefined();
      });
    });

    describe('destroy', () => {
      it('should clear all subscribers', () => {
        let stateCount = 0;
        let effectCount = 0;

        viewModel.subscribeToState(() => stateCount++);
        viewModel.subscribeToEffects(() => effectCount++);

        viewModel.destroy();

        viewModel.testReplaceState({
          isLoading: false,
          error: undefined,
          count: 100,
          message: 'test'
        });
        viewModel.testEmitEffect({ type: 'test' });

        // Should only have initial state subscription call
        expect(stateCount).assertEqual(1);
        expect(effectCount).assertEqual(0);
      });

      it('should handle state updates after destroy gracefully', () => {
        viewModel.destroy();

        // Should not throw
        viewModel.testReplaceState({
          isLoading: false,
          error: undefined,
          count: 100,
          message: 'test'
        });
      });

      it('should handle effect emissions after destroy gracefully', () => {
        viewModel.destroy();

        // Should not throw
        viewModel.testEmitEffect({ type: 'test' });
      });
    });

    describe('StateUnsubscribe', () => {
      it('should remove callback from set on unsubscribe', () => {
        let callCount = 0;
        const callback = () => callCount++;

        const unsubscribe = viewModel.subscribeToState(callback);
        expect(callCount).assertEqual(1); // Initial call

        unsubscribe.unsubscribe();

        viewModel.onEvent({ type: 'increment' });
        expect(callCount).assertEqual(1); // No additional calls
      });
    });

    describe('EffectUnsubscribe', () => {
      it('should remove callback from set on unsubscribe', () => {
        let callCount = 0;
        const callback = () => callCount++;

        const unsubscribe = viewModel.subscribeToEffects(callback);

        unsubscribe.unsubscribe();

        viewModel.onEvent({ type: 'triggerEffect' });
        expect(callCount).assertEqual(0);
      });
    });

    describe('error handling in callbacks', () => {
      it('should continue notifying other subscribers if one throws', () => {
        let count1 = 0;
        let count2 = 0;

        viewModel.subscribeToState(() => {
          count1++;
          throw new Error('Test error');
        });

        viewModel.subscribeToState(() => {
          count2++;
        });

        viewModel.onEvent({ type: 'increment' });

        // Both should be called despite first throwing
        expect(count1).assertEqual(2);
        expect(count2).assertEqual(2);
      });

      it('should continue notifying effect subscribers if one throws', () => {
        let count1 = 0;
        let count2 = 0;

        viewModel.subscribeToEffects(() => {
          count1++;
          throw new Error('Test error');
        });

        viewModel.subscribeToEffects(() => {
          count2++;
        });

        viewModel.onEvent({ type: 'triggerEffect' });

        expect(count1).assertEqual(1);
        expect(count2).assertEqual(1);
      });
    });
  });
}
