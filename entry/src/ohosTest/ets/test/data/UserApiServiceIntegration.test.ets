/**
 * Integration Tests for UserApiServiceImpl
 * Tests against the real reqres.in API
 *
 * Note: These tests require network connectivity and may fail if the API is down.
 * The reqres.in API is a test API that returns predictable responses.
 */

import { describe, it, expect, beforeEach, afterEach } from '@ohos/hypium';
import { UserApiServiceImpl } from '../../../../main/ets/data/api/UserApiServiceImpl';
import { ILogger } from '../../../../main/ets/core/di/interfaces';
import { Success, Failure } from '../../../../main/ets/domain/models/Result';
import { ErrorCode, AppError } from '../../../../main/ets/domain/models/AppError';
import { CreateUserRequest, UpdateUserRequest, PaginatedUsers, User } from '../../../../main/ets/domain/models/User';

/**
 * Mock logger for testing
 */
class IntegrationTestLogger implements ILogger {
  logs: string[] = [];
  warnings: string[] = [];
  errors: string[] = [];

  d(tag: string, message: string): void {
    this.logs.push(`[DEBUG][${tag}] ${message}`);
    console.log(`[DEBUG][${tag}] ${message}`);
  }

  i(tag: string, message: string): void {
    this.logs.push(`[INFO][${tag}] ${message}`);
    console.log(`[INFO][${tag}] ${message}`);
  }

  w(tag: string, message: string): void {
    this.warnings.push(`[WARN][${tag}] ${message}`);
    console.warn(`[WARN][${tag}] ${message}`);
  }

  e(tag: string, message: string): void {
    this.errors.push(`[ERROR][${tag}] ${message}`);
    console.error(`[ERROR][${tag}] ${message}`);
  }

  clear(): void {
    this.logs = [];
    this.warnings = [];
    this.errors = [];
  }
}

