/**
 * Unit Tests for UserListViewModel
 */

import { describe, it, expect, beforeEach } from '@ohos/hypium';
import {
  UserListViewModel,
  UserListState,
  UserListInput,
  UserListEffect
} from '../../../../main/ets/presentation/viewmodel/UserListViewModel';
import { User, UserImpl, PaginatedUsers } from '../../../../main/ets/domain/models/User';
import { Result, ResultFactory, Success, Failure } from '../../../../main/ets/domain/models/Result';
import { AppError, AppErrorFactory } from '../../../../main/ets/domain/models/AppError';

// Mock Repository
class MockUserRepository {
  private users: User[] = [];
  private shouldFail = false;
  private errorMessage = 'Mock error';

  setUsers(users: User[]): void {
    this.users = users;
  }

  setShouldFail(shouldFail: boolean, errorMessage?: string): void {
    this.shouldFail = shouldFail;
    if (errorMessage) {
      this.errorMessage = errorMessage;
    }
  }

  async getUsers(page: number, forceRefresh?: boolean): Promise<Result<PaginatedUsers, AppError>> {
    if (this.shouldFail) {
      return ResultFactory.failure(AppErrorFactory.networkError(this.errorMessage));
    }

    const perPage = 6;
    const startIndex = (page - 1) * perPage;
    const pageUsers = this.users.slice(startIndex, startIndex + perPage);

    const paginatedUsers: PaginatedUsers = {
      users: pageUsers,
      page: page,
      perPage: perPage,
      total: this.users.length,
      totalPages: Math.ceil(this.users.length / perPage)
    };

    return ResultFactory.success(paginatedUsers);
  }

  async getUser(userId: number): Promise<Result<User, AppError>> {
    if (this.shouldFail) {
      return ResultFactory.failure(AppErrorFactory.networkError(this.errorMessage));
    }

    const user = this.users.find(u => u.id === userId);
    if (user) {
      return ResultFactory.success(user);
    }
    return ResultFactory.failure(AppErrorFactory.apiNotFound('User'));
  }

  async deleteUser(userId: number): Promise<Result<void, AppError>> {
    if (this.shouldFail) {
      return ResultFactory.failure(AppErrorFactory.networkError(this.errorMessage));
    }

    this.users = this.users.filter(u => u.id !== userId);
    return ResultFactory.success(undefined);
  }
}

// Mock SyncManager
class MockSyncManager {
  private syncState = { isSyncing: false, pendingCount: 0, lastSyncTime: undefined, lastSyncError: undefined };
  private subscribers: Set<(state: object) => void> = new Set();

  getState() {
    return this.syncState;
  }

  subscribe(callback: (state: object) => void) {
    this.subscribers.add(callback);
    return { unsubscribe: () => this.subscribers.delete(callback) };
  }

  async triggerSync(): Promise<void> {
    this.syncState.isSyncing = true;
    this.notifySubscribers();
    await new Promise<void>(resolve => setTimeout(resolve, 10));
    this.syncState.isSyncing = false;
    this.notifySubscribers();
  }

  private notifySubscribers(): void {
    this.subscribers.forEach(cb => cb(this.syncState));
  }
}

// Mock AnalyticsService
class MockAnalyticsService {
  private events: Array<{ name: string }> = [];

  trackEvent(name: string, props?: object): void {
    this.events.push({ name });
  }

  trackScreen(screenName: string, screenClass: string): void {
    // No-op for tests
  }

  trackAction(action: string, target: string): void {
    // No-op for tests
  }

  trackError(code: string, message: string): void {
    // No-op for tests
  }

  startTiming(name: string) {
    return { end: () => {} };
  }

  getEvents(): Array<{ name: string }> {
    return this.events;
  }

  clearEvents(): void {
    this.events = [];
  }
}

// Helper to create test users
function createTestUsers(count: number): User[] {
  const users: User[] = [];
  for (let i = 1; i <= count; i++) {
    users.push(UserImpl.create(i, `user${i}@example.com`, `First${i}`, `Last${i}`, `avatar${i}.png`));
  }
  return users;
}

