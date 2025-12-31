/**
 * Unit Tests for UserFormViewModel
 */

import { describe, it, expect, beforeEach } from '@ohos/hypium';
import {
  UserFormViewModel,
  UserFormState,
  UserFormInput,
  UserFormEffect
} from '../../../../main/ets/presentation/viewmodel/UserFormViewModel';
import { User, UserImpl } from '../../../../main/ets/domain/models/User';
import { Result, ResultFactory } from '../../../../main/ets/domain/models/Result';
import { AppError, AppErrorFactory } from '../../../../main/ets/domain/models/AppError';

// Mock Repository
class MockUserRepository {
  private users: Map<number, User> = new Map();
  private shouldFail = false;
  private nextId = 100;

  addUser(user: User): void {
    this.users.set(user.id, user);
  }

  setShouldFail(shouldFail: boolean): void {
    this.shouldFail = shouldFail;
  }

  async getUser(userId: number): Promise<Result<User, AppError>> {
    if (this.shouldFail) {
      return ResultFactory.failure(AppErrorFactory.networkError('Mock error'));
    }

    const user = this.users.get(userId);
    if (user) {
      return ResultFactory.success(user);
    }
    return ResultFactory.failure(AppErrorFactory.apiNotFound('User'));
  }

  async createUser(request: { firstName: string; lastName: string; email: string; avatar: string }): Promise<Result<User, AppError>> {
    if (this.shouldFail) {
      return ResultFactory.failure(AppErrorFactory.networkError('Mock error'));
    }

    const user = UserImpl.create(this.nextId++, request.email, request.firstName, request.lastName, request.avatar);
    this.users.set(user.id, user);
    return ResultFactory.success(user);
  }

  async updateUser(request: { id: number; firstName: string; lastName: string; email: string; avatar: string }): Promise<Result<User, AppError>> {
    if (this.shouldFail) {
      return ResultFactory.failure(AppErrorFactory.networkError('Mock error'));
    }

    const user = UserImpl.create(request.id, request.email, request.firstName, request.lastName, request.avatar);
    this.users.set(user.id, user);
    return ResultFactory.success(user);
  }
}

// Mock AnalyticsService
class MockAnalyticsService {
  trackEvent(name: string, props?: object): void {}
  trackScreen(screenName: string, screenClass: string): void {}
  trackAction(action: string, target: string): void {}
  trackError(code: string, message: string): void {}
  startTiming(name: string) {
    return { end: () => {} };
  }
}

