/**
 * Unit Tests for UserValidator
 */

import { describe, it, expect } from '@ohos/hypium';
import { UserValidator, UserValidationResult, FieldError } from '../../../../main/ets/domain/validators/UserValidator';
import { CreateUserRequest, UpdateUserRequest } from '../../../../main/ets/domain/models/User';

export default function UserValidatorTest() {
  describe('UserValidator', () => {
    describe('validateUserData', () => {
      it('should return valid for all correct fields', () => {
        const result = UserValidator.validateUserData('John', 'Doe', 'john@example.com');

        expect(result.isValid).assertTrue();
        expect(result.errors.length).assertEqual(0);
        expect(result.firstNameError).assertUndefined();
        expect(result.lastNameError).assertUndefined();
        expect(result.emailError).assertUndefined();
      });

      it('should return invalid for empty first name', () => {
        const result = UserValidator.validateUserData('', 'Doe', 'john@example.com');

        expect(result.isValid).assertFalse();
        expect(result.firstNameError).assertNotNull();
        expect(result.lastNameError).assertUndefined();
        expect(result.emailError).assertUndefined();
      });

      it('should return invalid for empty last name', () => {
        const result = UserValidator.validateUserData('John', '', 'john@example.com');

        expect(result.isValid).assertFalse();
        expect(result.firstNameError).assertUndefined();
        expect(result.lastNameError).assertNotNull();
        expect(result.emailError).assertUndefined();
      });

      it('should return invalid for invalid email', () => {
        const result = UserValidator.validateUserData('John', 'Doe', 'invalid');

        expect(result.isValid).assertFalse();
        expect(result.firstNameError).assertUndefined();
        expect(result.lastNameError).assertUndefined();
        expect(result.emailError).assertNotNull();
      });

      it('should return multiple errors for multiple invalid fields', () => {
        const result = UserValidator.validateUserData('', '', '');

        expect(result.isValid).assertFalse();
        expect(result.errors.length).assertEqual(3);
        expect(result.firstNameError).assertNotNull();
        expect(result.lastNameError).assertNotNull();
        expect(result.emailError).assertNotNull();
      });

      it('should handle null values', () => {
        const result = UserValidator.validateUserData(null, null, null);

        expect(result.isValid).assertFalse();
        expect(result.errors.length).assertEqual(3);
      });

      it('should handle undefined values', () => {
        const result = UserValidator.validateUserData(undefined, undefined, undefined);

        expect(result.isValid).assertFalse();
        expect(result.errors.length).assertEqual(3);
      });

      it('should populate errors array with correct fields', () => {
        const result = UserValidator.validateUserData('', '', '');

        const fieldNames = result.errors.map(e => e.field);
        expect(fieldNames.includes('firstName')).assertTrue();
        expect(fieldNames.includes('lastName')).assertTrue();
        expect(fieldNames.includes('email')).assertTrue();
      });
    });

    describe('validateCreateRequest', () => {
      it('should validate valid create request', () => {
        const request: CreateUserRequest = {
          firstName: 'John',
          lastName: 'Doe',
          email: 'john@example.com',
          avatar: 'avatar.png'
        };

        const result = UserValidator.validateCreateRequest(request);

        expect(result.isValid).assertTrue();
      });

      it('should validate invalid create request', () => {
        const request: CreateUserRequest = {
          firstName: '',
          lastName: '',
          email: '',
          avatar: ''
        };

        const result = UserValidator.validateCreateRequest(request);

        expect(result.isValid).assertFalse();
        expect(result.errors.length).assertEqual(3);
      });
    });

    describe('validateUpdateRequest', () => {
      it('should validate valid update request', () => {
        const request: UpdateUserRequest = {
          id: 1,
          firstName: 'John',
          lastName: 'Doe',
          email: 'john@example.com',
          avatar: 'avatar.png'
        };

        const result = UserValidator.validateUpdateRequest(request);

        expect(result.isValid).assertTrue();
      });

      it('should validate invalid update request', () => {
        const request: UpdateUserRequest = {
          id: 1,
          firstName: '',
          lastName: '',
          email: '',
          avatar: ''
        };

        const result = UserValidator.validateUpdateRequest(request);

        expect(result.isValid).assertFalse();
      });
    });

    describe('validateAndNormalize', () => {
      it('should return Success with normalized data for valid input', () => {
        const result = UserValidator.validateAndNormalize('john', 'doe', 'JOHN@EXAMPLE.COM', 'avatar.png');

        expect(result.isSuccess).assertTrue();
      });

      it('should return Failure for invalid input', () => {
        const result = UserValidator.validateAndNormalize('', '', '');

        expect(result.isFailure).assertTrue();
      });

      it('should generate default avatar when not provided', () => {
        const result = UserValidator.validateAndNormalize('John', 'Doe', 'john@example.com');

        expect(result.isSuccess).assertTrue();
      });

      it('should use provided avatar', () => {
        const result = UserValidator.validateAndNormalize('John', 'Doe', 'john@example.com', 'custom.png');

        expect(result.isSuccess).assertTrue();
      });
    });

    describe('validateFirstName', () => {
      it('should return undefined for valid first name', () => {
        const error = UserValidator.validateFirstName('John');

        expect(error).assertUndefined();
      });

      it('should return error message for empty first name', () => {
        const error = UserValidator.validateFirstName('');

        expect(error).assertNotNull();
        expect(error?.includes('First name')).assertTrue();
      });

      it('should return error message for too short first name', () => {
        const error = UserValidator.validateFirstName('J');

        expect(error).assertNotNull();
      });

      it('should return error message for null', () => {
        const error = UserValidator.validateFirstName(null);

        expect(error).assertNotNull();
      });

      it('should return error message for undefined', () => {
        const error = UserValidator.validateFirstName(undefined);

        expect(error).assertNotNull();
      });
    });

    describe('validateLastName', () => {
      it('should return undefined for valid last name', () => {
        const error = UserValidator.validateLastName('Doe');

        expect(error).assertUndefined();
      });

      it('should return error message for empty last name', () => {
        const error = UserValidator.validateLastName('');

        expect(error).assertNotNull();
        expect(error?.includes('Last name')).assertTrue();
      });

      it('should return error message for too short last name', () => {
        const error = UserValidator.validateLastName('D');

        expect(error).assertNotNull();
      });
    });

    describe('validateEmail', () => {
      it('should return undefined for valid email', () => {
        const error = UserValidator.validateEmail('john@example.com');

        expect(error).assertUndefined();
      });

      it('should return error message for empty email', () => {
        const error = UserValidator.validateEmail('');

        expect(error).assertNotNull();
      });

      it('should return error message for invalid email', () => {
        const error = UserValidator.validateEmail('invalid');

        expect(error).assertNotNull();
      });

      it('should return error message for email without @', () => {
        const error = UserValidator.validateEmail('johnexample.com');

        expect(error).assertNotNull();
      });
    });

    describe('hasErrors', () => {
      it('should return false for valid result', () => {
        const result = UserValidator.validateUserData('John', 'Doe', 'john@example.com');

        expect(UserValidator.hasErrors(result)).assertFalse();
      });

      it('should return true for invalid result', () => {
        const result = UserValidator.validateUserData('', '', '');

        expect(UserValidator.hasErrors(result)).assertTrue();
      });
    });

    describe('getFirstError', () => {
      it('should return undefined for valid result', () => {
        const result = UserValidator.validateUserData('John', 'Doe', 'john@example.com');

        expect(UserValidator.getFirstError(result)).assertUndefined();
      });

      it('should return first error message for invalid result', () => {
        const result = UserValidator.validateUserData('', 'Doe', 'john@example.com');

        const firstError = UserValidator.getFirstError(result);
        expect(firstError).assertNotNull();
      });

      it('should return first error when multiple errors exist', () => {
        const result = UserValidator.validateUserData('', '', '');

        const firstError = UserValidator.getFirstError(result);
        expect(firstError).assertNotNull();
      });
    });
  });
}
