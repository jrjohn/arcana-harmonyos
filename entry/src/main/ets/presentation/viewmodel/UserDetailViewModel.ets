import { BaseViewModel, BaseState, BaseEffect } from './BaseViewModel';
import { User } from '../../domain/models/User';
import { IAnalyticsService, AnalyticsProps } from '../../core/di/interfaces';
import { IUserService } from '../../domain/services/UserService';
import { Success, Failure } from '../../domain/models/Result';
import { AppError } from '../../domain/models/AppError';
import { Logger } from '../../core/logging/Logger';

const TAG = 'UserDetailViewModel';

// ===== Input Events =====

export interface LoadUserInput {
  type: 'LoadUser';
  userId: number;
}

export interface RefreshUserInput {
  type: 'RefreshUser';
}

export interface EditUserInput {
  type: 'EditUser';
}

export interface DeleteUserInput {
  type: 'DeleteUser';
}

export interface ConfirmDeleteInput {
  type: 'ConfirmDelete';
}

export interface CancelDeleteInput {
  type: 'CancelDelete';
}

export interface NavigateBackInput {
  type: 'NavigateBack';
}

export interface UserUpdatedInput {
  type: 'UserUpdated';
}

export type UserDetailInput =
  | LoadUserInput
  | RefreshUserInput
  | EditUserInput
  | DeleteUserInput
  | ConfirmDeleteInput
  | CancelDeleteInput
  | NavigateBackInput
  | UserUpdatedInput;

// ===== State =====

export interface UserDetailState extends BaseState {
  user: User | undefined;
  userId: number;
  isDeleting: boolean;
  showDeleteConfirmation: boolean;
}

// ===== Effects =====

export interface NavigateBackEffect extends BaseEffect {
  type: 'NavigateBack';
}

export interface NavigateToEditEffect extends BaseEffect {
  type: 'NavigateToEdit';
  userId: number;
}

export interface ShowMessageDetailEffect extends BaseEffect {
  type: 'ShowMessage';
  message: string;
}

export interface ShowErrorDetailEffect extends BaseEffect {
  type: 'ShowError';
  message: string;
}

export interface UserDeletedEffect extends BaseEffect {
  type: 'UserDeleted';
}

export type UserDetailEffect =
  | NavigateBackEffect
  | NavigateToEditEffect
  | ShowMessageDetailEffect
  | ShowErrorDetailEffect
  | UserDeletedEffect;

/**
 * ViewModel for the User Detail screen.
 */
export class UserDetailViewModel extends BaseViewModel<UserDetailInput, UserDetailState, UserDetailEffect> {
  private userService: IUserService;
  private analytics: IAnalyticsService;

  constructor(
    userService: IUserService,
    analytics: IAnalyticsService,
    userId: number
  ) {
    super({
      isLoading: false,
      error: undefined,
      user: undefined,
      userId,
      isDeleting: false,
      showDeleteConfirmation: false
    });

    this.userService = userService;
    this.analytics = analytics;

    Logger.d(TAG, `UserDetailViewModel created for user ${userId}`);

    // Load user on init
    const loadInput: LoadUserInput = { type: 'LoadUser', userId: userId };
    this.onEvent(loadInput);
  }

