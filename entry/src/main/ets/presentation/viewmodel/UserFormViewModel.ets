import { BaseViewModel, BaseState, BaseEffect } from './BaseViewModel';
import { User, CreateUserRequest, UpdateUserRequest } from '../../domain/models/User';
import { IUserRepositoryService, IAnalyticsService, AnalyticsProps } from '../../core/di/interfaces';
import { UserValidator, UserValidationResult } from '../../domain/validators/UserValidator';
import { Success, Failure } from '../../domain/models/Result';
import { AppError } from '../../domain/models/AppError';
import { Logger } from '../../core/logging/Logger';

const TAG = 'UserFormViewModel';

// ===== Input Events =====

export interface LoadUserFormInput {
  type: 'LoadUser';
  userId: number;
}

export interface UpdateFirstNameInput {
  type: 'UpdateFirstName';
  value: string;
}

export interface UpdateLastNameInput {
  type: 'UpdateLastName';
  value: string;
}

export interface UpdateEmailInput {
  type: 'UpdateEmail';
  value: string;
}

export interface UpdateAvatarInput {
  type: 'UpdateAvatar';
  value: string;
}

export interface ValidateFieldInput {
  type: 'ValidateField';
  field: 'firstName' | 'lastName' | 'email';
}

export interface ValidateAllInput {
  type: 'ValidateAll';
}

export interface SubmitInput {
  type: 'Submit';
}

export interface CancelInput {
  type: 'Cancel';
}

export type UserFormInput =
  | LoadUserFormInput
  | UpdateFirstNameInput
  | UpdateLastNameInput
  | UpdateEmailInput
  | UpdateAvatarInput
  | ValidateFieldInput
  | ValidateAllInput
  | SubmitInput
  | CancelInput;

// ===== State =====

export interface UserFormState extends BaseState {
  mode: 'create' | 'edit';
  userId: number | undefined;
  firstName: string;
  lastName: string;
  email: string;
  avatar: string;
  firstNameError: string | undefined;
  lastNameError: string | undefined;
  emailError: string | undefined;
  isValid: boolean;
  isSaving: boolean;
  hasChanges: boolean;
  originalUser: User | undefined;
}

// ===== Effects =====

export interface NavigateBackFormEffect extends BaseEffect {
  type: 'NavigateBack';
}

export interface ShowSuccessEffect extends BaseEffect {
  type: 'ShowSuccess';
  message: string;
}

export interface ShowErrorFormEffect extends BaseEffect {
  type: 'ShowError';
  message: string;
}

export interface ShowUnsavedChangesDialogEffect extends BaseEffect {
  type: 'ShowUnsavedChangesDialog';
}

export type UserFormEffect =
  | NavigateBackFormEffect
  | ShowSuccessEffect
  | ShowErrorFormEffect
  | ShowUnsavedChangesDialogEffect;

/**
 * ViewModel for Create and Edit User forms.
 * Handles form validation and submission.
 */
export class UserFormViewModel extends BaseViewModel<UserFormInput, UserFormState, UserFormEffect> {
  private repository: IUserRepositoryService;
  private analytics: IAnalyticsService;

  constructor(
    repository: IUserRepositoryService,
    analytics: IAnalyticsService,
    mode: 'create' | 'edit' = 'create',
    userId?: number
  ) {
    super({
      isLoading: false,
      error: undefined,
      mode,
      userId,
      firstName: '',
      lastName: '',
      email: '',
      avatar: '',
      firstNameError: undefined,
      lastNameError: undefined,
      emailError: undefined,
      isValid: false,
      isSaving: false,
      hasChanges: false,
      originalUser: undefined
    });

    this.repository = repository;
    this.analytics = analytics;

    Logger.d(TAG, `UserFormViewModel created in ${mode} mode`);

    // Load user if editing
    if (mode === 'edit' && userId) {
      const loadInput: LoadUserFormInput = { type: 'LoadUser', userId: userId };
      this.onEvent(loadInput);
    }
  }

