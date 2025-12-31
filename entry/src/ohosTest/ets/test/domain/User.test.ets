/**
 * Unit Tests for User Domain Models
 */

import { describe, it, expect, beforeEach } from '@ohos/hypium';
import {
  User,
  UserImpl,
  UserFactory,
  UserUpdateFields,
  LocalUser,
  LocalUserImpl,
  SyncStatus,
  CreateUserRequest,
  UpdateUserRequest,
  PaginatedUsers
} from '../../../../main/ets/domain/models/User';

export default function UserTest() {
  describe('UserImpl', () => {
    describe('create', () => {
      it('should create a user with all properties', () => {
        const user = UserImpl.create(1, 'test@example.com', 'John', 'Doe', 'https://avatar.url');

        expect(user.id).assertEqual(1);
        expect(user.email).assertEqual('test@example.com');
        expect(user.firstName).assertEqual('John');
        expect(user.lastName).assertEqual('Doe');
        expect(user.avatar).assertEqual('https://avatar.url');
      });

      it('should create a user with empty avatar', () => {
        const user = UserImpl.create(2, 'test@example.com', 'Jane', 'Smith', '');

        expect(user.avatar).assertEqual('');
      });
    });

    describe('copyWith', () => {
      it('should copy user with updated email', () => {
        const original = UserImpl.create(1, 'old@example.com', 'John', 'Doe', 'avatar.png');
        const updated = UserImpl.copyWith(original, { email: 'new@example.com' });

        expect(updated.id).assertEqual(1);
        expect(updated.email).assertEqual('new@example.com');
        expect(updated.firstName).assertEqual('John');
        expect(updated.lastName).assertEqual('Doe');
      });

      it('should copy user with updated firstName', () => {
        const original = UserImpl.create(1, 'test@example.com', 'John', 'Doe', 'avatar.png');
        const updated = UserImpl.copyWith(original, { firstName: 'Jane' });

        expect(updated.firstName).assertEqual('Jane');
        expect(updated.lastName).assertEqual('Doe');
      });

      it('should copy user with updated lastName', () => {
        const original = UserImpl.create(1, 'test@example.com', 'John', 'Doe', 'avatar.png');
        const updated = UserImpl.copyWith(original, { lastName: 'Smith' });

        expect(updated.lastName).assertEqual('Smith');
        expect(updated.firstName).assertEqual('John');
      });

      it('should copy user with updated avatar', () => {
        const original = UserImpl.create(1, 'test@example.com', 'John', 'Doe', 'old-avatar.png');
        const updated = UserImpl.copyWith(original, { avatar: 'new-avatar.png' });

        expect(updated.avatar).assertEqual('new-avatar.png');
      });

      it('should copy user with multiple updates', () => {
        const original = UserImpl.create(1, 'old@example.com', 'John', 'Doe', 'old.png');
        const updates: UserUpdateFields = {
          email: 'new@example.com',
          firstName: 'Jane',
          lastName: 'Smith',
          avatar: 'new.png'
        };
        const updated = UserImpl.copyWith(original, updates);

        expect(updated.email).assertEqual('new@example.com');
        expect(updated.firstName).assertEqual('Jane');
        expect(updated.lastName).assertEqual('Smith');
        expect(updated.avatar).assertEqual('new.png');
      });

      it('should preserve original values when no updates provided', () => {
        const original = UserImpl.create(1, 'test@example.com', 'John', 'Doe', 'avatar.png');
        const updated = UserImpl.copyWith(original, {});

        expect(updated.id).assertEqual(original.id);
        expect(updated.email).assertEqual(original.email);
        expect(updated.firstName).assertEqual(original.firstName);
        expect(updated.lastName).assertEqual(original.lastName);
        expect(updated.avatar).assertEqual(original.avatar);
      });
    });

    describe('getFullName', () => {
      it('should return full name with space', () => {
        const user = UserImpl.create(1, 'test@example.com', 'John', 'Doe', '');
        const fullName = UserImpl.getFullName(user);

        expect(fullName).assertEqual('John Doe');
      });

      it('should handle single character names', () => {
        const user = UserImpl.create(1, 'test@example.com', 'J', 'D', '');
        const fullName = UserImpl.getFullName(user);

        expect(fullName).assertEqual('J D');
      });
    });

    describe('getInitials', () => {
      it('should return uppercase initials', () => {
        const user = UserImpl.create(1, 'test@example.com', 'John', 'Doe', '');
        const initials = UserImpl.getInitials(user);

        expect(initials).assertEqual('JD');
      });

      it('should convert lowercase to uppercase', () => {
        const user = UserImpl.create(1, 'test@example.com', 'john', 'doe', '');
        const initials = UserImpl.getInitials(user);

        expect(initials).assertEqual('JD');
      });
    });
  });

  describe('UserFactory', () => {
    it('should create user using factory', () => {
      const user = UserFactory.create(1, 'test@example.com', 'John', 'Doe', 'avatar.png');

      expect(user.id).assertEqual(1);
      expect(user.email).assertEqual('test@example.com');
    });

    it('should copy user using factory', () => {
      const original = UserFactory.create(1, 'test@example.com', 'John', 'Doe', '');
      const updated = UserFactory.copyWith(original, { firstName: 'Jane' });

      expect(updated.firstName).assertEqual('Jane');
    });

    it('should get full name using factory', () => {
      const user = UserFactory.create(1, 'test@example.com', 'John', 'Doe', '');
      const fullName = UserFactory.getFullName(user);

      expect(fullName).assertEqual('John Doe');
    });

    it('should get initials using factory', () => {
      const user = UserFactory.create(1, 'test@example.com', 'John', 'Doe', '');
      const initials = UserFactory.getInitials(user);

      expect(initials).assertEqual('JD');
    });
  });

  describe('LocalUserImpl', () => {
    describe('fromUser', () => {
      it('should create LocalUser from User with SYNCED status by default', () => {
        const user = UserImpl.create(1, 'test@example.com', 'John', 'Doe', 'avatar.png');
        const localUser = LocalUserImpl.fromUser(user);

        expect(localUser.id).assertEqual(1);
        expect(localUser.email).assertEqual('test@example.com');
        expect(localUser.firstName).assertEqual('John');
        expect(localUser.lastName).assertEqual('Doe');
        expect(localUser.avatar).assertEqual('avatar.png');
        expect(localUser.syncStatus).assertEqual(SyncStatus.SYNCED);
        expect(localUser.syncAttempts).assertEqual(0);
        expect(localUser.syncError).assertUndefined();
      });

      it('should create LocalUser with custom sync status', () => {
        const user = UserImpl.create(1, 'test@example.com', 'John', 'Doe', '');
        const localUser = LocalUserImpl.fromUser(user, SyncStatus.PENDING_UPDATE);

        expect(localUser.syncStatus).assertEqual(SyncStatus.PENDING_UPDATE);
      });

      it('should generate localId with user id', () => {
        const user = UserImpl.create(123, 'test@example.com', 'John', 'Doe', '');
        const localUser = LocalUserImpl.fromUser(user);

        expect(localUser.localId.startsWith('local_123_')).assertTrue();
      });

      it('should set createdAt and updatedAt timestamps', () => {
        const beforeTime = Date.now();
        const user = UserImpl.create(1, 'test@example.com', 'John', 'Doe', '');
        const localUser = LocalUserImpl.fromUser(user);
        const afterTime = Date.now();

        expect(localUser.createdAt >= beforeTime).assertTrue();
        expect(localUser.createdAt <= afterTime).assertTrue();
        expect(localUser.updatedAt >= beforeTime).assertTrue();
        expect(localUser.updatedAt <= afterTime).assertTrue();
      });
    });

    describe('createPending', () => {
      it('should create pending user with negative temp ID', () => {
        const localUser = LocalUserImpl.createPending('test@example.com', 'John', 'Doe', 'avatar.png');

        expect(localUser.id < 0).assertTrue();
        expect(localUser.email).assertEqual('test@example.com');
        expect(localUser.firstName).assertEqual('John');
        expect(localUser.lastName).assertEqual('Doe');
        expect(localUser.syncStatus).assertEqual(SyncStatus.PENDING_CREATE);
      });

      it('should generate pending localId', () => {
        const localUser = LocalUserImpl.createPending('test@example.com', 'John', 'Doe', '');

        expect(localUser.localId.startsWith('local_pending_')).assertTrue();
      });
    });

    describe('markForUpdate', () => {
      it('should mark user for update with PENDING_UPDATE status', () => {
        const original = LocalUserImpl.fromUser(
          UserImpl.create(1, 'test@example.com', 'John', 'Doe', '')
        );
        const marked = LocalUserImpl.markForUpdate(original);

        expect(marked.syncStatus).assertEqual(SyncStatus.PENDING_UPDATE);
        expect(marked.id).assertEqual(original.id);
        expect(marked.localId).assertEqual(original.localId);
      });

      it('should update updatedAt timestamp', () => {
        const original = LocalUserImpl.fromUser(
          UserImpl.create(1, 'test@example.com', 'John', 'Doe', '')
        );
        const originalUpdatedAt = original.updatedAt;

        // Small delay to ensure different timestamp
        const marked = LocalUserImpl.markForUpdate(original);

        expect(marked.updatedAt >= originalUpdatedAt).assertTrue();
      });
    });

    describe('markForDeletion', () => {
      it('should mark user for deletion with PENDING_DELETE status', () => {
        const original = LocalUserImpl.fromUser(
          UserImpl.create(1, 'test@example.com', 'John', 'Doe', '')
        );
        const marked = LocalUserImpl.markForDeletion(original);

        expect(marked.syncStatus).assertEqual(SyncStatus.PENDING_DELETE);
      });
    });

    describe('markAsSynced', () => {
      it('should mark user as synced', () => {
        const pending = LocalUserImpl.createPending('test@example.com', 'John', 'Doe', '');
        const synced = LocalUserImpl.markAsSynced(pending, 100);

        expect(synced.syncStatus).assertEqual(SyncStatus.SYNCED);
        expect(synced.id).assertEqual(100);
        expect(synced.syncAttempts).assertEqual(0);
        expect(synced.syncError).assertUndefined();
      });

      it('should keep original ID if serverId not provided', () => {
        const original = LocalUserImpl.fromUser(
          UserImpl.create(50, 'test@example.com', 'John', 'Doe', '')
        );
        const synced = LocalUserImpl.markAsSynced(original);

        expect(synced.id).assertEqual(50);
      });
    });

    describe('markSyncFailed', () => {
      it('should mark user as sync failed with error message', () => {
        const original = LocalUserImpl.fromUser(
          UserImpl.create(1, 'test@example.com', 'John', 'Doe', '')
        );
        const failed = LocalUserImpl.markSyncFailed(original, 'Network error');

        expect(failed.syncStatus).assertEqual(SyncStatus.SYNC_FAILED);
        expect(failed.syncError).assertEqual('Network error');
        expect(failed.syncAttempts).assertEqual(1);
      });

      it('should increment sync attempts', () => {
        const original = LocalUserImpl.fromUser(
          UserImpl.create(1, 'test@example.com', 'John', 'Doe', '')
        );
        const failed1 = LocalUserImpl.markSyncFailed(original, 'Error 1');
        const failed2 = LocalUserImpl.markSyncFailed(failed1, 'Error 2');

        expect(failed2.syncAttempts).assertEqual(2);
        expect(failed2.syncError).assertEqual('Error 2');
      });
    });

    describe('needsSync', () => {
      it('should return false for SYNCED status', () => {
        const user = LocalUserImpl.fromUser(
          UserImpl.create(1, 'test@example.com', 'John', 'Doe', ''),
          SyncStatus.SYNCED
        );

        expect(LocalUserImpl.needsSync(user)).assertFalse();
      });

      it('should return true for PENDING_CREATE status', () => {
        const user = LocalUserImpl.createPending('test@example.com', 'John', 'Doe', '');

        expect(LocalUserImpl.needsSync(user)).assertTrue();
      });

      it('should return true for PENDING_UPDATE status', () => {
        const original = LocalUserImpl.fromUser(
          UserImpl.create(1, 'test@example.com', 'John', 'Doe', '')
        );
        const user = LocalUserImpl.markForUpdate(original);

        expect(LocalUserImpl.needsSync(user)).assertTrue();
      });

      it('should return true for PENDING_DELETE status', () => {
        const original = LocalUserImpl.fromUser(
          UserImpl.create(1, 'test@example.com', 'John', 'Doe', '')
        );
        const user = LocalUserImpl.markForDeletion(original);

        expect(LocalUserImpl.needsSync(user)).assertTrue();
      });

      it('should return true for SYNC_FAILED status', () => {
        const original = LocalUserImpl.fromUser(
          UserImpl.create(1, 'test@example.com', 'John', 'Doe', '')
        );
        const user = LocalUserImpl.markSyncFailed(original, 'Error');

        expect(LocalUserImpl.needsSync(user)).assertTrue();
      });
    });

    describe('copyWithUpdates', () => {
      it('should copy local user with new field values', () => {
        const original = LocalUserImpl.fromUser(
          UserImpl.create(1, 'old@example.com', 'John', 'Doe', 'old.png')
        );
        const updated = LocalUserImpl.copyWithUpdates(
          original,
          'new@example.com',
          'Jane',
          'Smith',
          'new.png'
        );

        expect(updated.id).assertEqual(1);
        expect(updated.email).assertEqual('new@example.com');
        expect(updated.firstName).assertEqual('Jane');
        expect(updated.lastName).assertEqual('Smith');
        expect(updated.avatar).assertEqual('new.png');
        expect(updated.localId).assertEqual(original.localId);
        expect(updated.syncStatus).assertEqual(original.syncStatus);
      });

      it('should update the updatedAt timestamp', () => {
        const original = LocalUserImpl.fromUser(
          UserImpl.create(1, 'test@example.com', 'John', 'Doe', '')
        );
        const updated = LocalUserImpl.copyWithUpdates(
          original,
          'test@example.com',
          'John',
          'Doe',
          ''
        );

        expect(updated.updatedAt >= original.updatedAt).assertTrue();
      });
    });
  });

  describe('SyncStatus', () => {
    it('should have all expected values', () => {
      expect(SyncStatus.SYNCED).assertEqual('synced');
      expect(SyncStatus.PENDING_CREATE).assertEqual('pending_create');
      expect(SyncStatus.PENDING_UPDATE).assertEqual('pending_update');
      expect(SyncStatus.PENDING_DELETE).assertEqual('pending_delete');
      expect(SyncStatus.SYNC_FAILED).assertEqual('sync_failed');
    });
  });
}