  /**
   * Implementation of abstract updateState
   */
  protected updateState(state: UserDetailState): void {
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
   * Internal state change notification
   */
  private notifyStateChangeInternal(): void {
    this.replaceState(this.copyCurrentState());
  }

  /**
   * Creates a copy of the current state
   */
  private copyCurrentState(): UserDetailState {
    const copy: UserDetailState = {
      isLoading: this._state.isLoading,
      error: this._state.error,
      user: this._state.user,
      userId: this._state.userId,
      isDeleting: this._state.isDeleting,
      showDeleteConfirmation: this._state.showDeleteConfirmation
    };
    return copy;
  }

  /**
   * Handles input events
   */
  onEvent(input: UserDetailInput): void {
    Logger.d(TAG, `Received event: ${input.type}`);

    switch (input.type) {
      case 'LoadUser':
        this.loadUser(input.userId);
        break;

      case 'RefreshUser':
        this.refreshUser();
        break;

      case 'EditUser':
        this.editUser();
        break;

      case 'DeleteUser':
        this.showDeleteConfirmation();
        break;

      case 'ConfirmDelete':
        this.confirmDelete();
        break;

      case 'CancelDelete':
        this.cancelDelete();
        break;

      case 'NavigateBack':
        this.navigateBack();
        break;

      case 'UserUpdated':
        this.handleUserUpdated();
        break;
    }
  }

  /**
   * Loads user data
   */
  private async loadUser(userId: number): Promise<void> {
    this.setLoading(true);
    this.clearError();

    const timing = this.analytics.startTiming('load_user_detail');

    const result = await this.userService.getUserById(userId);

    timing.end();

    if (result.isSuccess) {
      const successResult = result as Success<User>;
      this._state.isLoading = false;
      this._state.user = successResult.value;
      this.notifyStateChangeInternal();
      Logger.d(TAG, `Loaded user: ${successResult.value.email}`);
    } else {
      const failureResult = result as Failure<AppError>;
      this.setError(failureResult.error.userMessage);
      this.analytics.trackError(failureResult.error.code, failureResult.error.message);
    }
  }

  /**
   * Refreshes user data
   */
  private async refreshUser(): Promise<void> {
    this.analytics.trackEvent('refresh_user_detail');
    await this.loadUser(this._state.userId);
  }

  /**
   * Navigates to edit screen
   */
  private editUser(): void {
    this.analytics.trackAction('edit_user_clicked', `user_${this._state.userId}`);
    const effect: NavigateToEditEffect = { type: 'NavigateToEdit', userId: this._state.userId };
    this.emitEffect(effect);
  }

  /**
   * Shows delete confirmation dialog
   */
  private showDeleteConfirmation(): void {
    this.analytics.trackAction('delete_user_clicked', `user_${this._state.userId}`);
    this._state.showDeleteConfirmation = true;
    this.notifyStateChangeInternal();
  }

  /**
   * Confirms and executes delete
   */
  private async confirmDelete(): Promise<void> {
    this._state.showDeleteConfirmation = false;
    this._state.isDeleting = true;
    this.notifyStateChangeInternal();

    const timing = this.analytics.startTiming('delete_user');

    const result = await this.userService.deleteUser(this._state.userId);

    timing.end();

    if (result.isSuccess) {
      const props = AnalyticsProps.of('user_id', this._state.userId);
      this.analytics.trackEvent('user_deleted', props);
      const msgEffect: ShowMessageDetailEffect = { type: 'ShowMessage', message: 'User deleted successfully' };
      this.emitEffect(msgEffect);
      const deletedEffect: UserDeletedEffect = { type: 'UserDeleted' };
      this.emitEffect(deletedEffect);
      const backEffect: NavigateBackEffect = { type: 'NavigateBack' };
      this.emitEffect(backEffect);
    } else {
      const failureResult = result as Failure<AppError>;
      this._state.isDeleting = false;
      this.notifyStateChangeInternal();
      this.analytics.trackError(failureResult.error.code, failureResult.error.message);
      const errEffect: ShowErrorDetailEffect = { type: 'ShowError', message: failureResult.error.userMessage };
      this.emitEffect(errEffect);
    }
  }

  /**
   * Cancels delete operation
   */
  private cancelDelete(): void {
    this._state.showDeleteConfirmation = false;
    this.notifyStateChangeInternal();
  }

  /**
   * Navigates back
   */
  private navigateBack(): void {
    const effect: NavigateBackEffect = { type: 'NavigateBack' };
    this.emitEffect(effect);
  }

  /**
   * Handles user updated notification (via Input event)
   */
  private async handleUserUpdated(): Promise<void> {
    await this.loadUser(this._state.userId);
  }
}
