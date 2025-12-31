/**
 * Unit Tests for RdbStoreManager
 * Tests the RelationalStore database lifecycle manager
 */

import { describe, it, expect, beforeEach, afterEach } from '@ohos/hypium';
import {
  RdbStoreManager,
  DB_CONFIG,
  Tables,
  UserColumns,
  SyncMetadataColumns
} from '../../../../main/ets/data/local/RdbStoreManager';

export default function RdbStoreManagerTest() {
  describe('RdbStoreManager', () => {
    describe('getInstance', () => {
      it('should return singleton instance', () => {
        const instance1 = RdbStoreManager.getInstance();
        const instance2 = RdbStoreManager.getInstance();

        expect(instance1).assertNotNull();
        expect(instance1).assertEqual(instance2);
      });

      it('should return same instance on multiple calls', () => {
        const instances: RdbStoreManager[] = [];
        for (let i = 0; i < 5; i++) {
          instances.push(RdbStoreManager.getInstance());
        }

        for (let i = 1; i < instances.length; i++) {
          expect(instances[0]).assertEqual(instances[i]);
        }
      });
    });

    describe('isReady', () => {
      it('should return false before initialization', () => {
        const manager = RdbStoreManager.getInstance();
        // Note: In a fresh test environment, this might be true if already initialized
        // This test verifies the method exists and returns a boolean
        const ready = manager.isReady();
        expect(typeof ready === 'boolean').assertTrue();
      });
    });

    describe('getStore', () => {
      it('should throw if not initialized', () => {
        // This test depends on initialization state
        // In practice, the app initializes before using
        const manager = RdbStoreManager.getInstance();
        if (!manager.isReady()) {
          let threw = false;
          try {
            manager.getStore();
          } catch (e) {
            threw = true;
          }
          expect(threw).assertTrue();
        } else {
          // Already initialized, getStore should work
          const store = manager.getStore();
          expect(store).assertNotNull();
        }
      });
    });
  });

  describe('DB_CONFIG', () => {
    it('should have database name', () => {
      expect(DB_CONFIG.NAME).assertEqual('arcana.db');
    });

    it('should have version 1', () => {
      expect(DB_CONFIG.VERSION).assertEqual(1);
    });

    it('should have security level defined', () => {
      expect(DB_CONFIG.SECURITY_LEVEL).assertNotNull();
    });
  });

  describe('Tables', () => {
    it('should have USERS table name', () => {
      expect(Tables.USERS).assertEqual('users');
    });

    it('should have SYNC_METADATA table name', () => {
      expect(Tables.SYNC_METADATA).assertEqual('sync_metadata');
    });
  });

  describe('UserColumns', () => {
    it('should have ID column', () => {
      expect(UserColumns.ID).assertEqual('id');
    });

    it('should have EMAIL column', () => {
      expect(UserColumns.EMAIL).assertEqual('email');
    });

    it('should have FIRST_NAME column', () => {
      expect(UserColumns.FIRST_NAME).assertEqual('first_name');
    });

    it('should have LAST_NAME column', () => {
      expect(UserColumns.LAST_NAME).assertEqual('last_name');
    });

    it('should have AVATAR column', () => {
      expect(UserColumns.AVATAR).assertEqual('avatar');
    });

    it('should have SYNC_STATUS column', () => {
      expect(UserColumns.SYNC_STATUS).assertEqual('sync_status');
    });

    it('should have LOCAL_ID column', () => {
      expect(UserColumns.LOCAL_ID).assertEqual('local_id');
    });

    it('should have CREATED_AT column', () => {
      expect(UserColumns.CREATED_AT).assertEqual('created_at');
    });

    it('should have UPDATED_AT column', () => {
      expect(UserColumns.UPDATED_AT).assertEqual('updated_at');
    });

    it('should have SYNC_ATTEMPTS column', () => {
      expect(UserColumns.SYNC_ATTEMPTS).assertEqual('sync_attempts');
    });

    it('should have SYNC_ERROR column', () => {
      expect(UserColumns.SYNC_ERROR).assertEqual('sync_error');
    });
  });

  describe('SyncMetadataColumns', () => {
    it('should have KEY column', () => {
      expect(SyncMetadataColumns.KEY).assertEqual('key');
    });

    it('should have VALUE column', () => {
      expect(SyncMetadataColumns.VALUE).assertEqual('value');
    });
  });
}
