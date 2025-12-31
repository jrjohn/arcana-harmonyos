/**
 * DataMigration - Migrates data from Preferences to RelationalStore
 *
 * Handles one-time migration of user data from the old Preferences-based
 * storage to the new RDB (RelationalStore) based storage.
 */

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { RdbStoreManager } from './RdbStoreManager';
import { UserLocalDataSourceRdb } from './UserLocalDataSourceRdb';
import { LocalUser, LocalUserImpl, SyncStatus } from '../../domain/models/User';
import { ILogger } from '../../core/di/interfaces';

const TAG = 'DataMigration';
const PREFERENCES_NAME = 'arcana_users';
const USERS_KEY = 'users_data';
const LAST_SYNC_KEY = 'last_sync_time';
const MIGRATION_VERSION_KEY = 'migration_version';
const CURRENT_MIGRATION_VERSION = 1;

/**
 * Migration result containing statistics
 */
export interface MigrationResult {
  success: boolean;
  usersMigrated: number;
  lastSyncMigrated: boolean;
  error?: string;
  durationMs: number;
}

/**
 * Raw user data structure from Preferences JSON
 */
interface RawUserData {
  id: number;
  email: string;
  firstName: string;
  lastName: string;
  avatar: string;
  syncStatus: string;
  localId: string;
  createdAt: number;
  updatedAt: number;
  syncAttempts?: number;
  syncError?: string;
}

/**
 * DataMigration - Handles migration from Preferences to RDB
 */
export class DataMigration {
  private context: common.UIAbilityContext;
  private logger?: ILogger;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  /**
   * Sets the logger for debugging
   */
  setLogger(logger: ILogger): void {
    this.logger = logger;
  }

  /**
   * Checks if migration is needed
   */
  async isMigrationNeeded(): Promise<boolean> {
    try {
      const prefs = await preferences.getPreferences(this.context, PREFERENCES_NAME);
      const migrationVersion = await prefs.get(MIGRATION_VERSION_KEY, 0) as number;

      // Migration needed if version is less than current
      const needed = migrationVersion < CURRENT_MIGRATION_VERSION;

      // Also check if there's any data to migrate
      if (needed) {
        const usersJson = await prefs.get(USERS_KEY, '[]') as string;
        const users = JSON.parse(usersJson) as RawUserData[];
        if (users.length === 0) {
          // No data to migrate, mark as done
          await this.markMigrationComplete(prefs);
          return false;
        }
      }

      this.log(`Migration needed: ${needed}, current version: ${migrationVersion}`);
      return needed;
    } catch (error) {
      this.logError(`Failed to check migration status: ${error}`);
      return false;
    }
  }

  /**
   * Performs the migration from Preferences to RDB
   */
  async migrate(): Promise<MigrationResult> {
    const startTime = Date.now();
    const result: MigrationResult = {
      success: false,
      usersMigrated: 0,
      lastSyncMigrated: false,
      durationMs: 0
    };

    try {
      this.log('Starting migration from Preferences to RDB...');

      // Initialize RDB
      const dbManager = RdbStoreManager.getInstance();
      await dbManager.initialize(this.context);

      // Create RDB data source
      const rdbDataSource = new UserLocalDataSourceRdb(this.context);
      if (this.logger) {
        rdbDataSource.setLogger(this.logger);
      }
      await rdbDataSource.initialize();

      // Get Preferences instance
      const prefs = await preferences.getPreferences(this.context, PREFERENCES_NAME);

      // Read users from Preferences
      const usersJson = await prefs.get(USERS_KEY, '[]') as string;
      const rawUsers = JSON.parse(usersJson) as RawUserData[];
      this.log(`Found ${rawUsers.length} users to migrate`);

      // Convert and save to RDB
      if (rawUsers.length > 0) {
        const localUsers = rawUsers.map(raw => this.convertToLocalUser(raw));
        await rdbDataSource.saveUsers(localUsers);
        result.usersMigrated = localUsers.length;
        this.log(`Migrated ${localUsers.length} users to RDB`);
      }

      // Migrate last sync time
      const lastSyncTime = await prefs.get(LAST_SYNC_KEY, 0) as number;
      if (lastSyncTime > 0) {
        await rdbDataSource.setLastSyncTime(lastSyncTime);
        result.lastSyncMigrated = true;
        this.log(`Migrated last sync time: ${new Date(lastSyncTime).toISOString()}`);
      }

      // Mark migration as complete
      await this.markMigrationComplete(prefs);

      result.success = true;
      this.log('Migration completed successfully');
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      result.error = errorMessage;
      this.logError(`Migration failed: ${errorMessage}`);
    }

    result.durationMs = Date.now() - startTime;
    return result;
  }

  /**
   * Converts raw user data from Preferences to LocalUser
   */
  private convertToLocalUser(raw: RawUserData): LocalUser {
    const syncStatus = this.parseSyncStatus(raw.syncStatus);

    return new LocalUserImpl(
      raw.id,
      raw.email,
      raw.firstName,
      raw.lastName,
      raw.avatar,
      syncStatus,
      raw.localId,
      raw.createdAt,
      raw.updatedAt,
      raw.syncAttempts ?? 0,
      raw.syncError
    );
  }

  /**
   * Parses sync status string to enum
   */
  private parseSyncStatus(status: string): SyncStatus {
    switch (status) {
      case 'synced':
        return SyncStatus.SYNCED;
      case 'pending_create':
        return SyncStatus.PENDING_CREATE;
      case 'pending_update':
        return SyncStatus.PENDING_UPDATE;
      case 'pending_delete':
        return SyncStatus.PENDING_DELETE;
      case 'sync_error':
        return SyncStatus.SYNC_ERROR;
      default:
        return SyncStatus.SYNCED;
    }
  }

  /**
   * Marks migration as complete in Preferences
   */
  private async markMigrationComplete(prefs: preferences.Preferences): Promise<void> {
    await prefs.put(MIGRATION_VERSION_KEY, CURRENT_MIGRATION_VERSION);
    await prefs.flush();
    this.log(`Marked migration version: ${CURRENT_MIGRATION_VERSION}`);
  }

  /**
   * Cleans up old Preferences data after successful migration
   * Call this only after verifying RDB data is correct
   */
  async cleanupPreferences(): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(this.context, PREFERENCES_NAME);

      // Remove user data but keep migration version
      await prefs.delete(USERS_KEY);
      await prefs.delete(LAST_SYNC_KEY);
      await prefs.flush();

      this.log('Cleaned up old Preferences data');
    } catch (error) {
      this.logError(`Failed to cleanup Preferences: ${error}`);
    }
  }

  /**
   * Rolls back migration (for testing or error recovery)
   */
  async rollback(): Promise<void> {
    try {
      const prefs = await preferences.getPreferences(this.context, PREFERENCES_NAME);
      await prefs.put(MIGRATION_VERSION_KEY, 0);
      await prefs.flush();
      this.log('Migration rolled back');
    } catch (error) {
      this.logError(`Failed to rollback migration: ${error}`);
    }
  }

  // ===== Logging =====

  private log(message: string): void {
    if (this.logger) {
      this.logger.i(TAG, message);
    } else {
      console.info(`${TAG}: ${message}`);
    }
  }

  private logError(message: string): void {
    if (this.logger) {
      this.logger.e(TAG, message);
    } else {
      console.error(`${TAG}: ${message}`);
    }
  }
}
