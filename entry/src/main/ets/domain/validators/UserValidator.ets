import { CreateUserRequest, UpdateUserRequest } from '../models/User';
import { Result, Success, Failure } from '../models/Result';
import { EmailValidator, EmailValidationError } from './EmailValidator';
import { NameValidator, NameValidationError } from './NameValidator';

/**
 * Field-level validation error
 */
export interface FieldError {
  readonly field: string;
  readonly message: string;
}

/**
 * Complete validation result for user forms
 */
export interface UserValidationResult {
  readonly isValid: boolean;
  readonly errors: FieldError[];
  readonly firstNameError?: string;
  readonly lastNameError?: string;
  readonly emailError?: string;
}

/**
 * Validated user data ready for submission
 */
export interface ValidatedUserData {
  readonly firstName: string;
  readonly lastName: string;
  readonly email: string;
  readonly avatar: string;
}

/**
 * Comprehensive user validator that validates all user input fields.
 * Provides both individual field validation and complete form validation.
 */
export class UserValidator {

  /**
   * Validates a complete create user request
   */
  static validateCreateRequest(request: CreateUserRequest): UserValidationResult {
    return UserValidator.validateUserData(
      request.firstName,
      request.lastName,
      request.email
    );
  }

  /**
   * Validates a complete update user request
   */
  static validateUpdateRequest(request: UpdateUserRequest): UserValidationResult {
    return UserValidator.validateUserData(
      request.firstName,
      request.lastName,
      request.email
    );
  }

  /**
   * Validates all user fields and returns detailed result
   */
  static validateUserData(
    firstName: string | null | undefined,
    lastName: string | null | undefined,
    email: string | null | undefined
  ): UserValidationResult {
    const errors: FieldError[] = [];
    let firstNameError: string | undefined;
    let lastNameError: string | undefined;
    let emailError: string | undefined;

    // Validate first name
    const firstNameResult = NameValidator.validateFirstName(firstName);
    if (!firstNameResult.isValid && firstNameResult.error) {
      firstNameError = NameValidator.getErrorMessage(firstNameResult.error, 'first_name');
      errors.push({ field: 'firstName', message: firstNameError });
    }

    // Validate last name
    const lastNameResult = NameValidator.validateLastName(lastName);
    if (!lastNameResult.isValid && lastNameResult.error) {
      lastNameError = NameValidator.getErrorMessage(lastNameResult.error, 'last_name');
      errors.push({ field: 'lastName', message: lastNameError });
    }

    // Validate email
    const emailResult = EmailValidator.validate(email);
    if (!emailResult.isValid && emailResult.error) {
      emailError = EmailValidator.getErrorMessage(emailResult.error);
      errors.push({ field: 'email', message: emailError });
    }

    return {
      isValid: errors.length === 0,
      errors,
      firstNameError,
      lastNameError,
      emailError
    };
  }

  /**
   * Validates and returns the validated data as a Result
   */
  static validateAndNormalize(
    firstName: string | null | undefined,
    lastName: string | null | undefined,
    email: string | null | undefined,
    avatar: string = ''
  ): Result<ValidatedUserData, UserValidationResult> {
    const validationResult = UserValidator.validateUserData(firstName, lastName, email);

    if (!validationResult.isValid) {
      return new Failure<UserValidationResult>(validationResult);
    }

    // Get normalized values
    const firstNameResult = NameValidator.validate(firstName);
    const lastNameResult = NameValidator.validate(lastName);
    const emailResult = EmailValidator.validate(email);

    const normalizedFirstName = firstNameResult.normalizedName !== undefined ? firstNameResult.normalizedName : '';
    const normalizedLastName = lastNameResult.normalizedName !== undefined ? lastNameResult.normalizedName : '';
    const normalizedEmail = emailResult.normalizedEmail !== undefined ? emailResult.normalizedEmail : '';

    const validatedData: ValidatedUserData = {
      firstName: normalizedFirstName,
      lastName: normalizedLastName,
      email: normalizedEmail,
      avatar: avatar !== '' ? avatar : UserValidator.generateDefaultAvatar(normalizedFirstName, normalizedLastName)
    };
    return new Success<ValidatedUserData>(validatedData);
  }

  /**
   * Validates first name field in real-time
   */
  static validateFirstName(firstName: string | null | undefined): string | undefined {
    const result = NameValidator.validateFirstName(firstName);
    if (!result.isValid && result.error) {
      return NameValidator.getErrorMessage(result.error, 'first_name');
    }
    return undefined;
  }

  /**
   * Validates last name field in real-time
   */
  static validateLastName(lastName: string | null | undefined): string | undefined {
    const result = NameValidator.validateLastName(lastName);
    if (!result.isValid && result.error) {
      return NameValidator.getErrorMessage(result.error, 'last_name');
    }
    return undefined;
  }

  /**
   * Validates email field in real-time
   */
  static validateEmail(email: string | null | undefined): string | undefined {
    const result = EmailValidator.validate(email);
    if (!result.isValid && result.error) {
      return EmailValidator.getErrorMessage(result.error);
    }
    return undefined;
  }

  /**
   * Checks if a form has any validation errors
   */
  static hasErrors(validation: UserValidationResult): boolean {
    return !validation.isValid;
  }

  /**
   * Gets the first error message from validation result
   */
  static getFirstError(validation: UserValidationResult): string | undefined {
    return validation.errors.length > 0 ? validation.errors[0].message : undefined;
  }

  /**
   * Generates a default avatar URL using UI Avatars service
   */
  private static generateDefaultAvatar(firstName: string, lastName: string): string {
    const initials = `${firstName.charAt(0)}${lastName.charAt(0)}`;
    return `https://ui-avatars.com/api/?name=${encodeURIComponent(initials)}&background=7C3AED&color=fff&size=128`;
  }
}