  /**
   * Implementation of abstract updateState
   */
  protected updateState(state: UserFormState): void {
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
  private copyCurrentState(): UserFormState {
    const copy: UserFormState = {
      isLoading: this._state.isLoading,
      error: this._state.error,
      mode: this._state.mode,
      userId: this._state.userId,
      firstName: this._state.firstName,
      lastName: this._state.lastName,
      email: this._state.email,
      avatar: this._state.avatar,
      firstNameError: this._state.firstNameError,
      lastNameError: this._state.lastNameError,
      emailError: this._state.emailError,
      isValid: this._state.isValid,
      isSaving: this._state.isSaving,
      hasChanges: this._state.hasChanges,
      originalUser: this._state.originalUser
    };
    return copy;
  }

  /**
   * Handles input events
   */
  onEvent(input: UserFormInput): void {
    Logger.d(TAG, `Received event: ${input.type}`);

    switch (input.type) {
      case 'LoadUser':
        this.loadUser(input.userId);
        break;

      case 'UpdateFirstName':
        this.updateField('firstName', input.value);
        break;

      case 'UpdateLastName':
        this.updateField('lastName', input.value);
        break;

      case 'UpdateEmail':
        this.updateField('email', input.value);
        break;

      case 'UpdateAvatar':
        this.updateField('avatar', input.value);
        break;

      case 'ValidateField':
        this.validateField(input.field);
        break;

      case 'ValidateAll':
        this.validateAll();
        break;

      case 'Submit':
        this.submit();
        break;

      case 'Cancel':
        this.cancel();
        break;
    }
  }

  /**
   * Loads user data for editing
   */
  private async loadUser(userId: number): Promise<void> {
    this.setLoading(true);

    const result = await this.repository.getUser(userId);

    if (result.isSuccess) {
      const successResult = result as Success<User>;
      const user = successResult.value;
      this._state.isLoading = false;
      this._state.firstName = user.firstName;
      this._state.lastName = user.lastName;
      this._state.email = user.email;
      this._state.avatar = user.avatar;
      this._state.originalUser = user;
      this._state.hasChanges = false;
      this.notifyStateChangeInternal();
      Logger.d(TAG, `Loaded user: ${user.email}`);
    } else {
      const failureResult = result as Failure<AppError>;
      this.setError(failureResult.error.userMessage);
      this.analytics.trackError(failureResult.error.code, failureResult.error.message);
    }
  }

  /**
   * Updates a field value
   */
  private updateField(field: 'firstName' | 'lastName' | 'email' | 'avatar', value: string): void {
    // Update the field
    if (field === 'firstName') {
      this._state.firstName = value;
      this._state.firstNameError = undefined;
    } else if (field === 'lastName') {
      this._state.lastName = value;
      this._state.lastNameError = undefined;
    } else if (field === 'email') {
      this._state.email = value;
      this._state.emailError = undefined;
    } else if (field === 'avatar') {
      this._state.avatar = value;
    }
    this._state.hasChanges = true;
    this.notifyStateChangeInternal();
  }

  /**
   * Validates a single field
   */
  private validateField(field: 'firstName' | 'lastName' | 'email'): void {
    let error: string | undefined;

    switch (field) {
      case 'firstName':
        error = UserValidator.validateFirstName(this._state.firstName);
        this._state.firstNameError = error;
        break;

      case 'lastName':
        error = UserValidator.validateLastName(this._state.lastName);
        this._state.lastNameError = error;
        break;

      case 'email':
        error = UserValidator.validateEmail(this._state.email);
        this._state.emailError = error;
        break;
    }

    this.notifyStateChangeInternal();
    this.updateValidState();
  }

  /**
   * Validates all fields
   */
  private validateAll(): UserValidationResult {
    const result = UserValidator.validateUserData(
      this._state.firstName,
      this._state.lastName,
      this._state.email
    );

    this._state.firstNameError = result.firstNameError;
    this._state.lastNameError = result.lastNameError;
    this._state.emailError = result.emailError;
    this._state.isValid = result.isValid;
    this.notifyStateChangeInternal();

    return result;
  }

  /**
   * Updates the overall valid state
   */
  private updateValidState(): void {
    const isValid = !this._state.firstNameError &&
      !this._state.lastNameError &&
      !this._state.emailError &&
      this._state.firstName.length > 0 &&
      this._state.lastName.length > 0 &&
      this._state.email.length > 0;

    this._state.isValid = isValid;
    this.notifyStateChangeInternal();
  }

  /**
   * Submits the form
   */
  private async submit(): Promise<void> {
    // Validate all fields first
    const validation = this.validateAll();
    if (!validation.isValid) {
      const props = AnalyticsProps.of('errors', validation.errors.length);
      this.analytics.trackEvent('form_validation_failed', props);
      return;
    }

    this._state.isSaving = true;
    this.notifyStateChangeInternal();

    const timing = this.analytics.startTiming(
      this._state.mode === 'create' ? 'create_user' : 'update_user'
    );

    try {
      if (this._state.mode === 'create') {
        await this.createUser();
      } else {
        await this.updateUser();
      }
    } finally {
      timing.end();
      this._state.isSaving = false;
      this.notifyStateChangeInternal();
    }
  }

  /**
   * Creates a new user
   */
  private async createUser(): Promise<void> {
    const request: CreateUserRequest = {
      firstName: this._state.firstName.trim(),
      lastName: this._state.lastName.trim(),
      email: this._state.email.trim().toLowerCase(),
      avatar: this._state.avatar !== '' ? this._state.avatar : ''
    };

    const result = await this.repository.createUser(request);

    if (result.isSuccess) {
      const successResult = result as Success<User>;
      const props = AnalyticsProps.of('user_id', successResult.value.id);
      this.analytics.trackEvent('user_created', props);
      const successEffect: ShowSuccessEffect = { type: 'ShowSuccess', message: 'User created successfully' };
      this.emitEffect(successEffect);
      const backEffect: NavigateBackFormEffect = { type: 'NavigateBack' };
      this.emitEffect(backEffect);
    } else {
      const failureResult = result as Failure<AppError>;
      this.analytics.trackError(failureResult.error.code, failureResult.error.message);
      const errorEffect: ShowErrorFormEffect = { type: 'ShowError', message: failureResult.error.userMessage };
      this.emitEffect(errorEffect);
    }
  }

  /**
   * Updates an existing user
   */
  private async updateUser(): Promise<void> {
    if (!this._state.userId) return;

    const request: UpdateUserRequest = {
      id: this._state.userId,
      firstName: this._state.firstName.trim(),
      lastName: this._state.lastName.trim(),
      email: this._state.email.trim().toLowerCase(),
      avatar: this._state.avatar !== '' ? this._state.avatar : ''
    };

    const result = await this.repository.updateUser(request);

    if (result.isSuccess) {
      const successResult = result as Success<User>;
      const updateProps = AnalyticsProps.of('user_id', successResult.value.id);
      this.analytics.trackEvent('user_updated', updateProps);
      const successEffect: ShowSuccessEffect = { type: 'ShowSuccess', message: 'User updated successfully' };
      this.emitEffect(successEffect);
      const backEffect: NavigateBackFormEffect = { type: 'NavigateBack' };
      this.emitEffect(backEffect);
    } else {
      const failureResult = result as Failure<AppError>;
      this.analytics.trackError(failureResult.error.code, failureResult.error.message);
      const errorEffect: ShowErrorFormEffect = { type: 'ShowError', message: failureResult.error.userMessage };
      this.emitEffect(errorEffect);
    }
  }

  /**
   * Cancels the form
   */
  private cancel(): void {
    if (this._state.hasChanges) {
      const dialogEffect: ShowUnsavedChangesDialogEffect = { type: 'ShowUnsavedChangesDialog' };
      this.emitEffect(dialogEffect);
    } else {
      const backEffect: NavigateBackFormEffect = { type: 'NavigateBack' };
      this.emitEffect(backEffect);
    }
  }

  /**
   * Checks if form has unsaved changes
   */
  hasUnsavedChanges(): boolean {
    if (this._state.mode === 'create') {
      return this._state.firstName.length > 0 ||
        this._state.lastName.length > 0 ||
        this._state.email.length > 0;
    }

    const original = this._state.originalUser;
    if (!original) return false;

    return this._state.firstName !== original.firstName ||
      this._state.lastName !== original.lastName ||
      this._state.email !== original.email ||
      this._state.avatar !== original.avatar;
  }
}
