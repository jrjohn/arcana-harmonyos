import { BaseViewModel, BaseInput, BaseState, BaseEffect } from './BaseViewModel';
import { User, PaginatedUsers } from '../../domain/models/User';
import { UserRepositoryImpl } from '../../data/repository/UserRepositoryImpl';
import { Success, Failure } from '../../domain/models/Result';
import { AppError } from '../../domain/models/AppError';
import { SyncManager, SyncState, SyncUnsubscribeCallback } from '../../core/sync/SyncManager';
import { AnalyticsService, AnalyticsTimingCallback, AnalyticsProps } from '../../core/analytics/AnalyticsService';
import { NetworkMonitor, NetworkStatus, UnsubscribeCallback } from '../../core/network/NetworkMonitor';
import { Logger } from '../../core/logging/Logger';

const TAG = 'UserListViewModel';

// ===== Input Events =====

export interface LoadUsersInput extends BaseInput {
  type: 'LoadUsers';
  forceRefresh: boolean;
}

export interface LoadNextPageInput extends BaseInput {
  type: 'LoadNextPage';
}

export interface RefreshUsersInput extends BaseInput {
  type: 'RefreshUsers';
}

export interface SearchUsersInput extends BaseInput {
  type: 'SearchUsers';
  query: string;
}

export interface ClearSearchInput extends BaseInput {
  type: 'ClearSearch';
}

export interface SelectUserInput extends BaseInput {
  type: 'SelectUser';
  userId: number;
}

export interface CreateUserInput extends BaseInput {
  type: 'CreateUser';
}

export interface DeleteUserInput extends BaseInput {
  type: 'DeleteUser';
  userId: number;
}

export interface TriggerSyncInput extends BaseInput {
  type: 'TriggerSync';
}

export interface RetryLoadInput extends BaseInput {
  type: 'RetryLoad';
}

export type UserListInput =
  | LoadUsersInput
  | LoadNextPageInput
  | RefreshUsersInput
  | SearchUsersInput
  | ClearSearchInput
  | SelectUserInput
  | CreateUserInput
  | DeleteUserInput
  | TriggerSyncInput
  | RetryLoadInput;

// ===== State =====

export interface UserListState extends BaseState {
  users: User[];
  currentPage: number;
  totalPages: number;
  hasNextPage: boolean;
  isLoadingMore: boolean;
  searchQuery: string;
  filteredUsers: User[];
  isOffline: boolean;
  syncState: SyncState;
  isEmpty: boolean;
}

// ===== Effects =====

export interface NavigateToDetailEffect extends BaseEffect {
  type: 'NavigateToDetail';
  userId: number;
}

export interface NavigateToCreateEffect extends BaseEffect {
  type: 'NavigateToCreate';
}

export interface ShowDeleteConfirmationEffect extends BaseEffect {
  type: 'ShowDeleteConfirmation';
  userId: number;
}

export interface ShowMessageEffect extends BaseEffect {
  type: 'ShowMessage';
  message: string;
}

export interface ShowErrorEffect extends BaseEffect {
  type: 'ShowError';
  message: string;
}

export type UserListEffect =
  | NavigateToDetailEffect
  | NavigateToCreateEffect
  | ShowDeleteConfirmationEffect
  | ShowMessageEffect
  | ShowErrorEffect;

/**
 * ViewModel for the User List screen.
 * Implements the Input/Output pattern for clean separation.
 */
export class UserListViewModel extends BaseViewModel<UserListInput, UserListState, UserListEffect> {
  private repository: UserRepositoryImpl;
  private syncManager: SyncManager;
  private analytics: AnalyticsService;
  private networkUnsubscribe: UnsubscribeCallback | null = null;
  private syncUnsubscribe: SyncUnsubscribeCallback | null = null;

  constructor(
    repository: UserRepositoryImpl,
    syncManager: SyncManager,
    analytics: AnalyticsService
  ) {
    super({
      isLoading: false,
      error: undefined,
      users: [],
      currentPage: 1,
      totalPages: 1,
      hasNextPage: false,
      isLoadingMore: false,
      searchQuery: '',
      filteredUsers: [],
      isOffline: false,
      syncState: syncManager.getState(),
      isEmpty: true
    });

    this.repository = repository;
    this.syncManager = syncManager;
    this.analytics = analytics;

    this.setupSubscriptions();
    Logger.d(TAG, 'UserListViewModel created');
  }

  /**
   * Sets up network and sync subscriptions
   */
  private setupSubscriptions(): void {
    // Subscribe to network changes
    this.networkUnsubscribe = NetworkMonitor.subscribe((state) => {
      const wasOffline = this._state.isOffline;
      this._state.isOffline = state.status !== NetworkStatus.AVAILABLE;
      this.notifyStateChangeInternal();

      // Auto-refresh when coming online
      if (state.status === NetworkStatus.AVAILABLE && wasOffline) {
        this.onEvent({ type: 'RefreshUsers' });
      }
    });

    // Subscribe to sync state changes
    this.syncUnsubscribe = this.syncManager.subscribe((state) => {
      this._state.syncState = state;
      this.notifyStateChangeInternal();
    });
  }

