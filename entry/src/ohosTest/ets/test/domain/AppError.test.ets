/**
 * Unit Tests for AppError
 */

import { describe, it, expect } from '@ohos/hypium';
import { AppError, AppErrorFactory, ErrorCode, AppErrorOptions } from '../../../../main/ets/domain/models/AppError';

export default function AppErrorTest() {
  describe('ErrorCode', () => {
    it('should have network error codes', () => {
      expect(ErrorCode.NETWORK_ERROR).assertEqual('E1000');
      expect(ErrorCode.NETWORK_TIMEOUT).assertEqual('E1001');
      expect(ErrorCode.NETWORK_NO_CONNECTION).assertEqual('E1002');
      expect(ErrorCode.NETWORK_SERVER_ERROR).assertEqual('E1003');
      expect(ErrorCode.NETWORK_CLIENT_ERROR).assertEqual('E1004');
    });

    it('should have API error codes', () => {
      expect(ErrorCode.API_ERROR).assertEqual('E2000');
      expect(ErrorCode.API_NOT_FOUND).assertEqual('E2001');
      expect(ErrorCode.API_UNAUTHORIZED).assertEqual('E2002');
      expect(ErrorCode.API_FORBIDDEN).assertEqual('E2003');
      expect(ErrorCode.API_RATE_LIMITED).assertEqual('E2004');
      expect(ErrorCode.API_VALIDATION_ERROR).assertEqual('E2005');
    });

    it('should have database error codes', () => {
      expect(ErrorCode.DATABASE_ERROR).assertEqual('E3000');
      expect(ErrorCode.DATABASE_NOT_FOUND).assertEqual('E3001');
      expect(ErrorCode.DATABASE_CONSTRAINT_VIOLATION).assertEqual('E3002');
      expect(ErrorCode.DATABASE_MIGRATION_ERROR).assertEqual('E3003');
    });

    it('should have validation error codes', () => {
      expect(ErrorCode.VALIDATION_ERROR).assertEqual('E4000');
      expect(ErrorCode.VALIDATION_REQUIRED).assertEqual('E4001');
      expect(ErrorCode.VALIDATION_FORMAT).assertEqual('E4002');
      expect(ErrorCode.VALIDATION_LENGTH).assertEqual('E4003');
      expect(ErrorCode.VALIDATION_RANGE).assertEqual('E4004');
    });

    it('should have sync error codes', () => {
      expect(ErrorCode.SYNC_ERROR).assertEqual('E5000');
      expect(ErrorCode.SYNC_CONFLICT).assertEqual('E5001');
      expect(ErrorCode.SYNC_TIMEOUT).assertEqual('E5002');
      expect(ErrorCode.SYNC_QUEUE_FULL).assertEqual('E5003');
    });

    it('should have unknown error code', () => {
      expect(ErrorCode.UNKNOWN).assertEqual('E9999');
    });
  });

  describe('AppError', () => {
    describe('constructor', () => {
      it('should create error with code and message', () => {
        const error = new AppError(ErrorCode.NETWORK_ERROR, 'Network failed');

        expect(error.code).assertEqual(ErrorCode.NETWORK_ERROR);
        expect(error.message).assertEqual('Network failed');
        expect(error.name).assertEqual('AppError');
      });

      it('should use custom user message when provided', () => {
        const error = new AppError(
          ErrorCode.NETWORK_ERROR,
          'Technical details',
          'User friendly message'
        );

        expect(error.userMessage).assertEqual('User friendly message');
      });

      it('should use default user message when not provided', () => {
        const error = new AppError(ErrorCode.NETWORK_ERROR, 'Network failed');

        expect(error.userMessage).assertEqual('Network error. Please check your connection and try again.');
      });

      it('should set timestamp', () => {
        const before = Date.now();
        const error = new AppError(ErrorCode.NETWORK_ERROR, 'Test');
        const after = Date.now();

        expect(error.timestamp >= before).assertTrue();
        expect(error.timestamp <= after).assertTrue();
      });

      it('should handle options with debugInfo', () => {
        const options: AppErrorOptions = { debugInfo: 'Debug info here' };
        const error = new AppError(ErrorCode.NETWORK_ERROR, 'Test', undefined, options);

        expect(error.debugInfo).assertEqual('Debug info here');
      });

      it('should handle options with cause', () => {
        const cause = new Error('Original error');
        const options: AppErrorOptions = { cause };
        const error = new AppError(ErrorCode.NETWORK_ERROR, 'Test', undefined, options);

        expect(error.cause?.message).assertEqual('Original error');
      });

      it('should handle options with recoverable flag', () => {
        const options: AppErrorOptions = { recoverable: false };
        const error = new AppError(ErrorCode.NETWORK_ERROR, 'Test', undefined, options);

        expect(error.recoverable).assertFalse();
      });
    });

    describe('default user messages', () => {
      it('should have correct message for NETWORK_ERROR', () => {
        const error = new AppError(ErrorCode.NETWORK_ERROR, 'Test');
        expect(error.userMessage).assertEqual('Network error. Please check your connection and try again.');
      });

      it('should have correct message for NETWORK_TIMEOUT', () => {
        const error = new AppError(ErrorCode.NETWORK_TIMEOUT, 'Test');
        expect(error.userMessage).assertEqual('Network error. Please check your connection and try again.');
      });

      it('should have correct message for NETWORK_NO_CONNECTION', () => {
        const error = new AppError(ErrorCode.NETWORK_NO_CONNECTION, 'Test');
        expect(error.userMessage).assertEqual('No internet connection. Your changes will be saved locally.');
      });

      it('should have correct message for NETWORK_SERVER_ERROR', () => {
        const error = new AppError(ErrorCode.NETWORK_SERVER_ERROR, 'Test');
        expect(error.userMessage).assertEqual('Server error. Please try again later.');
      });

      it('should have correct message for API_NOT_FOUND', () => {
        const error = new AppError(ErrorCode.API_NOT_FOUND, 'Test');
        expect(error.userMessage).assertEqual('The requested resource was not found.');
      });

      it('should have correct message for API_UNAUTHORIZED', () => {
        const error = new AppError(ErrorCode.API_UNAUTHORIZED, 'Test');
        expect(error.userMessage).assertEqual('You are not authorized to perform this action.');
      });

      it('should have correct message for API_RATE_LIMITED', () => {
        const error = new AppError(ErrorCode.API_RATE_LIMITED, 'Test');
        expect(error.userMessage).assertEqual('Too many requests. Please wait a moment and try again.');
      });

      it('should have correct message for DATABASE_ERROR', () => {
        const error = new AppError(ErrorCode.DATABASE_ERROR, 'Test');
        expect(error.userMessage).assertEqual('Failed to save data locally. Please try again.');
      });

      it('should have correct message for VALIDATION_ERROR', () => {
        const error = new AppError(ErrorCode.VALIDATION_ERROR, 'Test');
        expect(error.userMessage).assertEqual('Please check your input and try again.');
      });

      it('should have correct message for SYNC_ERROR', () => {
        const error = new AppError(ErrorCode.SYNC_ERROR, 'Test');
        expect(error.userMessage).assertEqual('Failed to sync data. Will retry automatically.');
      });

      it('should have correct message for SYNC_CONFLICT', () => {
        const error = new AppError(ErrorCode.SYNC_CONFLICT, 'Test');
        expect(error.userMessage).assertEqual('Data conflict detected. Please refresh and try again.');
      });

      it('should have default message for UNKNOWN', () => {
        const error = new AppError(ErrorCode.UNKNOWN, 'Test');
        expect(error.userMessage).assertEqual('An unexpected error occurred. Please try again.');
      });
    });

    describe('recoverable by default', () => {
      it('should be recoverable for NETWORK_ERROR', () => {
        const error = new AppError(ErrorCode.NETWORK_ERROR, 'Test');
        expect(error.recoverable).assertTrue();
      });

      it('should be recoverable for NETWORK_TIMEOUT', () => {
        const error = new AppError(ErrorCode.NETWORK_TIMEOUT, 'Test');
        expect(error.recoverable).assertTrue();
      });

      it('should be recoverable for NETWORK_NO_CONNECTION', () => {
        const error = new AppError(ErrorCode.NETWORK_NO_CONNECTION, 'Test');
        expect(error.recoverable).assertTrue();
      });

      it('should be recoverable for API_RATE_LIMITED', () => {
        const error = new AppError(ErrorCode.API_RATE_LIMITED, 'Test');
        expect(error.recoverable).assertTrue();
      });

      it('should be recoverable for SYNC_ERROR', () => {
        const error = new AppError(ErrorCode.SYNC_ERROR, 'Test');
        expect(error.recoverable).assertTrue();
      });

      it('should not be recoverable for API_NOT_FOUND', () => {
        const error = new AppError(ErrorCode.API_NOT_FOUND, 'Test');
        expect(error.recoverable).assertFalse();
      });

      it('should not be recoverable for VALIDATION_ERROR', () => {
        const error = new AppError(ErrorCode.VALIDATION_ERROR, 'Test');
        expect(error.recoverable).assertFalse();
      });
    });

    describe('toLogString', () => {
      it('should format basic error', () => {
        const error = new AppError(ErrorCode.NETWORK_ERROR, 'Connection failed');
        const logString = error.toLogString();

        expect(logString).assertEqual('[E1000] Connection failed');
      });

      it('should include debug info when present', () => {
        const options: AppErrorOptions = { debugInfo: 'Request ID: 123' };
        const error = new AppError(ErrorCode.NETWORK_ERROR, 'Failed', undefined, options);
        const logString = error.toLogString();

        expect(logString.includes('Debug: Request ID: 123')).assertTrue();
      });

      it('should include cause when present', () => {
        const cause = new Error('Original cause');
        const options: AppErrorOptions = { cause };
        const error = new AppError(ErrorCode.NETWORK_ERROR, 'Failed', undefined, options);
        const logString = error.toLogString();

        expect(logString.includes('Cause: Original cause')).assertTrue();
      });

      it('should include both debug info and cause', () => {
        const cause = new Error('Cause message');
        const options: AppErrorOptions = { debugInfo: 'Debug', cause };
        const error = new AppError(ErrorCode.NETWORK_ERROR, 'Failed', undefined, options);
        const logString = error.toLogString();

        expect(logString.includes('Debug: Debug')).assertTrue();
        expect(logString.includes('Cause: Cause message')).assertTrue();
      });
    });
  });

  describe('AppErrorFactory', () => {
    describe('networkError', () => {
      it('should create network error', () => {
        const error = AppErrorFactory.networkError('Connection failed');

        expect(error.code).assertEqual(ErrorCode.NETWORK_ERROR);
        expect(error.message).assertEqual('Connection failed');
        expect(error.recoverable).assertTrue();
      });

      it('should include cause when provided', () => {
        const cause = new Error('Original');
        const error = AppErrorFactory.networkError('Failed', cause);

        expect(error.cause?.message).assertEqual('Original');
      });
    });

    describe('networkTimeout', () => {
      it('should create timeout error', () => {
        const error = AppErrorFactory.networkTimeout();

        expect(error.code).assertEqual(ErrorCode.NETWORK_TIMEOUT);
        expect(error.message).assertEqual('Request timed out');
      });
    });

    describe('noConnection', () => {
      it('should create no connection error', () => {
        const error = AppErrorFactory.noConnection();

        expect(error.code).assertEqual(ErrorCode.NETWORK_NO_CONNECTION);
        expect(error.message).assertEqual('No network connection');
      });
    });

    describe('serverError', () => {
      it('should create server error with status code', () => {
        const error = AppErrorFactory.serverError(500);

        expect(error.code).assertEqual(ErrorCode.NETWORK_SERVER_ERROR);
        expect(error.message).assertEqual('Server error: 500');
        expect(error.debugInfo).assertEqual('HTTP 500');
      });

      it('should use custom message when provided', () => {
        const error = AppErrorFactory.serverError(503, 'Service unavailable');

        expect(error.userMessage).assertEqual('Service unavailable');
      });
    });

    describe('apiNotFound', () => {
      it('should create not found error', () => {
        const error = AppErrorFactory.apiNotFound('User');

        expect(error.code).assertEqual(ErrorCode.API_NOT_FOUND);
        expect(error.message).assertEqual('User not found');
      });
    });

    describe('validationError', () => {
      it('should create validation error', () => {
        const error = AppErrorFactory.validationError('email', 'Invalid format');

        expect(error.code).assertEqual(ErrorCode.VALIDATION_ERROR);
        expect(error.message).assertEqual('Validation failed for email: Invalid format');
        expect(error.userMessage).assertEqual('Invalid format');
        expect(error.recoverable).assertFalse();
      });
    });

    describe('databaseError', () => {
      it('should create database error', () => {
        const error = AppErrorFactory.databaseError('insert');

        expect(error.code).assertEqual(ErrorCode.DATABASE_ERROR);
        expect(error.message).assertEqual('Database insert failed');
      });

      it('should include cause when provided', () => {
        const cause = new Error('Constraint violation');
        const error = AppErrorFactory.databaseError('insert', cause);

        expect(error.cause?.message).assertEqual('Constraint violation');
      });
    });

    describe('syncError', () => {
      it('should create sync error', () => {
        const error = AppErrorFactory.syncError('Sync failed');

        expect(error.code).assertEqual(ErrorCode.SYNC_ERROR);
        expect(error.message).assertEqual('Sync failed');
        expect(error.recoverable).assertTrue();
      });
    });

    describe('syncConflict', () => {
      it('should create sync conflict error', () => {
        const error = AppErrorFactory.syncConflict('user_123');

        expect(error.code).assertEqual(ErrorCode.SYNC_CONFLICT);
        expect(error.message).assertEqual('Sync conflict for resource: user_123');
        expect(error.debugInfo).assertEqual('Resource ID: user_123');
      });
    });

    describe('fromHttpStatus', () => {
      it('should create API_NOT_FOUND for 404', () => {
        const error = AppErrorFactory.fromHttpStatus(404);

        expect(error.code).assertEqual(ErrorCode.API_NOT_FOUND);
      });

      it('should create API_UNAUTHORIZED for 401', () => {
        const error = AppErrorFactory.fromHttpStatus(401);

        expect(error.code).assertEqual(ErrorCode.API_UNAUTHORIZED);
      });

      it('should create API_FORBIDDEN for 403', () => {
        const error = AppErrorFactory.fromHttpStatus(403);

        expect(error.code).assertEqual(ErrorCode.API_FORBIDDEN);
      });

      it('should create API_RATE_LIMITED for 429', () => {
        const error = AppErrorFactory.fromHttpStatus(429);

        expect(error.code).assertEqual(ErrorCode.API_RATE_LIMITED);
      });

      it('should create server error for 5xx', () => {
        const error500 = AppErrorFactory.fromHttpStatus(500);
        const error502 = AppErrorFactory.fromHttpStatus(502);
        const error503 = AppErrorFactory.fromHttpStatus(503);

        expect(error500.code).assertEqual(ErrorCode.NETWORK_SERVER_ERROR);
        expect(error502.code).assertEqual(ErrorCode.NETWORK_SERVER_ERROR);
        expect(error503.code).assertEqual(ErrorCode.NETWORK_SERVER_ERROR);
      });

      it('should create client error for 4xx', () => {
        const error400 = AppErrorFactory.fromHttpStatus(400);
        const error422 = AppErrorFactory.fromHttpStatus(422);

        expect(error400.code).assertEqual(ErrorCode.NETWORK_CLIENT_ERROR);
        expect(error422.code).assertEqual(ErrorCode.NETWORK_CLIENT_ERROR);
      });

      it('should create unknown error for other status codes', () => {
        const error = AppErrorFactory.fromHttpStatus(200);

        expect(error.code).assertEqual(ErrorCode.UNKNOWN);
      });

      it('should use custom message when provided', () => {
        const error = AppErrorFactory.fromHttpStatus(404, 'User not found');

        expect(error.message).assertEqual('User not found');
      });
    });

    describe('unknown', () => {
      it('should create unknown error', () => {
        const error = AppErrorFactory.unknown();

        expect(error.code).assertEqual(ErrorCode.UNKNOWN);
        expect(error.message).assertEqual('Unknown error');
      });

      it('should use cause message when provided', () => {
        const cause = new Error('Something happened');
        const error = AppErrorFactory.unknown(cause);

        expect(error.message).assertEqual('Something happened');
        expect(error.cause?.message).assertEqual('Something happened');
      });
    });
  });
}