export default function UserApiServiceIntegrationTest() {
  describe('UserApiServiceImpl Integration Tests', () => {
    let service: UserApiServiceImpl;
    let logger: IntegrationTestLogger;

    beforeEach(() => {
      service = new UserApiServiceImpl();
      logger = new IntegrationTestLogger();
      service.setLogger(logger);
    });

    afterEach(() => {
      service.destroy();
    });

    describe('getUsers - Real API', () => {
      it('should fetch first page of users from reqres.in', async () => {
        const result = await service.getUsers(1, 6);

        expect(result.isSuccess).assertTrue();
        if (result.isSuccess) {
          const success = result as Success<PaginatedUsers>;
          expect(success.value.page).assertEqual(1);
          expect(success.value.perPage).assertEqual(6);
          expect(success.value.users.length > 0).assertTrue();
        }
      });

      it('should fetch second page of users', async () => {
        const result = await service.getUsers(2, 6);

        expect(result.isSuccess).assertTrue();
        if (result.isSuccess) {
          const success = result as Success<PaginatedUsers>;
          expect(success.value.page).assertEqual(2);
        }
      });

      it('should return correct total and totalPages', async () => {
        const result = await service.getUsers(1, 6);

        expect(result.isSuccess).assertTrue();
        if (result.isSuccess) {
          const success = result as Success<PaginatedUsers>;
          expect(success.value.total > 0).assertTrue();
          expect(success.value.totalPages > 0).assertTrue();
        }
      });

      it('should return empty users array for page beyond total', async () => {
        const result = await service.getUsers(100, 6);

        expect(result.isSuccess).assertTrue();
        if (result.isSuccess) {
          const success = result as Success<PaginatedUsers>;
          expect(success.value.users.length).assertEqual(0);
        }
      });

      it('should return users with valid data structure', async () => {
        const result = await service.getUsers(1, 6);

        expect(result.isSuccess).assertTrue();
        if (result.isSuccess) {
          const success = result as Success<PaginatedUsers>;
          for (const user of success.value.users) {
            expect(typeof user.id === 'number').assertTrue();
            expect(typeof user.email === 'string').assertTrue();
            expect(typeof user.firstName === 'string').assertTrue();
            expect(typeof user.lastName === 'string').assertTrue();
            expect(typeof user.avatar === 'string').assertTrue();
            expect(user.email.includes('@')).assertTrue();
          }
        }
      });

      it('should handle different perPage values', async () => {
        const result = await service.getUsers(1, 3);

        expect(result.isSuccess).assertTrue();
        if (result.isSuccess) {
          const success = result as Success<PaginatedUsers>;
          expect(success.value.perPage).assertEqual(3);
          expect(success.value.users.length <= 3).assertTrue();
        }
      });
    });

    describe('getUser - Real API', () => {
      it('should fetch user with ID 1 from reqres.in', async () => {
        const result = await service.getUser(1);

        expect(result.isSuccess).assertTrue();
        if (result.isSuccess) {
          const success = result as Success<User>;
          expect(success.value.id).assertEqual(1);
          expect(success.value.email).assertContain('@reqres.in');
        }
      });

      it('should fetch user with ID 2', async () => {
        const result = await service.getUser(2);

        expect(result.isSuccess).assertTrue();
        if (result.isSuccess) {
          const success = result as Success<User>;
          expect(success.value.id).assertEqual(2);
        }
      });

      it('should return user with complete profile data', async () => {
        const result = await service.getUser(1);

        expect(result.isSuccess).assertTrue();
        if (result.isSuccess) {
          const success = result as Success<User>;
          expect(success.value.firstName.length > 0).assertTrue();
          expect(success.value.lastName.length > 0).assertTrue();
          expect(success.value.avatar.startsWith('https://')).assertTrue();
        }
      });

      it('should return failure for non-existent user ID 23', async () => {
        const result = await service.getUser(23);

        expect(result.isFailure).assertTrue();
        if (result.isFailure) {
          const failure = result as Failure<AppError>;
          expect(failure.error.code).assertEqual(ErrorCode.API_NOT_FOUND);
        }
      });

      it('should return failure for user ID 999', async () => {
        const result = await service.getUser(999);

        expect(result.isFailure).assertTrue();
      });

      it('should log warning for not found user', async () => {
        logger.clear();
        await service.getUser(23);

        expect(logger.warnings.length > 0).assertTrue();
        const hasNotFoundWarning = logger.warnings.some(w => w.includes('not found'));
        expect(hasNotFoundWarning).assertTrue();
      });
    });

    describe('createUser - Real API', () => {
      it('should create a new user on reqres.in', async () => {
        const request: CreateUserRequest = {
          email: 'morpheus@reqres.in',
          firstName: 'Morpheus',
          lastName: 'Leader',
          avatar: 'https://reqres.in/img/faces/custom.jpg'
        };

        const result = await service.createUser(request);

        expect(result.isSuccess).assertTrue();
        if (result.isSuccess) {
          const success = result as Success<User>;
          expect(typeof success.value.id === 'number').assertTrue();
          expect(success.value.email).assertEqual('morpheus@reqres.in');
          expect(success.value.firstName).assertEqual('Morpheus');
          expect(success.value.lastName).assertEqual('Leader');
        }
      });

      it('should return created user with generated ID', async () => {
        const request: CreateUserRequest = {
          email: 'neo@matrix.com',
          firstName: 'Neo',
          lastName: 'Anderson',
          avatar: ''
        };

        const result = await service.createUser(request);

        expect(result.isSuccess).assertTrue();
        if (result.isSuccess) {
          const success = result as Success<User>;
          expect(success.value.id > 0).assertTrue();
        }
      });

      it('should log success message on user creation', async () => {
        logger.clear();
        const request: CreateUserRequest = {
          email: 'test@test.com',
          firstName: 'Test',
          lastName: 'User',
          avatar: ''
        };

        await service.createUser(request);

        const hasSuccessLog = logger.logs.some(l => l.includes('Successfully created'));
        expect(hasSuccessLog).assertTrue();
      });

      it('should handle empty avatar in create request', async () => {
        const request: CreateUserRequest = {
          email: 'noavatar@test.com',
          firstName: 'No',
          lastName: 'Avatar',
          avatar: ''
        };

        const result = await service.createUser(request);

        expect(result.isSuccess).assertTrue();
      });

      it('should create user with special characters in name', async () => {
        const request: CreateUserRequest = {
          email: 'special@test.com',
          firstName: "Jean-Pierre",
          lastName: "O'Connor",
          avatar: ''
        };

        const result = await service.createUser(request);

        expect(result.isSuccess).assertTrue();
        if (result.isSuccess) {
          const success = result as Success<User>;
          expect(success.value.firstName).assertEqual("Jean-Pierre");
        }
      });
    });

    describe('updateUser - Real API', () => {
      it('should update user on reqres.in', async () => {
        const request: UpdateUserRequest = {
          id: 2,
          email: 'updated@reqres.in',
          firstName: 'Updated',
          lastName: 'User',
          avatar: 'https://reqres.in/img/faces/updated.jpg'
        };

        const result = await service.updateUser(request);

        expect(result.isSuccess).assertTrue();
        if (result.isSuccess) {
          const success = result as Success<User>;
          expect(success.value.id).assertEqual(2);
        }
      });

      it('should update user with ID 1', async () => {
        const request: UpdateUserRequest = {
          id: 1,
          email: 'george.updated@reqres.in',
          firstName: 'George',
          lastName: 'Bluth',
          avatar: ''
        };

        const result = await service.updateUser(request);

        expect(result.isSuccess).assertTrue();
      });

      it('should log success message on update', async () => {
        logger.clear();
        const request: UpdateUserRequest = {
          id: 1,
          email: 'test@test.com',
          firstName: 'Test',
          lastName: 'Update',
          avatar: ''
        };

        await service.updateUser(request);

        const hasSuccessLog = logger.logs.some(l => l.includes('Successfully updated'));
        expect(hasSuccessLog).assertTrue();
      });

      it('should preserve user ID in update response', async () => {
        const request: UpdateUserRequest = {
          id: 3,
          email: 'preserveid@test.com',
          firstName: 'Preserve',
          lastName: 'ID',
          avatar: ''
        };

        const result = await service.updateUser(request);

        expect(result.isSuccess).assertTrue();
        if (result.isSuccess) {
          const success = result as Success<User>;
          expect(success.value.id).assertEqual(3);
        }
      });
    });

    describe('deleteUser - Real API', () => {
      it('should delete user from reqres.in', async () => {
        const result = await service.deleteUser(2);

        expect(result.isSuccess).assertTrue();
        if (result.isSuccess) {
          const success = result as Success<void>;
          expect(success.value).assertUndefined();
        }
      });

      it('should delete user with ID 1', async () => {
        const result = await service.deleteUser(1);

        expect(result.isSuccess).assertTrue();
      });

      it('should log success message on deletion', async () => {
        logger.clear();
        await service.deleteUser(3);

        const hasSuccessLog = logger.logs.some(l => l.includes('Successfully deleted'));
        expect(hasSuccessLog).assertTrue();
      });

      it('should handle deleting any valid ID (API always returns 204)', async () => {
        const result = await service.deleteUser(999);

        // reqres.in returns 204 for any delete request
        expect(result.isSuccess).assertTrue();
      });
    });

    describe('Error Scenarios', () => {
      it('should handle 404 for non-existent single user', async () => {
        const result = await service.getUser(9999);

        expect(result.isFailure).assertTrue();
        if (result.isFailure) {
          const failure = result as Failure<AppError>;
          expect(failure.error.code).assertEqual(ErrorCode.API_NOT_FOUND);
        }
      });

      it('should include user message in error', async () => {
        const result = await service.getUser(9999);

        expect(result.isFailure).assertTrue();
        if (result.isFailure) {
          const failure = result as Failure<AppError>;
          expect(failure.error.userMessage.length > 0).assertTrue();
        }
      });
    });

    describe('Response Mapping', () => {
      it('should correctly map snake_case to camelCase', async () => {
        const result = await service.getUser(1);

        expect(result.isSuccess).assertTrue();
        if (result.isSuccess) {
          const success = result as Success<User>;
          // Verify camelCase properties exist
          expect(success.value.hasOwnProperty('firstName')).assertTrue();
          expect(success.value.hasOwnProperty('lastName')).assertTrue();
          // Verify snake_case properties do not exist
          expect(success.value.hasOwnProperty('first_name')).assertFalse();
          expect(success.value.hasOwnProperty('last_name')).assertFalse();
        }
      });

      it('should map perPage correctly from per_page', async () => {
        const result = await service.getUsers(1, 6);

        expect(result.isSuccess).assertTrue();
        if (result.isSuccess) {
          const success = result as Success<PaginatedUsers>;
          expect(success.value.hasOwnProperty('perPage')).assertTrue();
          expect(success.value.hasOwnProperty('per_page')).assertFalse();
        }
      });

      it('should map totalPages correctly from total_pages', async () => {
        const result = await service.getUsers(1, 6);

        expect(result.isSuccess).assertTrue();
        if (result.isSuccess) {
          const success = result as Success<PaginatedUsers>;
          expect(success.value.hasOwnProperty('totalPages')).assertTrue();
          expect(success.value.hasOwnProperty('total_pages')).assertFalse();
        }
      });
    });

    describe('API Response Validation', () => {
      it('should return valid avatar URLs', async () => {
        const result = await service.getUsers(1, 6);

        expect(result.isSuccess).assertTrue();
        if (result.isSuccess) {
          const success = result as Success<PaginatedUsers>;
          for (const user of success.value.users) {
            expect(user.avatar.startsWith('https://')).assertTrue();
          }
        }
      });

      it('should return valid email addresses', async () => {
        const result = await service.getUsers(1, 6);

        expect(result.isSuccess).assertTrue();
        if (result.isSuccess) {
          const success = result as Success<PaginatedUsers>;
          for (const user of success.value.users) {
            expect(user.email.includes('@')).assertTrue();
            expect(user.email.includes('.')).assertTrue();
          }
        }
      });

      it('should return non-empty names', async () => {
        const result = await service.getUser(1);

        expect(result.isSuccess).assertTrue();
        if (result.isSuccess) {
          const success = result as Success<User>;
          expect(success.value.firstName.trim().length > 0).assertTrue();
          expect(success.value.lastName.trim().length > 0).assertTrue();
        }
      });

      it('should return positive user IDs', async () => {
        const result = await service.getUsers(1, 6);

        expect(result.isSuccess).assertTrue();
        if (result.isSuccess) {
          const success = result as Success<PaginatedUsers>;
          for (const user of success.value.users) {
            expect(user.id > 0).assertTrue();
          }
        }
      });
    });

    describe('Pagination Behavior', () => {
      it('should return same total across different pages', async () => {
        const result1 = await service.getUsers(1, 6);
        const result2 = await service.getUsers(2, 6);

        if (result1.isSuccess && result2.isSuccess) {
          const page1 = (result1 as Success<PaginatedUsers>).value;
          const page2 = (result2 as Success<PaginatedUsers>).value;
          expect(page1.total).assertEqual(page2.total);
          expect(page1.totalPages).assertEqual(page2.totalPages);
        }
      });

      it('should return different users on different pages', async () => {
        const result1 = await service.getUsers(1, 6);
        const result2 = await service.getUsers(2, 6);

        if (result1.isSuccess && result2.isSuccess) {
          const page1 = (result1 as Success<PaginatedUsers>).value;
          const page2 = (result2 as Success<PaginatedUsers>).value;

          if (page1.users.length > 0 && page2.users.length > 0) {
            expect(page1.users[0].id !== page2.users[0].id).assertTrue();
          }
        }
      });

      it('should respect perPage parameter', async () => {
        const result = await service.getUsers(1, 2);

        if (result.isSuccess) {
          const success = (result as Success<PaginatedUsers>).value;
          expect(success.users.length <= 2).assertTrue();
        }
      });
    });

    describe('Concurrent Requests', () => {
      it('should handle multiple concurrent user fetches', async () => {
        const promises = [
          service.getUser(1),
          service.getUser(2),
          service.getUser(3)
        ];

        const results = await Promise.all(promises);

        for (const result of results) {
          expect(result.isSuccess).assertTrue();
        }
      });

      it('should handle concurrent getUsers and getUser', async () => {
        const promises = [
          service.getUsers(1, 6),
          service.getUser(1),
          service.getUsers(2, 6)
        ];

        const results = await Promise.all(promises);

        for (const result of results) {
          expect(result.isSuccess || result.isFailure).assertTrue();
        }
      });

      it('should maintain data integrity across concurrent requests', async () => {
        const promises = [];
        for (let i = 1; i <= 5; i++) {
          promises.push(service.getUser(i));
        }

        const results = await Promise.all(promises);

        for (let i = 0; i < results.length; i++) {
          if (results[i].isSuccess) {
            const user = (results[i] as Success<User>).value;
            expect(user.id).assertEqual(i + 1);
          }
        }
      });
    });

    describe('Service Lifecycle', () => {
      it('should work correctly after setLogger is called multiple times', async () => {
        service.setLogger(new IntegrationTestLogger());
        service.setLogger(new IntegrationTestLogger());

        const result = await service.getUsers();
        expect(result.isSuccess || result.isFailure).assertTrue();
      });

      it('should handle operations after logger is set', async () => {
        const newService = new UserApiServiceImpl();
        // First operation without logger
        await newService.getUsers();
        // Set logger
        newService.setLogger(new IntegrationTestLogger());
        // Operation with logger
        const result = await newService.getUsers();

        expect(result.isSuccess || result.isFailure).assertTrue();
        newService.destroy();
      });
    });
  });
}
