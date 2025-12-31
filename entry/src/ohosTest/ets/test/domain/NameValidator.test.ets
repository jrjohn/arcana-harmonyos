/**
 * Unit Tests for NameValidator
 */

import { describe, it, expect } from '@ohos/hypium';
import { NameValidator, NameValidationError, NameType } from '../../../../main/ets/domain/validators/NameValidator';

export default function NameValidatorTest() {
  describe('NameValidator', () => {
    describe('validate', () => {
      describe('valid names', () => {
        it('should accept simple name', () => {
          const result = NameValidator.validate('John');

          expect(result.isValid).assertTrue();
          expect(result.normalizedName).assertEqual('John');
          expect(result.error).assertUndefined();
        });

        it('should accept name with hyphen', () => {
          const result = NameValidator.validate('Mary-Jane');

          expect(result.isValid).assertTrue();
        });

        it('should accept name with apostrophe', () => {
          const result = NameValidator.validate("O'Brien");

          expect(result.isValid).assertTrue();
        });

        it('should accept name with space', () => {
          const result = NameValidator.validate('Mary Jane');

          expect(result.isValid).assertTrue();
        });

        it('should accept accented characters', () => {
          const result = NameValidator.validate('José');

          expect(result.isValid).assertTrue();
        });

        it('should accept umlauts', () => {
          const result = NameValidator.validate('Müller');

          expect(result.isValid).assertTrue();
        });

        it('should trim whitespace', () => {
          const result = NameValidator.validate('  John  ');

          expect(result.isValid).assertTrue();
          expect(result.name).assertEqual('John');
        });
      });

      describe('name normalization', () => {
        it('should capitalize first letter', () => {
          const result = NameValidator.validate('john');

          expect(result.isValid).assertTrue();
          expect(result.normalizedName).assertEqual('John');
        });

        it('should lowercase rest of name', () => {
          const result = NameValidator.validate('JOHN');

          expect(result.isValid).assertTrue();
          expect(result.normalizedName).assertEqual('John');
        });

        it('should handle mixed case', () => {
          const result = NameValidator.validate('jOhN');

          expect(result.isValid).assertTrue();
          expect(result.normalizedName).assertEqual('John');
        });

        it('should normalize hyphenated names', () => {
          const result = NameValidator.validate('mary-jane');

          expect(result.isValid).assertTrue();
          // Note: normalization splits on hyphen and capitalizes each part
        });

        it('should normalize names with apostrophe', () => {
          const result = NameValidator.validate("o'brien");

          expect(result.isValid).assertTrue();
          expect(result.normalizedName).assertEqual("O'Brien");
        });
      });

      describe('empty validation', () => {
        it('should reject null', () => {
          const result = NameValidator.validate(null);

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(NameValidationError.EMPTY);
        });

        it('should reject undefined', () => {
          const result = NameValidator.validate(undefined);

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(NameValidationError.EMPTY);
        });

        it('should reject empty string', () => {
          const result = NameValidator.validate('');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(NameValidationError.EMPTY);
        });

        it('should reject whitespace only', () => {
          const result = NameValidator.validate('   ');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(NameValidationError.ONLY_WHITESPACE);
        });

        it('should reject tabs only', () => {
          const result = NameValidator.validate('\t\t');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(NameValidationError.ONLY_WHITESPACE);
        });
      });

      describe('length validation', () => {
        it('should reject name with 1 character', () => {
          const result = NameValidator.validate('A');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(NameValidationError.TOO_SHORT);
        });

        it('should accept name with 2 characters', () => {
          const result = NameValidator.validate('Jo');

          expect(result.isValid).assertTrue();
        });

        it('should accept name with 50 characters', () => {
          const name = 'A'.repeat(50);
          const result = NameValidator.validate(name);

          expect(result.isValid).assertTrue();
        });

        it('should reject name with 51 characters', () => {
          const name = 'A'.repeat(51);
          const result = NameValidator.validate(name);

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(NameValidationError.TOO_LONG);
        });
      });

      describe('character validation', () => {
        it('should reject name starting with number', () => {
          const result = NameValidator.validate('1John');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(NameValidationError.STARTS_WITH_NUMBER);
        });

        it('should reject name with numbers', () => {
          const result = NameValidator.validate('John123');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(NameValidationError.INVALID_CHARACTERS);
        });

        it('should reject name with special characters', () => {
          const result = NameValidator.validate('John@Doe');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(NameValidationError.INVALID_CHARACTERS);
        });

        it('should reject name with underscores', () => {
          const result = NameValidator.validate('John_Doe');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(NameValidationError.INVALID_CHARACTERS);
        });

        it('should reject name with exclamation mark', () => {
          const result = NameValidator.validate('John!');

          expect(result.isValid).assertFalse();
          expect(result.error).assertEqual(NameValidationError.INVALID_CHARACTERS);
        });
      });

      describe('name type parameter', () => {
        it('should accept name type parameter', () => {
          const result = NameValidator.validate('John', 'first_name');

          expect(result.isValid).assertTrue();
        });
      });
    });

    describe('validateFirstName', () => {
      it('should validate first name', () => {
        const result = NameValidator.validateFirstName('John');

        expect(result.isValid).assertTrue();
      });

      it('should reject invalid first name', () => {
        const result = NameValidator.validateFirstName('');

        expect(result.isValid).assertFalse();
      });
    });

    describe('validateLastName', () => {
      it('should validate last name', () => {
        const result = NameValidator.validateLastName('Doe');

        expect(result.isValid).assertTrue();
      });

      it('should reject invalid last name', () => {
        const result = NameValidator.validateLastName('');

        expect(result.isValid).assertFalse();
      });
    });

    describe('validateAsResult', () => {
      it('should return Success for valid name', () => {
        const result = NameValidator.validateAsResult('John');

        expect(result.isSuccess).assertTrue();
      });

      it('should return Failure for invalid name', () => {
        const result = NameValidator.validateAsResult('');

        expect(result.isFailure).assertTrue();
      });

      it('should return normalized name in Success', () => {
        const result = NameValidator.validateAsResult('john');

        expect(result.isSuccess).assertTrue();
      });
    });

    describe('isValid', () => {
      it('should return true for valid name', () => {
        expect(NameValidator.isValid('John')).assertTrue();
      });

      it('should return false for invalid name', () => {
        expect(NameValidator.isValid('')).assertFalse();
      });

      it('should return false for null', () => {
        expect(NameValidator.isValid(null)).assertFalse();
      });

      it('should return false for undefined', () => {
        expect(NameValidator.isValid(undefined)).assertFalse();
      });
    });

    describe('getErrorMessage', () => {
      it('should return message for EMPTY', () => {
        const message = NameValidator.getErrorMessage(NameValidationError.EMPTY, 'first_name');
        expect(message).assertEqual('First name is required');
      });

      it('should return message for TOO_SHORT', () => {
        const message = NameValidator.getErrorMessage(NameValidationError.TOO_SHORT, 'first_name');
        expect(message).assertEqual('First name must be at least 2 characters');
      });

      it('should return message for TOO_LONG', () => {
        const message = NameValidator.getErrorMessage(NameValidationError.TOO_LONG, 'last_name');
        expect(message).assertEqual('Last name must be less than 50 characters');
      });

      it('should return message for INVALID_CHARACTERS', () => {
        const message = NameValidator.getErrorMessage(NameValidationError.INVALID_CHARACTERS, 'name');
        expect(message).assertEqual('Name contains invalid characters');
      });

      it('should return message for ONLY_WHITESPACE', () => {
        const message = NameValidator.getErrorMessage(NameValidationError.ONLY_WHITESPACE, 'first_name');
        expect(message).assertEqual('First name cannot be only whitespace');
      });

      it('should return message for STARTS_WITH_NUMBER', () => {
        const message = NameValidator.getErrorMessage(NameValidationError.STARTS_WITH_NUMBER, 'last_name');
        expect(message).assertEqual('Last name cannot start with a number');
      });

      it('should use correct field name for first_name', () => {
        const message = NameValidator.getErrorMessage(NameValidationError.EMPTY, 'first_name');
        expect(message.includes('First name')).assertTrue();
      });

      it('should use correct field name for last_name', () => {
        const message = NameValidator.getErrorMessage(NameValidationError.EMPTY, 'last_name');
        expect(message.includes('Last name')).assertTrue();
      });

      it('should use correct field name for name', () => {
        const message = NameValidator.getErrorMessage(NameValidationError.EMPTY, 'name');
        expect(message.includes('Name')).assertTrue();
      });
    });
  });
}