  /**
   * Internal state change notification
   */
  private notifyStateChangeInternal(): void {
    // This is a workaround since we can't use object spread
    this.replaceState(this.copyCurrentState());
  }

  /**
   * Creates a copy of the current state
   */
  private copyCurrentState(): UserListState {
    const copy: UserListState = {
      isLoading: this._state.isLoading,
      error: this._state.error,
      users: this._state.users,
      currentPage: this._state.currentPage,
      totalPages: this._state.totalPages,
      hasNextPage: this._state.hasNextPage,
      isLoadingMore: this._state.isLoadingMore,
      searchQuery: this._state.searchQuery,
      filteredUsers: this._state.filteredUsers,
      isOffline: this._state.isOffline,
      syncState: this._state.syncState,
      isEmpty: this._state.isEmpty
    };
    return copy;
  }

  /**
   * Implementation of abstract updateState
   */
  protected updateState(state: UserListState): void {
    this.setStateDirectly(state);
  }

  /**
   * Sets loading state
   */
  protected setLoading(isLoading: boolean): void {
    this._state.isLoading = isLoading;
    this.notifyStateChangeInternal();
  }

  /**
   * Sets error state
   */
  protected setError(error: string | undefined): void {
    this._state.error = error;
    this._state.isLoading = false;
    this.notifyStateChangeInternal();
  }

  /**
   * Clears error state
   */
  protected clearError(): void {
    this._state.error = undefined;
    this.notifyStateChangeInternal();
  }

  /**
   * Updates multiple state fields
   */
  private updateMultipleFields(updates: Partial<UserListState>): void {
    if (updates.isLoading !== undefined) this._state.isLoading = updates.isLoading;
    if (updates.error !== undefined) this._state.error = updates.error;
    if (updates.users !== undefined) this._state.users = updates.users;
    if (updates.currentPage !== undefined) this._state.currentPage = updates.currentPage;
    if (updates.totalPages !== undefined) this._state.totalPages = updates.totalPages;
    if (updates.hasNextPage !== undefined) this._state.hasNextPage = updates.hasNextPage;
    if (updates.isLoadingMore !== undefined) this._state.isLoadingMore = updates.isLoadingMore;
    if (updates.searchQuery !== undefined) this._state.searchQuery = updates.searchQuery;
    if (updates.filteredUsers !== undefined) this._state.filteredUsers = updates.filteredUsers;
    if (updates.isOffline !== undefined) this._state.isOffline = updates.isOffline;
    if (updates.syncState !== undefined) this._state.syncState = updates.syncState;
    if (updates.isEmpty !== undefined) this._state.isEmpty = updates.isEmpty;
    this.notifyStateChangeInternal();
  }

  /**
   * Handles input events
   */
  onEvent(input: UserListInput): void {
    Logger.d(TAG, `Received event: ${input.type}`);

    switch (input.type) {
      case 'LoadUsers':
        this.loadUsers(input.forceRefresh);
        break;

      case 'LoadNextPage':
        this.loadNextPage();
        break;

      case 'RefreshUsers':
        this.refreshUsers();
        break;

      case 'SearchUsers':
        this.searchUsers(input.query);
        break;

      case 'ClearSearch':
        this.clearSearch();
        break;

      case 'SelectUser':
        this.selectUser(input.userId);
        break;

      case 'CreateUser':
        this.navigateToCreate();
        break;

      case 'DeleteUser':
        this.confirmDelete(input.userId);
        break;

      case 'TriggerSync':
        this.triggerSync();
        break;

      case 'RetryLoad':
        this.loadUsers(true);
        break;
    }
  }

  /**
   * Loads users from repository
   */
  private async loadUsers(forceRefresh: boolean): Promise<void> {
    if (this._state.isLoading) return;

    this.setLoading(true);
    this.clearError();
    const props = AnalyticsProps.of('force_refresh', forceRefresh);
    this.analytics.trackEvent('load_users', props);

    const timing = this.analytics.startTiming('load_users');

    const result = await this.repository.getUsers(1, forceRefresh);

    timing.end();

    if (result.isSuccess) {
      const successResult = result as Success<PaginatedUsers>;
      const paginated = successResult.value;
      this._state.isLoading = false;
      this._state.users = paginated.users;
      this._state.filteredUsers = paginated.users;
      this._state.currentPage = paginated.page;
      this._state.totalPages = paginated.totalPages;
      this._state.hasNextPage = paginated.page < paginated.totalPages;
      this._state.isEmpty = paginated.users.length === 0;
      this.notifyStateChangeInternal();
      Logger.d(TAG, `Loaded ${paginated.users.length} users`);
    } else {
      const failureResult = result as Failure<AppError>;
      this.setError(failureResult.error.userMessage);
      this.analytics.trackError(failureResult.error.code, failureResult.error.message);
    }
  }