export default function UserFormViewModelTest() {
  describe('UserFormViewModel', () => {
    let mockRepository: MockUserRepository;
    let mockAnalytics: MockAnalyticsService;

    beforeEach(() => {
      mockRepository = new MockUserRepository();
      mockAnalytics = new MockAnalyticsService();
    });

    describe('create mode', () => {
      let viewModel: UserFormViewModel;

      beforeEach(() => {
        viewModel = new UserFormViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          'create'
        );
      });

      it('should initialize in create mode', () => {
        expect(viewModel.state.mode).assertEqual('create');
        expect(viewModel.state.userId).assertUndefined();
        expect(viewModel.state.firstName).assertEqual('');
        expect(viewModel.state.lastName).assertEqual('');
        expect(viewModel.state.email).assertEqual('');
      });

      it('should not be loading initially', () => {
        expect(viewModel.state.isLoading).assertFalse();
      });

      it('should not be valid with empty fields', () => {
        expect(viewModel.state.isValid).assertFalse();
      });
    });

    describe('edit mode', () => {
      it('should load user in edit mode', async () => {
        const existingUser = UserImpl.create(1, 'test@example.com', 'John', 'Doe', 'avatar.png');
        mockRepository.addUser(existingUser);

        const viewModel = new UserFormViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          'edit',
          1
        );

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        expect(viewModel.state.mode).assertEqual('edit');
        expect(viewModel.state.firstName).assertEqual('John');
        expect(viewModel.state.lastName).assertEqual('Doe');
        expect(viewModel.state.email).assertEqual('test@example.com');
      });
    });

    describe('UpdateFirstName event', () => {
      let viewModel: UserFormViewModel;

      beforeEach(() => {
        viewModel = new UserFormViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          'create'
        );
      });

      it('should update first name', () => {
        viewModel.onEvent({ type: 'UpdateFirstName', value: 'John' });

        expect(viewModel.state.firstName).assertEqual('John');
      });

      it('should mark form as having changes', () => {
        viewModel.onEvent({ type: 'UpdateFirstName', value: 'John' });

        expect(viewModel.state.hasChanges).assertTrue();
      });

      it('should clear first name error on update', () => {
        // First validate to set error
        viewModel.onEvent({ type: 'ValidateField', field: 'firstName' });
        expect(viewModel.state.firstNameError).assertNotNull();

        // Then update to clear error
        viewModel.onEvent({ type: 'UpdateFirstName', value: 'John' });
        expect(viewModel.state.firstNameError).assertUndefined();
      });
    });

    describe('UpdateLastName event', () => {
      let viewModel: UserFormViewModel;

      beforeEach(() => {
        viewModel = new UserFormViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          'create'
        );
      });

      it('should update last name', () => {
        viewModel.onEvent({ type: 'UpdateLastName', value: 'Doe' });

        expect(viewModel.state.lastName).assertEqual('Doe');
      });
    });

    describe('UpdateEmail event', () => {
      let viewModel: UserFormViewModel;

      beforeEach(() => {
        viewModel = new UserFormViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          'create'
        );
      });

      it('should update email', () => {
        viewModel.onEvent({ type: 'UpdateEmail', value: 'test@example.com' });

        expect(viewModel.state.email).assertEqual('test@example.com');
      });
    });

    describe('UpdateAvatar event', () => {
      let viewModel: UserFormViewModel;

      beforeEach(() => {
        viewModel = new UserFormViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          'create'
        );
      });

      it('should update avatar', () => {
        viewModel.onEvent({ type: 'UpdateAvatar', value: 'avatar.png' });

        expect(viewModel.state.avatar).assertEqual('avatar.png');
      });
    });

    describe('ValidateField event', () => {
      let viewModel: UserFormViewModel;

      beforeEach(() => {
        viewModel = new UserFormViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          'create'
        );
      });

      it('should validate first name and show error for empty', () => {
        viewModel.onEvent({ type: 'ValidateField', field: 'firstName' });

        expect(viewModel.state.firstNameError).assertNotNull();
      });

      it('should validate first name and clear error for valid', () => {
        viewModel.onEvent({ type: 'UpdateFirstName', value: 'John' });
        viewModel.onEvent({ type: 'ValidateField', field: 'firstName' });

        expect(viewModel.state.firstNameError).assertUndefined();
      });

      it('should validate last name and show error for empty', () => {
        viewModel.onEvent({ type: 'ValidateField', field: 'lastName' });

        expect(viewModel.state.lastNameError).assertNotNull();
      });

      it('should validate email and show error for invalid', () => {
        viewModel.onEvent({ type: 'UpdateEmail', value: 'invalid' });
        viewModel.onEvent({ type: 'ValidateField', field: 'email' });

        expect(viewModel.state.emailError).assertNotNull();
      });

      it('should validate email and clear error for valid', () => {
        viewModel.onEvent({ type: 'UpdateEmail', value: 'test@example.com' });
        viewModel.onEvent({ type: 'ValidateField', field: 'email' });

        expect(viewModel.state.emailError).assertUndefined();
      });
    });

    describe('ValidateAll event', () => {
      let viewModel: UserFormViewModel;

      beforeEach(() => {
        viewModel = new UserFormViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          'create'
        );
      });

      it('should validate all fields', () => {
        viewModel.onEvent({ type: 'ValidateAll' });

        expect(viewModel.state.firstNameError).assertNotNull();
        expect(viewModel.state.lastNameError).assertNotNull();
        expect(viewModel.state.emailError).assertNotNull();
        expect(viewModel.state.isValid).assertFalse();
      });

      it('should set isValid true when all fields valid', () => {
        viewModel.onEvent({ type: 'UpdateFirstName', value: 'John' });
        viewModel.onEvent({ type: 'UpdateLastName', value: 'Doe' });
        viewModel.onEvent({ type: 'UpdateEmail', value: 'john@example.com' });
        viewModel.onEvent({ type: 'ValidateAll' });

        expect(viewModel.state.isValid).assertTrue();
      });
    });

    describe('Submit event in create mode', () => {
      let viewModel: UserFormViewModel;

      beforeEach(() => {
        viewModel = new UserFormViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          'create'
        );
      });

      it('should not submit with invalid data', async () => {
        let effectEmitted = false;

        viewModel.subscribeToEffects(() => {
          effectEmitted = true;
        });

        viewModel.onEvent({ type: 'Submit' });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        // Should not emit NavigateBack on invalid submit
        expect(effectEmitted).assertFalse();
      });

      it('should submit with valid data', async () => {
        viewModel.onEvent({ type: 'UpdateFirstName', value: 'John' });
        viewModel.onEvent({ type: 'UpdateLastName', value: 'Doe' });
        viewModel.onEvent({ type: 'UpdateEmail', value: 'john@example.com' });

        const effects: UserFormEffect[] = [];
        viewModel.subscribeToEffects((effect) => {
          effects.push(effect);
        });

        viewModel.onEvent({ type: 'Submit' });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        const hasSuccessEffect = effects.some(e => e.type === 'ShowSuccess');
        const hasNavigateBack = effects.some(e => e.type === 'NavigateBack');

        expect(hasSuccessEffect).assertTrue();
        expect(hasNavigateBack).assertTrue();
      });

      it('should show error on submit failure', async () => {
        mockRepository.setShouldFail(true);

        viewModel.onEvent({ type: 'UpdateFirstName', value: 'John' });
        viewModel.onEvent({ type: 'UpdateLastName', value: 'Doe' });
        viewModel.onEvent({ type: 'UpdateEmail', value: 'john@example.com' });

        let errorEffect: UserFormEffect | null = null;
        viewModel.subscribeToEffects((effect) => {
          if (effect.type === 'ShowError') {
            errorEffect = effect;
          }
        });

        viewModel.onEvent({ type: 'Submit' });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        expect(errorEffect).assertNotNull();
      });
    });

    describe('Submit event in edit mode', () => {
      it('should update user on submit', async () => {
        const existingUser = UserImpl.create(1, 'old@example.com', 'OldFirst', 'OldLast', 'old.png');
        mockRepository.addUser(existingUser);

        const viewModel = new UserFormViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          'edit',
          1
        );

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        viewModel.onEvent({ type: 'UpdateFirstName', value: 'NewFirst' });
        viewModel.onEvent({ type: 'UpdateLastName', value: 'NewLast' });
        viewModel.onEvent({ type: 'UpdateEmail', value: 'new@example.com' });

        const effects: UserFormEffect[] = [];
        viewModel.subscribeToEffects((effect) => {
          effects.push(effect);
        });

        viewModel.onEvent({ type: 'Submit' });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        const hasSuccessEffect = effects.some(e => e.type === 'ShowSuccess');
        expect(hasSuccessEffect).assertTrue();
      });
    });

    describe('Cancel event', () => {
      let viewModel: UserFormViewModel;

      beforeEach(() => {
        viewModel = new UserFormViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          'create'
        );
      });

      it('should navigate back if no changes', () => {
        let effect: UserFormEffect | null = null;
        viewModel.subscribeToEffects((e) => {
          effect = e;
        });

        viewModel.onEvent({ type: 'Cancel' });

        expect(effect?.type).assertEqual('NavigateBack');
      });

      it('should show unsaved changes dialog if has changes', () => {
        viewModel.onEvent({ type: 'UpdateFirstName', value: 'John' });

        let effect: UserFormEffect | null = null;
        viewModel.subscribeToEffects((e) => {
          effect = e;
        });

        viewModel.onEvent({ type: 'Cancel' });

        expect(effect?.type).assertEqual('ShowUnsavedChangesDialog');
      });
    });

    describe('hasUnsavedChanges', () => {
      it('should return false for new empty form', () => {
        const viewModel = new UserFormViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          'create'
        );

        expect(viewModel.hasUnsavedChanges()).assertFalse();
      });

      it('should return true when form has data', () => {
        const viewModel = new UserFormViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          'create'
        );

        viewModel.onEvent({ type: 'UpdateFirstName', value: 'John' });

        expect(viewModel.hasUnsavedChanges()).assertTrue();
      });

      it('should detect changes in edit mode', async () => {
        const existingUser = UserImpl.create(1, 'test@example.com', 'John', 'Doe', 'avatar.png');
        mockRepository.addUser(existingUser);

        const viewModel = new UserFormViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          'edit',
          1
        );

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        expect(viewModel.hasUnsavedChanges()).assertFalse();

        viewModel.onEvent({ type: 'UpdateFirstName', value: 'Jane' });

        expect(viewModel.hasUnsavedChanges()).assertTrue();
      });
    });
  });
}
