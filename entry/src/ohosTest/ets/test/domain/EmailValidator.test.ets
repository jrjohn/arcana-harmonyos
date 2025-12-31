/**
 * Unit Tests for EmailValidator
 */

import { describe, it, expect } from '@ohos/hypium';
import { EmailValidator, EmailValidationError } from '../../../../main/ets/domain/validators/EmailValidator';

export default function EmailValidatorTest() {
  describe('EmailValidator', () => {
    describe('validate', () => {
      describe('valid emails', () => {
        it('should accept simple email', () => {
          const result = EmailValidator.validate('test@example.com');

          expect(result.isValid).assertTrue();
          expect(result.normalizedEmail).assertEqual('test@example.com');
          expect(result.error).assertUndefined();
        });

        it('should accept email with subdomain', () => {
          const result = EmailValidator.validate('user@mail.example.com');

          expect(result.isValid).assertTrue();
        });

        it('should accept email with numbers', () => {
          const result = EmailValidator.validate('user123@example.com');

          expect(result.isValid).assertTrue();
        });

        it('should accept email with dots in local part', () => {
          const result = EmailValidator.validate('first.last@example.com');

          expect(result.isValid).assertTrue();
        });

        it('should accept email with plus sign', () => {
          const result = EmailValidator.validate('user+tag@example.com');

          expect(result.isValid).assertTrue();
        });

        it('should accept email with hyphen in domain', () => {
          const result = EmailValidator.validate('user@my-domain.com');

          expect(result.isValid).assertTrue();
        });

        it('should normalize email to lowercase', () => {
          const result = EmailValidator.validate('User@Example.COM');

          expect(result.isValid).assertTrue();
          expect(result.normalizedEmail).assertEqual('user@example.com');
        });

        it('should trim whitespace', () => {
          const result = EmailValidator.validate('  test@example.com  ');

          expect(result.isValid).assertTrue();
          expect(result.normalizedEmail).assertEqual('test@example.com');
        });

        it('should accept email with underscore', () => {
          const result = EmailValidator.validate('user_name@example.com');

          expect(result.isValid).assertTrue();
        });
      });

      describe('empty validation', () => {
        it('should reject null', () => {
          const result = EmailValidator.validate(null);

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(EmailValidationError.EMPTY);
        });

        it('should reject undefined', () => {
          const result = EmailValidator.validate(undefined);

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(EmailValidationError.EMPTY);
        });

        it('should reject empty string', () => {
          const result = EmailValidator.validate('');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(EmailValidationError.EMPTY);
        });

        it('should reject whitespace only', () => {
          const result = EmailValidator.validate('   ');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(EmailValidationError.EMPTY);
        });
      });

      describe('length validation', () => {
        it('should reject too short email', () => {
          const result = EmailValidator.validate('a@b');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(EmailValidationError.TOO_SHORT);
        });

        it('should reject email exceeding max length', () => {
          const longLocal = 'a'.repeat(65);
          const email = `${longLocal}@example.com`;
          const result = EmailValidator.validate(email);

          expect(result.isValid).assertFalse();
        });
      });

      describe('@ symbol validation', () => {
        it('should reject email without @ symbol', () => {
          const result = EmailValidator.validate('testexample.com');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(EmailValidationError.MISSING_AT_SYMBOL);
        });

        it('should reject email with multiple @ symbols', () => {
          const result = EmailValidator.validate('test@example@com');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(EmailValidationError.MULTIPLE_AT_SYMBOLS);
        });
      });

      describe('local part validation', () => {
        it('should reject email starting with dot', () => {
          const result = EmailValidator.validate('.test@example.com');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(EmailValidationError.STARTS_WITH_DOT);
        });

        it('should reject email ending with dot before @', () => {
          const result = EmailValidator.validate('test.@example.com');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(EmailValidationError.ENDS_WITH_DOT);
        });

        it('should reject email with consecutive dots', () => {
          const result = EmailValidator.validate('test..user@example.com');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(EmailValidationError.CONSECUTIVE_DOTS);
        });

        it('should reject email with empty local part', () => {
          const result = EmailValidator.validate('@example.com');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(EmailValidationError.INVALID_LOCAL_PART);
        });
      });

      describe('domain validation', () => {
        it('should reject email with empty domain', () => {
          const result = EmailValidator.validate('test@');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(EmailValidationError.INVALID_DOMAIN);
        });

        it('should reject email without TLD', () => {
          const result = EmailValidator.validate('test@example');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(EmailValidationError.INVALID_DOMAIN);
        });

        it('should reject email with domain starting with dot', () => {
          const result = EmailValidator.validate('test@.example.com');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(EmailValidationError.INVALID_DOMAIN);
        });

        it('should reject email with domain starting with hyphen', () => {
          const result = EmailValidator.validate('test@-example.com');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(EmailValidationError.INVALID_DOMAIN);
        });

        it('should reject email with domain ending with dot', () => {
          const result = EmailValidator.validate('test@example.com.');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(EmailValidationError.INVALID_DOMAIN);
        });

        it('should reject email with domain ending with hyphen', () => {
          const result = EmailValidator.validate('test@example-.com');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(EmailValidationError.INVALID_DOMAIN);
        });
      });
    });

    describe('validateAsResult', () => {
      it('should return Success for valid email', () => {
        const result = EmailValidator.validateAsResult('test@example.com');

        expect(result.isSuccess).assertTrue();
      });

      it('should return Failure for invalid email', () => {
        const result = EmailValidator.validateAsResult('invalid');

        expect(result.isFailure).assertTrue();
      });
    });

    describe('isValid', () => {
      it('should return true for valid email', () => {
        expect(EmailValidator.isValid('test@example.com')).assertTrue();
      });

      it('should return false for invalid email', () => {
        expect(EmailValidator.isValid('invalid')).assertFalse();
      });

      it('should return false for null', () => {
        expect(EmailValidator.isValid(null)).assertFalse();
      });

      it('should return false for undefined', () => {
        expect(EmailValidator.isValid(undefined)).assertFalse();
      });
    });

    describe('getErrorMessage', () => {
      it('should return message for EMPTY', () => {
        const message = EmailValidator.getErrorMessage(EmailValidationError.EMPTY);
        expect(message).assertEqual('Email is required');
      });

      it('should return message for TOO_SHORT', () => {
        const message = EmailValidator.getErrorMessage(EmailValidationError.TOO_SHORT);
        expect(message).assertEqual('Email is too short');
      });

      it('should return message for TOO_LONG', () => {
        const message = EmailValidator.getErrorMessage(EmailValidationError.TOO_LONG);
        expect(message).assertEqual('Email is too long');
      });

      it('should return message for INVALID_FORMAT', () => {
        const message = EmailValidator.getErrorMessage(EmailValidationError.INVALID_FORMAT);
        expect(message).assertEqual('Please enter a valid email address');
      });

      it('should return message for INVALID_LOCAL_PART', () => {
        const message = EmailValidator.getErrorMessage(EmailValidationError.INVALID_LOCAL_PART);
        expect(message).assertEqual('Invalid characters before @ symbol');
      });

      it('should return message for INVALID_DOMAIN', () => {
        const message = EmailValidator.getErrorMessage(EmailValidationError.INVALID_DOMAIN);
        expect(message).assertEqual('Invalid domain name');
      });

      it('should return message for MISSING_AT_SYMBOL', () => {
        const message = EmailValidator.getErrorMessage(EmailValidationError.MISSING_AT_SYMBOL);
        expect(message).assertEqual('Email must contain @ symbol');
      });

      it('should return message for MULTIPLE_AT_SYMBOLS', () => {
        const message = EmailValidator.getErrorMessage(EmailValidationError.MULTIPLE_AT_SYMBOLS);
        expect(message).assertEqual('Email can only contain one @ symbol');
      });

      it('should return message for STARTS_WITH_DOT', () => {
        const message = EmailValidator.getErrorMessage(EmailValidationError.STARTS_WITH_DOT);
        expect(message).assertEqual('Email cannot start with a dot');
      });

      it('should return message for ENDS_WITH_DOT', () => {
        const message = EmailValidator.getErrorMessage(EmailValidationError.ENDS_WITH_DOT);
        expect(message).assertEqual('Email cannot end with a dot');
      });

      it('should return message for CONSECUTIVE_DOTS', () => {
        const message = EmailValidator.getErrorMessage(EmailValidationError.CONSECUTIVE_DOTS);
        expect(message).assertEqual('Email cannot contain consecutive dots');
      });
    });
  });
}