  /**
   * Loads the next page of users
   */
  private async loadNextPage(): Promise<void> {
    if (this._state.isLoadingMore || !this._state.hasNextPage) return;

    this._state.isLoadingMore = true;
    this.notifyStateChangeInternal();

    const nextPage = this._state.currentPage + 1;
    const props = AnalyticsProps.of('page', nextPage);
    this.analytics.trackEvent('load_next_page', props);

    const result = await this.repository.getUsers(nextPage);

    if (result.isSuccess) {
      const successResult = result as Success<PaginatedUsers>;
      const paginated = successResult.value;
      const allUsers: User[] = [];
      for (const u of this._state.users) {
        allUsers.push(u);
      }
      for (const u of paginated.users) {
        allUsers.push(u);
      }

      this._state.isLoadingMore = false;
      this._state.users = allUsers;
      this._state.filteredUsers = this._state.searchQuery ? this.filterUsers(allUsers, this._state.searchQuery) : allUsers;
      this._state.currentPage = paginated.page;
      this._state.hasNextPage = paginated.page < paginated.totalPages;
      this.notifyStateChangeInternal();

      Logger.d(TAG, `Loaded page ${nextPage}, total users: ${allUsers.length}`);
    } else {
      const failureResult = result as Failure<AppError>;
      this._state.isLoadingMore = false;
      this.notifyStateChangeInternal();
      const errorEffect: ShowErrorEffect = { type: 'ShowError', message: failureResult.error.userMessage };
      this.emitEffect(errorEffect);
    }
  }

  /**
   * Refreshes users (pull-to-refresh)
   */
  private async refreshUsers(): Promise<void> {
    this.analytics.trackEvent('refresh_users');
    await this.loadUsers(true);
    const messageEffect: ShowMessageEffect = { type: 'ShowMessage', message: 'Users refreshed' };
    this.emitEffect(messageEffect);
  }

  /**
   * Searches users by query
   */
  private searchUsers(query: string): void {
    const trimmedQuery = query.trim();
    this._state.searchQuery = trimmedQuery;
    this._state.filteredUsers = trimmedQuery ? this.filterUsers(this._state.users, trimmedQuery) : this._state.users;
    this.notifyStateChangeInternal();

    if (trimmedQuery) {
      const props = AnalyticsProps.of('query_length', trimmedQuery.length);
      this.analytics.trackEvent('search_users', props);
    }
  }

  /**
   * Filters users by search query
   */
  private filterUsers(users: User[], query: string): User[] {
    const lowerQuery = query.toLowerCase();
    return users.filter(user =>
      user.firstName.toLowerCase().includes(lowerQuery) ||
      user.lastName.toLowerCase().includes(lowerQuery) ||
      user.email.toLowerCase().includes(lowerQuery)
    );
  }

  /**
   * Clears search
   */
  private clearSearch(): void {
    this._state.searchQuery = '';
    this._state.filteredUsers = this._state.users;
    this.notifyStateChangeInternal();
  }

  /**
   * Navigates to user detail
   */
  private selectUser(userId: number): void {
    this.analytics.trackAction('select_user', `user_${userId}`);
    const effect: NavigateToDetailEffect = { type: 'NavigateToDetail', userId: userId };
    this.emitEffect(effect);
  }

  /**
   * Navigates to create user
   */
  private navigateToCreate(): void {
    this.analytics.trackAction('create_user_clicked', 'fab');
    const effect: NavigateToCreateEffect = { type: 'NavigateToCreate' };
    this.emitEffect(effect);
  }

  /**
   * Shows delete confirmation
   */
  private confirmDelete(userId: number): void {
    this.analytics.trackAction('delete_user_clicked', `user_${userId}`);
    const effect: ShowDeleteConfirmationEffect = { type: 'ShowDeleteConfirmation', userId: userId };
    this.emitEffect(effect);
  }

  /**
   * Triggers manual sync
   */
  private async triggerSync(): Promise<void> {
    this.analytics.trackEvent('manual_sync_triggered');
    await this.syncManager.triggerSync();
  }

  /**
   * Called when a user is deleted (from outside)
   */
  async onUserDeleted(userId: number): Promise<void> {
    // Remove from local list
    const updatedUsers: User[] = [];
    for (const u of this._state.users) {
      if (u.id !== userId) {
        updatedUsers.push(u);
      }
    }
    this._state.users = updatedUsers;
    this._state.filteredUsers = this._state.searchQuery
      ? this.filterUsers(updatedUsers, this._state.searchQuery)
      : updatedUsers;
    this._state.isEmpty = updatedUsers.length === 0;
    this.notifyStateChangeInternal();

    const effect: ShowMessageEffect = { type: 'ShowMessage', message: 'User deleted' };
    this.emitEffect(effect);
  }

  /**
   * Called when a user is created or updated (from outside)
   */
  async onUserChanged(): Promise<void> {
    // Refresh the list
    await this.loadUsers(true);
  }

  /**
   * Cleanup
   */
  destroy(): void {
    if (this.networkUnsubscribe) {
      this.networkUnsubscribe.unsubscribe();
    }
    if (this.syncUnsubscribe) {
      this.syncUnsubscribe.unsubscribe();
    }
    super.destroy();
  }
}
