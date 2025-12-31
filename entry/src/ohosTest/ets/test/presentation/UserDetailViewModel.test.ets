/**
 * Unit Tests for UserDetailViewModel
 * Tests the user detail screen view model with Input/Output/Effect pattern
 */

import { describe, it, expect, beforeEach, afterEach } from '@ohos/hypium';
import {
  UserDetailViewModel,
  UserDetailState,
  UserDetailInput,
  UserDetailEffect
} from '../../../../main/ets/presentation/viewmodel/UserDetailViewModel';
import { User, UserImpl } from '../../../../main/ets/domain/models/User';
import { Result, ResultFactory } from '../../../../main/ets/domain/models/Result';
import { AppError, AppErrorFactory } from '../../../../main/ets/domain/models/AppError';

// Mock Repository
class MockUserRepository {
  private users: Map<number, User> = new Map();
  private shouldFail = false;

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

  async deleteUser(userId: number): Promise<Result<void, AppError>> {
    if (this.shouldFail) {
      return ResultFactory.failure(AppErrorFactory.networkError('Delete failed'));
    }

    this.users.delete(userId);
    return ResultFactory.success(undefined);
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

export default function UserDetailViewModelTest() {
  describe('UserDetailViewModel', () => {
    let mockRepository: MockUserRepository;
    let mockAnalytics: MockAnalyticsService;

    beforeEach(() => {
      mockRepository = new MockUserRepository();
      mockAnalytics = new MockAnalyticsService();
    });

    describe('constructor', () => {
      it('should create instance with user ID', async () => {
        const existingUser = UserImpl.create(1, 'test@test.com', 'John', 'Doe', 'avatar.png');
        mockRepository.addUser(existingUser);

        const viewModel = new UserDetailViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          1
        );

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        expect(viewModel).assertNotNull();
        expect(viewModel.state.userId).assertEqual(1);
      });

      it('should auto-load user on init', async () => {
        const existingUser = UserImpl.create(1, 'test@test.com', 'John', 'Doe', 'avatar.png');
        mockRepository.addUser(existingUser);

        const viewModel = new UserDetailViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          1
        );

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        expect(viewModel.state.user).assertNotNull();
        expect(viewModel.state.user?.email).assertEqual('test@test.com');
      });
    });

    describe('initial state', () => {
      it('should not be loading after init', async () => {
        const existingUser = UserImpl.create(1, 'test@test.com', 'John', 'Doe', 'avatar.png');
        mockRepository.addUser(existingUser);

        const viewModel = new UserDetailViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          1
        );

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        expect(viewModel.state.isLoading).assertFalse();
      });

      it('should not show delete confirmation initially', async () => {
        const existingUser = UserImpl.create(1, 'test@test.com', 'John', 'Doe', 'avatar.png');
        mockRepository.addUser(existingUser);

        const viewModel = new UserDetailViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          1
        );

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        expect(viewModel.state.showDeleteConfirmation).assertFalse();
      });

      it('should not be deleting initially', async () => {
        const existingUser = UserImpl.create(1, 'test@test.com', 'John', 'Doe', 'avatar.png');
        mockRepository.addUser(existingUser);

        const viewModel = new UserDetailViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          1
        );

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        expect(viewModel.state.isDeleting).assertFalse();
      });
    });

    describe('LoadUser input', () => {
      it('should load user data', async () => {
        const existingUser = UserImpl.create(2, 'loaded@test.com', 'Loaded', 'User', 'loaded.png');
        mockRepository.addUser(existingUser);

        const viewModel = new UserDetailViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          2
        );

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        expect(viewModel.state.user?.firstName).assertEqual('Loaded');
      });

      it('should show error for non-existent user', async () => {
        const viewModel = new UserDetailViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          999
        );

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        expect(viewModel.state.error).assertNotNull();
      });
    });

    describe('RefreshUser input', () => {
      it('should reload user data', async () => {
        const existingUser = UserImpl.create(1, 'test@test.com', 'John', 'Doe', 'avatar.png');
        mockRepository.addUser(existingUser);

        const viewModel = new UserDetailViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          1
        );

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        viewModel.onEvent({ type: 'RefreshUser' });

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        expect(viewModel.state.user).assertNotNull();
      });
    });

    describe('EditUser input', () => {
      it('should emit NavigateToEdit effect', async () => {
        const existingUser = UserImpl.create(1, 'test@test.com', 'John', 'Doe', 'avatar.png');
        mockRepository.addUser(existingUser);

        const viewModel = new UserDetailViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          1
        );

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        const effects: UserDetailEffect[] = [];
        viewModel.subscribeToEffects((effect) => {
          effects.push(effect);
        });

        viewModel.onEvent({ type: 'EditUser' });

        const navigateEffect = effects.find(e => e.type === 'NavigateToEdit');
        expect(navigateEffect).assertNotNull();
      });

      it('should include userId in NavigateToEdit effect', async () => {
        const existingUser = UserImpl.create(42, 'test@test.com', 'John', 'Doe', 'avatar.png');
        mockRepository.addUser(existingUser);

        const viewModel = new UserDetailViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          42
        );

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        const effects: UserDetailEffect[] = [];
        viewModel.subscribeToEffects((effect) => {
          effects.push(effect);
        });

        viewModel.onEvent({ type: 'EditUser' });

        const navigateEffect = effects.find(e => e.type === 'NavigateToEdit');
        if (navigateEffect && navigateEffect.type === 'NavigateToEdit') {
          expect(navigateEffect.userId).assertEqual(42);
        }
      });
    });

    describe('DeleteUser input', () => {
      it('should show delete confirmation', async () => {
        const existingUser = UserImpl.create(1, 'test@test.com', 'John', 'Doe', 'avatar.png');
        mockRepository.addUser(existingUser);

        const viewModel = new UserDetailViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          1
        );

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        viewModel.onEvent({ type: 'DeleteUser' });

        expect(viewModel.state.showDeleteConfirmation).assertTrue();
      });
    });

    describe('CancelDelete input', () => {
      it('should hide delete confirmation', async () => {
        const existingUser = UserImpl.create(1, 'test@test.com', 'John', 'Doe', 'avatar.png');
        mockRepository.addUser(existingUser);

        const viewModel = new UserDetailViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          1
        );

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        viewModel.onEvent({ type: 'DeleteUser' });
        expect(viewModel.state.showDeleteConfirmation).assertTrue();

        viewModel.onEvent({ type: 'CancelDelete' });
        expect(viewModel.state.showDeleteConfirmation).assertFalse();
      });
    });

    describe('ConfirmDelete input', () => {
      it('should delete user and navigate back', async () => {
        const existingUser = UserImpl.create(1, 'test@test.com', 'John', 'Doe', 'avatar.png');
        mockRepository.addUser(existingUser);

        const viewModel = new UserDetailViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          1
        );

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        const effects: UserDetailEffect[] = [];
        viewModel.subscribeToEffects((effect) => {
          effects.push(effect);
        });

        viewModel.onEvent({ type: 'DeleteUser' });
        viewModel.onEvent({ type: 'ConfirmDelete' });

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        const hasNavigateBack = effects.some(e => e.type === 'NavigateBack');
        const hasUserDeleted = effects.some(e => e.type === 'UserDeleted');

        expect(hasNavigateBack).assertTrue();
        expect(hasUserDeleted).assertTrue();
      });

      it('should show error on delete failure', async () => {
        const existingUser = UserImpl.create(1, 'test@test.com', 'John', 'Doe', 'avatar.png');
        mockRepository.addUser(existingUser);
        mockRepository.setShouldFail(true);

        const viewModel = new UserDetailViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          1
        );

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        const effects: UserDetailEffect[] = [];
        viewModel.subscribeToEffects((effect) => {
          effects.push(effect);
        });

        viewModel.onEvent({ type: 'DeleteUser' });
        viewModel.onEvent({ type: 'ConfirmDelete' });

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        const hasShowError = effects.some(e => e.type === 'ShowError');
        expect(hasShowError).assertTrue();
      });
    });

    describe('NavigateBack input', () => {
      it('should emit NavigateBack effect', async () => {
        const existingUser = UserImpl.create(1, 'test@test.com', 'John', 'Doe', 'avatar.png');
        mockRepository.addUser(existingUser);

        const viewModel = new UserDetailViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          1
        );

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        const effects: UserDetailEffect[] = [];
        viewModel.subscribeToEffects((effect) => {
          effects.push(effect);
        });

        viewModel.onEvent({ type: 'NavigateBack' });

        const hasNavigateBack = effects.some(e => e.type === 'NavigateBack');
        expect(hasNavigateBack).assertTrue();
      });
    });

    describe('UserUpdated input', () => {
      it('should reload user data', async () => {
        const existingUser = UserImpl.create(1, 'test@test.com', 'John', 'Doe', 'avatar.png');
        mockRepository.addUser(existingUser);

        const viewModel = new UserDetailViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          1
        );

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        // Update user in repository
        const updatedUser = UserImpl.create(1, 'updated@test.com', 'Updated', 'Name', 'new.png');
        mockRepository.addUser(updatedUser);

        viewModel.onEvent({ type: 'UserUpdated' });

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        expect(viewModel.state.user?.firstName).assertEqual('Updated');
      });
    });

    describe('state subscriptions', () => {
      it('should notify subscribers on state changes', async () => {
        const existingUser = UserImpl.create(1, 'test@test.com', 'John', 'Doe', 'avatar.png');
        mockRepository.addUser(existingUser);

        const viewModel = new UserDetailViewModel(
          mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
          mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService,
          1
        );

        let stateChangeCount = 0;
        viewModel.subscribe((state) => {
          stateChangeCount++;
        });

        await new Promise<void>(resolve => setTimeout(resolve, 200));

        expect(stateChangeCount >= 1).assertTrue();
      });
    });
  });
}
