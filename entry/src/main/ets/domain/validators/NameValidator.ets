import { Result, Success, Failure } from '../models/Result';

/**
 * Name validation result
 */
export interface NameValidationResult {
  readonly isValid: boolean;
  readonly name: string;
  readonly normalizedName: string | undefined;
  readonly error: NameValidationError | undefined;
}

/**
 * Name validation errors
 */
export enum NameValidationError {
  EMPTY = 'empty',
  TOO_SHORT = 'too_short',
  TOO_LONG = 'too_long',
  INVALID_CHARACTERS = 'invalid_characters',
  ONLY_WHITESPACE = 'only_whitespace',
  STARTS_WITH_NUMBER = 'starts_with_number'
}

/**
 * Name type for contextual error messages
 */
export type NameType = 'first_name' | 'last_name' | 'name';

// Module-level constants to avoid this in static methods
const NAME_MIN_LENGTH = 2;
const NAME_MAX_LENGTH = 50;
// Pattern allows letters, spaces, hyphens, and apostrophes (for names like O'Brien, Mary-Jane)
const NAME_PATTERN = /^[a-zA-Z\u00C0-\u024F][a-zA-Z\u00C0-\u024F\s'-]*$/;

/**
 * Validator for first name and last name fields.
 * Ensures names meet minimum requirements and contain valid characters.
 */
export class NameValidator {

  /**
   * Validates a name with detailed error reporting
   */
  static validate(name: string | null | undefined, type: NameType = 'name'): NameValidationResult {
    // Check for empty
    if (name === null || name === undefined || name.length === 0) {
      const result: NameValidationResult = {
        isValid: false,
        name: name ?? '',
        normalizedName: undefined,
        error: NameValidationError.EMPTY
      };
      return result;
    }

    // Check for only whitespace
    const trimmedName = name.trim();
    if (trimmedName.length === 0) {
      const result: NameValidationResult = {
        isValid: false,
        name: name,
        normalizedName: undefined,
        error: NameValidationError.ONLY_WHITESPACE
      };
      return result;
    }

    // Check minimum length
    if (trimmedName.length < NAME_MIN_LENGTH) {
      const result: NameValidationResult = {
        isValid: false,
        name: trimmedName,
        normalizedName: undefined,
        error: NameValidationError.TOO_SHORT
      };
      return result;
    }

    // Check maximum length
    if (trimmedName.length > NAME_MAX_LENGTH) {
      const result: NameValidationResult = {
        isValid: false,
        name: trimmedName,
        normalizedName: undefined,
        error: NameValidationError.TOO_LONG
      };
      return result;
    }

    // Check for starting with number
    if (/^\d/.test(trimmedName)) {
      const result: NameValidationResult = {
        isValid: false,
        name: trimmedName,
        normalizedName: undefined,
        error: NameValidationError.STARTS_WITH_NUMBER
      };
      return result;
    }

    // Check for valid characters
    if (!NAME_PATTERN.test(trimmedName)) {
      const result: NameValidationResult = {
        isValid: false,
        name: trimmedName,
        normalizedName: undefined,
        error: NameValidationError.INVALID_CHARACTERS
      };
      return result;
    }

    // Normalize the name (capitalize first letter of each word)
    const normalizedName = NameValidator.normalizeName(trimmedName);

    const successResult: NameValidationResult = {
      isValid: true,
      name: trimmedName,
      normalizedName: normalizedName,
      error: undefined
    };
    return successResult;
  }

  /**
   * Validates first name specifically
   */
  static validateFirstName(firstName: string | null | undefined): NameValidationResult {
    return NameValidator.validate(firstName, 'first_name');
  }

  /**
   * Validates last name specifically
   */
  static validateLastName(lastName: string | null | undefined): NameValidationResult {
    return NameValidator.validate(lastName, 'last_name');
  }

  /**
   * Simple validation that returns a Result
   */
  static validateAsResult(name: string | null | undefined, type: NameType = 'name'): Result<string, string> {
    const result = NameValidator.validate(name, type);
    if (result.isValid && result.normalizedName !== undefined) {
      return new Success<string>(result.normalizedName);
    }
    const errorMsg = result.error !== undefined ? NameValidator.getErrorMessage(result.error, type) : 'Invalid name';
    return new Failure<string>(errorMsg);
  }

  /**
   * Quick check if name is valid
   */
  static isValid(name: string | null | undefined): boolean {
    return NameValidator.validate(name).isValid;
  }

  /**
   * Gets a user-friendly error message for a name validation error
   */
  static getErrorMessage(error: NameValidationError, type: NameType = 'name'): string {
    const fieldName = NameValidator.getFieldDisplayName(type);

    switch (error) {
      case NameValidationError.EMPTY:
        return `${fieldName} is required`;
      case NameValidationError.TOO_SHORT:
        return `${fieldName} must be at least ${NAME_MIN_LENGTH} characters`;
      case NameValidationError.TOO_LONG:
        return `${fieldName} must be less than ${NAME_MAX_LENGTH} characters`;
      case NameValidationError.INVALID_CHARACTERS:
        return `${fieldName} contains invalid characters`;
      case NameValidationError.ONLY_WHITESPACE:
        return `${fieldName} cannot be only whitespace`;
      case NameValidationError.STARTS_WITH_NUMBER:
        return `${fieldName} cannot start with a number`;
      default:
        return `Please enter a valid ${fieldName.toLowerCase()}`;
    }
  }

  private static getFieldDisplayName(type: NameType): string {
    switch (type) {
      case 'first_name':
        return 'First name';
      case 'last_name':
        return 'Last name';
      default:
        return 'Name';
    }
  }

  /**
   * Normalizes a name by capitalizing the first letter of each word
   */
  private static normalizeName(name: string): string {
    return name
      .split(/[\s-]+/)
      .map(word => {
        if (word.length === 0) return word;
        // Handle apostrophes (O'Brien)
        const apostropheIndex = word.indexOf("'");
        if (apostropheIndex > 0 && apostropheIndex < word.length - 1) {
          return (
            word.charAt(0).toUpperCase() +
            word.slice(1, apostropheIndex + 1).toLowerCase() +
            word.charAt(apostropheIndex + 1).toUpperCase() +
            word.slice(apostropheIndex + 2).toLowerCase()
          );
        }
        return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
      })
      .join(name.includes('-') ? '-' : ' ');
  }
}
