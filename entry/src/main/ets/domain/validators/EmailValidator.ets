import { Result, Success, Failure } from '../models/Result';

/**
 * Email validation result
 */
export interface EmailValidationResult {
  readonly isValid: boolean;
  readonly email: string;
  readonly normalizedEmail: string | undefined;
  readonly error: EmailValidationError | undefined;
}

/**
 * Local part validation result interface
 */
export interface LocalPartValidationResult {
  readonly isValid: boolean;
  readonly error: EmailValidationError | undefined;
}

/**
 * Domain part validation result interface
 */
export interface DomainPartValidationResult {
  readonly isValid: boolean;
  readonly error: EmailValidationError | undefined;
}

/**
 * Email validation errors
 */
export enum EmailValidationError {
  EMPTY = 'empty',
  TOO_SHORT = 'too_short',
  TOO_LONG = 'too_long',
  INVALID_FORMAT = 'invalid_format',
  INVALID_LOCAL_PART = 'invalid_local_part',
  INVALID_DOMAIN = 'invalid_domain',
  MISSING_AT_SYMBOL = 'missing_at_symbol',
  MULTIPLE_AT_SYMBOLS = 'multiple_at_symbols',
  STARTS_WITH_DOT = 'starts_with_dot',
  ENDS_WITH_DOT = 'ends_with_dot',
  CONSECUTIVE_DOTS = 'consecutive_dots'
}

// Module-level constants to avoid this in static methods
const EMAIL_MIN_LENGTH = 5; // a@b.c
const EMAIL_MAX_LENGTH = 254;
const EMAIL_MAX_LOCAL_PART_LENGTH = 64;
const EMAIL_MAX_DOMAIN_LENGTH = 253;
const EMAIL_PATTERN = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/;

/**
 * RFC 5322 compliant email validator.
 * Provides detailed validation with specific error messages.
 */
export class EmailValidator {

  /**
   * Validates an email address with detailed error reporting
   */
  static validate(email: string | null | undefined): EmailValidationResult {
    // Check for empty
    if (email === null || email === undefined || email.trim().length === 0) {
      const result: EmailValidationResult = {
        isValid: false,
        email: email ?? '',
        normalizedEmail: undefined,
        error: EmailValidationError.EMPTY
      };
      return result;
    }

    const trimmedEmail = email.trim();

    // Check minimum length
    if (trimmedEmail.length < EMAIL_MIN_LENGTH) {
      const result: EmailValidationResult = {
        isValid: false,
        email: trimmedEmail,
        normalizedEmail: undefined,
        error: EmailValidationError.TOO_SHORT
      };
      return result;
    }

    // Check maximum length
    if (trimmedEmail.length > EMAIL_MAX_LENGTH) {
      const result: EmailValidationResult = {
        isValid: false,
        email: trimmedEmail,
        normalizedEmail: undefined,
        error: EmailValidationError.TOO_LONG
      };
      return result;
    }

    // Check for @ symbol
    const matches = trimmedEmail.match(/@/g);
    const atCount = matches !== null ? matches.length : 0;
    if (atCount === 0) {
      const result: EmailValidationResult = {
        isValid: false,
        email: trimmedEmail,
        normalizedEmail: undefined,
        error: EmailValidationError.MISSING_AT_SYMBOL
      };
      return result;
    }

    if (atCount > 1) {
      const result: EmailValidationResult = {
        isValid: false,
        email: trimmedEmail,
        normalizedEmail: undefined,
        error: EmailValidationError.MULTIPLE_AT_SYMBOLS
      };
      return result;
    }

    // Split into local and domain parts
    const atIndex = trimmedEmail.indexOf('@');
    const localPart = trimmedEmail.substring(0, atIndex);
    const domainPart = trimmedEmail.substring(atIndex + 1);

    // Validate local part
    const localValidation = EmailValidator.validateLocalPart(localPart);
    if (!localValidation.isValid) {
      const result: EmailValidationResult = {
        isValid: false,
        email: trimmedEmail,
        normalizedEmail: undefined,
        error: localValidation.error
      };
      return result;
    }

    // Validate domain part
    const domainValidation = EmailValidator.validateDomainPart(domainPart);
    if (!domainValidation.isValid) {
      const result: EmailValidationResult = {
        isValid: false,
        email: trimmedEmail,
        normalizedEmail: undefined,
        error: domainValidation.error
      };
      return result;
    }

    // Final regex check
    if (!EMAIL_PATTERN.test(trimmedEmail)) {
      const result: EmailValidationResult = {
        isValid: false,
        email: trimmedEmail,
        normalizedEmail: undefined,
        error: EmailValidationError.INVALID_FORMAT
      };
      return result;
    }

    // Valid email
    const successResult: EmailValidationResult = {
      isValid: true,
      email: trimmedEmail,
      normalizedEmail: trimmedEmail.toLowerCase(),
      error: undefined
    };
    return successResult;
  }

