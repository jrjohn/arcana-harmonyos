import { BaseViewModel, BaseInput, BaseState, BaseEffect } from './BaseViewModel';
import { User, PaginatedUsers } from '../../domain/models/User';
import { IAnalyticsService } from '../../core/di/interfaces';
import { IUserService } from '../../domain/services/UserService';
import { Success, Failure } from '../../domain/models/Result';
import { AppError } from '../../domain/models/AppError';
import { Logger } from '../../core/logging/Logger';

const TAG = 'HomeViewModel';

// ===== Input Events =====

export interface LoadDataInput extends BaseInput {
  type: 'LoadData';
}

export interface NavigateToUsersInput extends BaseInput {
  type: 'NavigateToUsers';
}

export interface RefreshInput extends BaseInput {
  type: 'Refresh';
}

export type HomeInput =
  | LoadDataInput
  | NavigateToUsersInput
  | RefreshInput;

// ===== State =====

export interface HomeState extends BaseState {
  totalUserCount: number;
  loadedUserCount: number;
  users: User[];
}

// ===== Effects =====

export interface NavigateToUsersEffect extends BaseEffect {
  type: 'NavigateToUsers';
}

export interface ShowErrorEffect extends BaseEffect {
  type: 'ShowError';
  message: string;
}

export type HomeEffect =
  | NavigateToUsersEffect
  | ShowErrorEffect;

/**
 * ViewModel for the Home screen.
 * Implements the Input/Output pattern for clean separation.
 */
export class HomeViewModel extends BaseViewModel<HomeInput, HomeState, HomeEffect> {
  private userService: IUserService;
  private analytics: IAnalyticsService;

  constructor(
    userService: IUserService,
    analytics: IAnalyticsService
  ) {
    super({
      isLoading: true,
      error: undefined,
      totalUserCount: 0,
      loadedUserCount: 0,
      users: []
    });

    this.userService = userService;
    this.analytics = analytics;

    Logger.d(TAG, 'HomeViewModel created');
  }

  /**
   * Creates a copy of the current state
   */
  private copyCurrentState(): HomeState {
    const copy: HomeState = {
      isLoading: this._state.isLoading,
      error: this._state.error,
      totalUserCount: this._state.totalUserCount,
      loadedUserCount: this._state.loadedUserCount,
      users: this._state.users
    };
    return copy;
  }

  /**
   * Internal state change notification
   */
  private notifyStateChangeInternal(): void {
    this.replaceState(this.copyCurrentState());
  }

  /**
   * Implementation of abstract updateState
   */
  protected updateState(state: HomeState): void {
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
   * Handles input events
   */
  onEvent(input: HomeInput): void {
    Logger.d(TAG, `Received event: ${input.type}`);

    switch (input.type) {
      case 'LoadData':
        this.loadData();
        break;

      case 'NavigateToUsers':
        this.navigateToUsers();
        break;

      case 'Refresh':
        this.loadData();
        break;
    }
  }

  /**
   * Loads user data for the home screen
   */
  private async loadData(): Promise<void> {
    this.setLoading(true);
    this.clearError();

    this.analytics.trackEvent('home_load_data');

    const timing = this.analytics.startTiming('home_load_data');

    const result = await this.userService.getUsers(1, false);

    timing.end();

    if (result.isSuccess) {
      const successResult = result as Success<PaginatedUsers>;
      const paginated = successResult.value;

      this._state.isLoading = false;
      this._state.users = paginated.users;
      this._state.loadedUserCount = paginated.users.length;
      this._state.totalUserCount = paginated.total;
      this.notifyStateChangeInternal();

      Logger.d(TAG, `Loaded ${paginated.users.length} users, total: ${paginated.total}`);
    } else {
      const failureResult = result as Failure<AppError>;
      this.setError(failureResult.error.userMessage);
      this.analytics.trackError(failureResult.error.code, failureResult.error.message);
    }
  }

  /**
   * Navigates to user list
   */
  private navigateToUsers(): void {
    this.analytics.trackAction('navigate_to_users', 'home_button');
    const effect: NavigateToUsersEffect = { type: 'NavigateToUsers' };
    this.emitEffect(effect);
  }
}
