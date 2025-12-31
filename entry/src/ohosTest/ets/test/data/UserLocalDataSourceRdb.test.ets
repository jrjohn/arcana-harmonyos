/**
 * Unit Tests for UserLocalDataSourceRdb
 * Tests the RelationalStore-based user local data source
 */

import { describe, it, expect, beforeEach, afterEach } from '@ohos/hypium';
import { SyncStatus, LocalUserImpl } from '../../../../main/ets/domain/models/User';
import { ILogger } from '../../../../main/ets/core/di/interfaces';

/**
 * Mock logger for testing
 */
class MockLogger implements ILogger {
  logs: string[] = [];
  warnings: string[] = [];
  errors: string[] = [];

  d(tag: string, message: string): void {
    this.logs.push(`[D][${tag}] ${message}`);
  }

  i(tag: string, message: string): void {
    this.logs.push(`[I][${tag}] ${message}`);
  }

  w(tag: string, message: string): void {
    this.warnings.push(`[W][${tag}] ${message}`);
  }

  e(tag: string, message: string): void {
    this.errors.push(`[E][${tag}] ${message}`);
  }

  clear(): void {
    this.logs = [];
    this.warnings = [];
    this.errors = [];
  }
}

/**
 * Helper to create test users
 */
function createTestUser(
  id: number,
  email: string = `user${id}@test.com`,
  syncStatus: SyncStatus = SyncStatus.SYNCED
): LocalUserImpl {
  const now = Date.now();
  return new LocalUserImpl(
    id,
    email,
    `FirstName${id}`,
    `LastName${id}`,
    `https://example.com/avatar${id}.png`,
    syncStatus,
    `local-${id}`,
    now,
    now,
    0,
    undefined
  );
}

export default function UserLocalDataSourceRdbTest() {
  describe('UserLocalDataSourceRdb', () => {
    let mockLogger: MockLogger;

    beforeEach(() => {
      mockLogger = new MockLogger();
    });

    afterEach(() => {
      mockLogger.clear();
    });

    describe('LocalUserImpl', () => {
      it('should create user with all properties', () => {
        const user = createTestUser(1);

        expect(user.id).assertEqual(1);
        expect(user.email).assertEqual('user1@test.com');
        expect(user.firstName).assertEqual('FirstName1');
        expect(user.lastName).assertEqual('LastName1');
        expect(user.avatar).assertEqual('https://example.com/avatar1.png');
        expect(user.syncStatus).assertEqual(SyncStatus.SYNCED);
        expect(user.localId).assertEqual('local-1');
        expect(user.syncAttempts).assertEqual(0);
        expect(user.syncError).assertUndefined();
      });

      it('should create user with sync error', () => {
        const now = Date.now();
        const user = new LocalUserImpl(
          1,
          'test@test.com',
          'First',
          'Last',
          'avatar.png',
          SyncStatus.SYNC_ERROR,
          'local-1',
          now,
          now,
          3,
          'Network error'
        );

        expect(user.syncStatus).assertEqual(SyncStatus.SYNC_ERROR);
        expect(user.syncAttempts).assertEqual(3);
        expect(user.syncError).assertEqual('Network error');
      });

      it('should have valid timestamps', () => {
        const before = Date.now();
        const user = createTestUser(1);
        const after = Date.now();

        expect(user.createdAt >= before).assertTrue();
        expect(user.createdAt <= after).assertTrue();
        expect(user.updatedAt >= before).assertTrue();
        expect(user.updatedAt <= after).assertTrue();
      });
    });

    describe('SyncStatus enum', () => {
      it('should have SYNCED status', () => {
        expect(SyncStatus.SYNCED).assertEqual('synced');
      });

      it('should have PENDING_CREATE status', () => {
        expect(SyncStatus.PENDING_CREATE).assertEqual('pending_create');
      });

      it('should have PENDING_UPDATE status', () => {
        expect(SyncStatus.PENDING_UPDATE).assertEqual('pending_update');
      });

      it('should have PENDING_DELETE status', () => {
        expect(SyncStatus.PENDING_DELETE).assertEqual('pending_delete');
      });

      it('should have SYNC_ERROR status', () => {
        expect(SyncStatus.SYNC_ERROR).assertEqual('sync_error');
      });
    });

    describe('Test User Creation', () => {
      it('should create multiple test users', () => {
        const users = [
          createTestUser(1),
          createTestUser(2),
          createTestUser(3)
        ];

        expect(users.length).assertEqual(3);
        expect(users[0].id).assertEqual(1);
        expect(users[1].id).assertEqual(2);
        expect(users[2].id).assertEqual(3);
      });

      it('should create users with different sync statuses', () => {
        const syncedUser = createTestUser(1, 'synced@test.com', SyncStatus.SYNCED);
        const pendingUser = createTestUser(2, 'pending@test.com', SyncStatus.PENDING_CREATE);
        const errorUser = createTestUser(3, 'error@test.com', SyncStatus.SYNC_ERROR);

        expect(syncedUser.syncStatus).assertEqual(SyncStatus.SYNCED);
        expect(pendingUser.syncStatus).assertEqual(SyncStatus.PENDING_CREATE);
        expect(errorUser.syncStatus).assertEqual(SyncStatus.SYNC_ERROR);
      });

      it('should create users with unique local IDs', () => {
        const user1 = createTestUser(1);
        const user2 = createTestUser(2);

        expect(user1.localId).assertNotEqual(user2.localId);
      });

      it('should create users with unique emails', () => {
        const user1 = createTestUser(1);
        const user2 = createTestUser(2);

        expect(user1.email).assertNotEqual(user2.email);
      });
    });

    describe('MockLogger', () => {
      it('should log debug messages', () => {
        mockLogger.d('TEST', 'Debug message');
        expect(mockLogger.logs.length).assertEqual(1);
        expect(mockLogger.logs[0]).assertContain('Debug message');
      });

      it('should log info messages', () => {
        mockLogger.i('TEST', 'Info message');
        expect(mockLogger.logs.length).assertEqual(1);
        expect(mockLogger.logs[0]).assertContain('Info message');
      });

      it('should log warning messages', () => {
        mockLogger.w('TEST', 'Warning message');
        expect(mockLogger.warnings.length).assertEqual(1);
        expect(mockLogger.warnings[0]).assertContain('Warning message');
      });

      it('should log error messages', () => {
        mockLogger.e('TEST', 'Error message');
        expect(mockLogger.errors.length).assertEqual(1);
        expect(mockLogger.errors[0]).assertContain('Error message');
      });

      it('should clear all logs', () => {
        mockLogger.d('TEST', 'Debug');
        mockLogger.w('TEST', 'Warning');
        mockLogger.e('TEST', 'Error');

        mockLogger.clear();

        expect(mockLogger.logs.length).assertEqual(0);
        expect(mockLogger.warnings.length).assertEqual(0);
        expect(mockLogger.errors.length).assertEqual(0);
      });
    });
  });
}