  /**
   * Simple validation that returns a Result
   */
  static validateAsResult(email: string | null | undefined): Result<string, string> {
    const result = EmailValidator.validate(email);
    if (result.isValid && result.normalizedEmail !== undefined) {
      return new Success<string>(result.normalizedEmail);
    }
    const errorMsg = result.error !== undefined ? EmailValidator.getErrorMessage(result.error) : 'Invalid email';
    return new Failure<string>(errorMsg);
  }

  /**
   * Quick check if email is valid
   */
  static isValid(email: string | null | undefined): boolean {
    return EmailValidator.validate(email).isValid;
  }

  /**
   * Gets a user-friendly error message for an email validation error
   */
  static getErrorMessage(error: EmailValidationError): string {
    switch (error) {
      case EmailValidationError.EMPTY:
        return 'Email is required';
      case EmailValidationError.TOO_SHORT:
        return 'Email is too short';
      case EmailValidationError.TOO_LONG:
        return 'Email is too long';
      case EmailValidationError.INVALID_FORMAT:
        return 'Please enter a valid email address';
      case EmailValidationError.INVALID_LOCAL_PART:
        return 'Invalid characters before @ symbol';
      case EmailValidationError.INVALID_DOMAIN:
        return 'Invalid domain name';
      case EmailValidationError.MISSING_AT_SYMBOL:
        return 'Email must contain @ symbol';
      case EmailValidationError.MULTIPLE_AT_SYMBOLS:
        return 'Email can only contain one @ symbol';
      case EmailValidationError.STARTS_WITH_DOT:
        return 'Email cannot start with a dot';
      case EmailValidationError.ENDS_WITH_DOT:
        return 'Email cannot end with a dot';
      case EmailValidationError.CONSECUTIVE_DOTS:
        return 'Email cannot contain consecutive dots';
      default:
        return 'Please enter a valid email address';
    }
  }

  private static validateLocalPart(localPart: string): LocalPartValidationResult {
    if (localPart.length === 0) {
      const result: LocalPartValidationResult = { isValid: false, error: EmailValidationError.INVALID_LOCAL_PART };
      return result;
    }

    if (localPart.length > EMAIL_MAX_LOCAL_PART_LENGTH) {
      const result: LocalPartValidationResult = { isValid: false, error: EmailValidationError.TOO_LONG };
      return result;
    }

    if (localPart.startsWith('.')) {
      const result: LocalPartValidationResult = { isValid: false, error: EmailValidationError.STARTS_WITH_DOT };
      return result;
    }

    if (localPart.endsWith('.')) {
      const result: LocalPartValidationResult = { isValid: false, error: EmailValidationError.ENDS_WITH_DOT };
      return result;
    }

    if (localPart.includes('..')) {
      const result: LocalPartValidationResult = { isValid: false, error: EmailValidationError.CONSECUTIVE_DOTS };
      return result;
    }

    const validResult: LocalPartValidationResult = { isValid: true, error: undefined };
    return validResult;
  }

  private static validateDomainPart(domainPart: string): DomainPartValidationResult {
    if (domainPart.length === 0) {
      const result: DomainPartValidationResult = { isValid: false, error: EmailValidationError.INVALID_DOMAIN };
      return result;
    }

    if (domainPart.length > EMAIL_MAX_DOMAIN_LENGTH) {
      const result: DomainPartValidationResult = { isValid: false, error: EmailValidationError.TOO_LONG };
      return result;
    }

    if (domainPart.startsWith('.') || domainPart.startsWith('-')) {
      const result: DomainPartValidationResult = { isValid: false, error: EmailValidationError.INVALID_DOMAIN };
      return result;
    }

    if (domainPart.endsWith('.') || domainPart.endsWith('-')) {
      const result: DomainPartValidationResult = { isValid: false, error: EmailValidationError.INVALID_DOMAIN };
      return result;
    }

    if (!domainPart.includes('.')) {
      const result: DomainPartValidationResult = { isValid: false, error: EmailValidationError.INVALID_DOMAIN };
      return result;
    }

    const validResult: DomainPartValidationResult = { isValid: true, error: undefined };
    return validResult;
  }
}