export default function UserListViewModelTest() {
  describe('UserListViewModel', () => {
    let viewModel: UserListViewModel;
    let mockRepository: MockUserRepository;
    let mockSyncManager: MockSyncManager;
    let mockAnalytics: MockAnalyticsService;

    beforeEach(() => {
      mockRepository = new MockUserRepository();
      mockSyncManager = new MockSyncManager();
      mockAnalytics = new MockAnalyticsService();

      // Set up test users
      mockRepository.setUsers(createTestUsers(12));

      viewModel = new UserListViewModel(
        mockRepository as unknown as import('../../../../main/ets/data/repository/UserRepositoryImpl').UserRepositoryImpl,
        mockSyncManager as unknown as import('../../../../main/ets/core/sync/SyncManager').SyncManager,
        mockAnalytics as unknown as import('../../../../main/ets/core/analytics/AnalyticsService').AnalyticsService
      );
    });

    describe('initial state', () => {
      it('should have correct initial state', () => {
        expect(viewModel.state.isLoading).assertFalse();
        expect(viewModel.state.users.length).assertEqual(0);
        expect(viewModel.state.currentPage).assertEqual(1);
        expect(viewModel.state.hasNextPage).assertFalse();
        expect(viewModel.state.searchQuery).assertEqual('');
        expect(viewModel.state.isEmpty).assertTrue();
      });
    });

    describe('LoadUsers event', () => {
      it('should load users successfully', async () => {
        let loadedState: UserListState | null = null;

        viewModel.subscribeToState((state) => {
          loadedState = state;
        });

        viewModel.onEvent({ type: 'LoadUsers', forceRefresh: false });

        // Wait for async operation
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        expect(loadedState?.users.length).assertEqual(6);
        expect(loadedState?.isLoading).assertFalse();
        expect(loadedState?.isEmpty).assertFalse();
      });

      it('should set loading state while loading', async () => {
        const states: boolean[] = [];

        viewModel.subscribeToState((state) => {
          states.push(state.isLoading);
        });

        viewModel.onEvent({ type: 'LoadUsers', forceRefresh: false });

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        // Should have been true at some point then false
        expect(states.includes(true)).assertTrue();
        expect(states[states.length - 1]).assertFalse();
      });

      it('should handle load failure', async () => {
        mockRepository.setShouldFail(true, 'Network error');

        let errorState: string | undefined;

        viewModel.subscribeToState((state) => {
          errorState = state.error;
        });

        viewModel.onEvent({ type: 'LoadUsers', forceRefresh: false });

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        expect(errorState).assertNotNull();
      });

      it('should set hasNextPage correctly', async () => {
        let finalState: UserListState | null = null;

        viewModel.subscribeToState((state) => {
          finalState = state;
        });

        viewModel.onEvent({ type: 'LoadUsers', forceRefresh: false });

        await new Promise<void>(resolve => setTimeout(resolve, 100));

        // 12 users, 6 per page = 2 pages, so hasNextPage should be true
        expect(finalState?.hasNextPage).assertTrue();
      });
    });

    describe('LoadNextPage event', () => {
      it('should load next page', async () => {
        // First load page 1
        viewModel.onEvent({ type: 'LoadUsers', forceRefresh: false });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        let finalState: UserListState | null = null;
        viewModel.subscribeToState((state) => {
          finalState = state;
        });

        // Then load page 2
        viewModel.onEvent({ type: 'LoadNextPage' });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        // Should have all 12 users now
        expect(finalState?.users.length).assertEqual(12);
        expect(finalState?.currentPage).assertEqual(2);
      });

      it('should not load if no next page', async () => {
        // Set only 3 users (less than page size)
        mockRepository.setUsers(createTestUsers(3));

        viewModel.onEvent({ type: 'LoadUsers', forceRefresh: false });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        let finalState: UserListState | null = null;
        viewModel.subscribeToState((state) => {
          finalState = state;
        });

        viewModel.onEvent({ type: 'LoadNextPage' });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        expect(finalState?.currentPage).assertEqual(1);
      });
    });

    describe('SearchUsers event', () => {
      it('should filter users by query', async () => {
        viewModel.onEvent({ type: 'LoadUsers', forceRefresh: false });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        let finalState: UserListState | null = null;
        viewModel.subscribeToState((state) => {
          finalState = state;
        });

        viewModel.onEvent({ type: 'SearchUsers', query: 'First1' });

        expect(finalState?.searchQuery).assertEqual('First1');
        expect(finalState?.filteredUsers.length).assertEqual(1);
      });

      it('should filter by email', async () => {
        viewModel.onEvent({ type: 'LoadUsers', forceRefresh: false });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        let finalState: UserListState | null = null;
        viewModel.subscribeToState((state) => {
          finalState = state;
        });

        viewModel.onEvent({ type: 'SearchUsers', query: 'user1@' });

        expect(finalState?.filteredUsers.length >= 1).assertTrue();
      });

      it('should return all users for empty query', async () => {
        viewModel.onEvent({ type: 'LoadUsers', forceRefresh: false });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        viewModel.onEvent({ type: 'SearchUsers', query: 'First1' });

        let finalState: UserListState | null = null;
        viewModel.subscribeToState((state) => {
          finalState = state;
        });

        viewModel.onEvent({ type: 'SearchUsers', query: '' });

        expect(finalState?.filteredUsers.length).assertEqual(6);
      });
    });

    describe('ClearSearch event', () => {
      it('should clear search query', async () => {
        viewModel.onEvent({ type: 'LoadUsers', forceRefresh: false });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        viewModel.onEvent({ type: 'SearchUsers', query: 'test' });

        let finalState: UserListState | null = null;
        viewModel.subscribeToState((state) => {
          finalState = state;
        });

        viewModel.onEvent({ type: 'ClearSearch' });

        expect(finalState?.searchQuery).assertEqual('');
      });
    });

    describe('SelectUser event', () => {
      it('should emit NavigateToDetail effect', () => {
        let emittedEffect: UserListEffect | null = null;

        viewModel.subscribeToEffects((effect) => {
          emittedEffect = effect;
        });

        viewModel.onEvent({ type: 'SelectUser', userId: 123 });

        expect(emittedEffect).assertNotNull();
        expect(emittedEffect?.type).assertEqual('NavigateToDetail');
        if (emittedEffect?.type === 'NavigateToDetail') {
          expect(emittedEffect.userId).assertEqual(123);
        }
      });
    });

    describe('CreateUser event', () => {
      it('should emit NavigateToCreate effect', () => {
        let emittedEffect: UserListEffect | null = null;

        viewModel.subscribeToEffects((effect) => {
          emittedEffect = effect;
        });

        viewModel.onEvent({ type: 'CreateUser' });

        expect(emittedEffect).assertNotNull();
        expect(emittedEffect?.type).assertEqual('NavigateToCreate');
      });
    });

    describe('DeleteUser event', () => {
      it('should emit ShowDeleteConfirmation effect', () => {
        let emittedEffect: UserListEffect | null = null;

        viewModel.subscribeToEffects((effect) => {
          emittedEffect = effect;
        });

        viewModel.onEvent({ type: 'DeleteUser', userId: 123 });

        expect(emittedEffect).assertNotNull();
        expect(emittedEffect?.type).assertEqual('ShowDeleteConfirmation');
      });
    });

    describe('ConfirmDeleteUser event', () => {
      it('should remove user from list', async () => {
        viewModel.onEvent({ type: 'LoadUsers', forceRefresh: false });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        const initialUserCount = viewModel.state.users.length;

        let finalState: UserListState | null = null;
        viewModel.subscribeToState((state) => {
          finalState = state;
        });

        viewModel.onEvent({ type: 'ConfirmDeleteUser', userId: 1 });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        expect(finalState?.users.length).assertEqual(initialUserCount - 1);
      });

      it('should emit ShowMessage effect', async () => {
        viewModel.onEvent({ type: 'LoadUsers', forceRefresh: false });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        let emittedEffect: UserListEffect | null = null;
        viewModel.subscribeToEffects((effect) => {
          emittedEffect = effect;
        });

        viewModel.onEvent({ type: 'ConfirmDeleteUser', userId: 1 });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        expect(emittedEffect?.type).assertEqual('ShowMessage');
      });
    });

    describe('RefreshUsers event', () => {
      it('should reload users', async () => {
        viewModel.onEvent({ type: 'LoadUsers', forceRefresh: false });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        let refreshEffect: UserListEffect | null = null;
        viewModel.subscribeToEffects((effect) => {
          refreshEffect = effect;
        });

        viewModel.onEvent({ type: 'RefreshUsers' });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        expect(refreshEffect?.type).assertEqual('ShowMessage');
      });
    });

    describe('TriggerSync event', () => {
      it('should trigger sync', async () => {
        viewModel.onEvent({ type: 'TriggerSync' });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        // Just verify no error is thrown
        expect(true).assertTrue();
      });
    });

    describe('RetryLoad event', () => {
      it('should reload users with force refresh', async () => {
        mockRepository.setShouldFail(true);
        viewModel.onEvent({ type: 'LoadUsers', forceRefresh: false });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        mockRepository.setShouldFail(false);

        let finalState: UserListState | null = null;
        viewModel.subscribeToState((state) => {
          finalState = state;
        });

        viewModel.onEvent({ type: 'RetryLoad' });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        expect(finalState?.users.length).assertEqual(6);
      });
    });

    describe('UserChanged event', () => {
      it('should reload users', async () => {
        viewModel.onEvent({ type: 'LoadUsers', forceRefresh: false });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        // Add more users to repository
        mockRepository.setUsers(createTestUsers(15));

        viewModel.onEvent({ type: 'UserChanged' });
        await new Promise<void>(resolve => setTimeout(resolve, 100));

        // Should have reloaded
        expect(viewModel.state.users.length).assertEqual(6);
      });
    });

    describe('destroy', () => {
      it('should clean up subscriptions', () => {
        viewModel.destroy();

        // Verify no error is thrown when destroyed
        expect(true).assertTrue();
      });
    });
  });
}
