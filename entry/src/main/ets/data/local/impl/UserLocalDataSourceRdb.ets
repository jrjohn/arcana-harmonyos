/**
 * UserLocalDataSourceRdb - RelationalStore-based implementation
 *
 * Uses HarmonyOS @kit.ArkData RelationalStore (SQLite) for local persistence.
 * Replaces the Preferences-based implementation for better:
 * - Query performance (SQL indexes)
 * - Scalability (thousands of records)
 * - Complex queries (filtering, sorting, pagination)
 * - Data integrity (transactions, constraints)
 */

import { relationalStore, ValuesBucket } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { injectable } from '../../core/di/decorators';
import { IUserLocalDataSource, ILogger } from '../../core/di/interfaces';
import { LocalUser, SyncStatus, LocalUserImpl } from '../../domain/models/User';
import {
  RdbStoreManager,
  Tables,
  UserColumns,
  SyncMetadataColumns
} from './RdbStoreManager';

const TAG = 'UserLocalDataSourceRdb';
const LAST_SYNC_KEY = 'last_sync_time';

/**
 * All user columns for SELECT queries
 */
const ALL_USER_COLUMNS: string[] = [
  UserColumns.ID,
  UserColumns.EMAIL,
  UserColumns.FIRST_NAME,
  UserColumns.LAST_NAME,
  UserColumns.AVATAR,
  UserColumns.SYNC_STATUS,
  UserColumns.LOCAL_ID,
  UserColumns.CREATED_AT,
  UserColumns.UPDATED_AT,
  UserColumns.SYNC_ATTEMPTS,
  UserColumns.SYNC_ERROR
];

/**
 * RelationalStore-based User Local Data Source
 */
@injectable()
export class UserLocalDataSourceRdb implements IUserLocalDataSource {
  private context: common.UIAbilityContext;
  private dbManager: RdbStoreManager;
  private logger?: ILogger;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.dbManager = RdbStoreManager.getInstance();
  }

  /**
   * Sets the logger (for manual injection)
   */
  setLogger(logger: ILogger): void {
    this.logger = logger;
  }

  /**
   * Initializes the data source (creates database and tables)
   */
  async initialize(): Promise<void> {
    try {
      await this.dbManager.initialize(this.context);
      this.log('RDB data source initialized');
    } catch (error) {
      const message = `Failed to initialize RDB data source: ${error}`;
      this.logError(message);
      throw new Error(message);
    }
  }

  /**
   * Gets the RDB store instance
   */
  private getStore(): relationalStore.RdbStore {
    return this.dbManager.getStore();
  }

  // ===== Read Operations =====

  /**
   * Gets all users from the database
   */
  async getAllUsers(): Promise<LocalUser[]> {
    try {
      const store = this.getStore();
      const predicates = new relationalStore.RdbPredicates(Tables.USERS);

      const resultSet = await store.query(predicates, ALL_USER_COLUMNS);
      const users = this.mapResultSetToUsers(resultSet);

      this.log(`Retrieved ${users.length} users from database`);
      return users;
    } catch (error) {
      this.logError(`Failed to get all users: ${error}`);
      return [];
    }
  }

  /**
   * Gets a user by ID
   */
  async getUser(userId: number): Promise<LocalUser | undefined> {
    try {
      const store = this.getStore();
      const predicates = new relationalStore.RdbPredicates(Tables.USERS)
        .equalTo(UserColumns.ID, userId);

      const resultSet = await store.query(predicates, ALL_USER_COLUMNS);
      const users = this.mapResultSetToUsers(resultSet);

      const user = users.length > 0 ? users[0] : undefined;
      this.log(user ? `Found user: ${userId}` : `User not found: ${userId}`);
      return user;
    } catch (error) {
      this.logError(`Failed to get user by ID ${userId}: ${error}`);
      return undefined;
    }
  }

  /**
   * Gets users by sync status
   */
  async getUsersBySyncStatus(statuses: SyncStatus[]): Promise<LocalUser[]> {
    try {
      const store = this.getStore();
      const predicates = new relationalStore.RdbPredicates(Tables.USERS)
        .in(UserColumns.SYNC_STATUS, statuses);

      const resultSet = await store.query(predicates, ALL_USER_COLUMNS);
      const users = this.mapResultSetToUsers(resultSet);

      this.log(`Found ${users.length} users with statuses: ${statuses.join(', ')}`);
      return users;
    } catch (error) {
      this.logError(`Failed to get users by sync status: ${error}`);
      return [];
    }
  }

  /**
   * Searches users by email or name
   */
  async searchUsers(query: string): Promise<LocalUser[]> {
    try {
      const store = this.getStore();
      const searchPattern = `%${query}%`;

      // Use raw SQL for OR conditions (RdbPredicates doesn't support OR well)
      const sql = `
        SELECT * FROM ${Tables.USERS}
        WHERE ${UserColumns.EMAIL} LIKE ?
           OR ${UserColumns.FIRST_NAME} LIKE ?
           OR ${UserColumns.LAST_NAME} LIKE ?
        ORDER BY ${UserColumns.UPDATED_AT} DESC
      `;

      const resultSet = await store.querySql(sql, [searchPattern, searchPattern, searchPattern]);
      const users = this.mapResultSetToUsers(resultSet);

      this.log(`Search '${query}' found ${users.length} users`);
      return users;
    } catch (error) {
      this.logError(`Failed to search users: ${error}`);
      return [];
    }
  }

  /**
   * Gets users with pagination
   */
  async getUsersPaginated(page: number, pageSize: number): Promise<LocalUser[]> {
    try {
      const store = this.getStore();
      const offset = (page - 1) * pageSize;

      const predicates = new relationalStore.RdbPredicates(Tables.USERS)
        .orderByDesc(UserColumns.UPDATED_AT)
        .limitAs(pageSize)
        .offsetAs(offset);

      const resultSet = await store.query(predicates, ALL_USER_COLUMNS);
      const users = this.mapResultSetToUsers(resultSet);

      this.log(`Retrieved page ${page} with ${users.length} users`);
      return users;
    } catch (error) {
      this.logError(`Failed to get paginated users: ${error}`);
      return [];
    }
  }

  /**
   * Gets total user count
   */
  async getUserCount(): Promise<number> {
    try {
      const store = this.getStore();
      const sql = `SELECT COUNT(*) as count FROM ${Tables.USERS}`;
      const resultSet = await store.querySql(sql);

      let count = 0;
      if (resultSet.goToFirstRow()) {
        count = resultSet.getLong(resultSet.getColumnIndex('count'));
      }
      resultSet.close();

      return count;
    } catch (error) {
      this.logError(`Failed to get user count: ${error}`);
      return 0;
    }
  }

  // ===== Write Operations =====

  /**
   * Saves a user (insert or update)
   */
  async saveUser(user: LocalUser): Promise<void> {
    try {
      const store = this.getStore();
      const existingUser = await this.getUser(user.id);

      if (existingUser) {
        await this.updateUserInternal(store, user);
        this.log(`Updated user: ${user.id}`);
      } else {
        await this.insertUserInternal(store, user);
        this.log(`Inserted user: ${user.id}`);
      }
    } catch (error) {
      const message = `Failed to save user ${user.id}: ${error}`;
      this.logError(message);
      throw new Error(message);
    }
  }

  /**
   * Saves multiple users in a transaction
   */
  async saveUsers(users: LocalUser[]): Promise<void> {
    if (users.length === 0) return;

    try {
      await this.dbManager.withTransaction(async () => {
        const store = this.getStore();

        for (const user of users) {
          const existingUser = await this.getUser(user.id);
          if (existingUser) {
            await this.updateUserInternal(store, user);
          } else {
            await this.insertUserInternal(store, user);
          }
        }
      });

      this.log(`Saved ${users.length} users in transaction`);
    } catch (error) {
      const message = `Failed to save users: ${error}`;
      this.logError(message);
      throw new Error(message);
    }
  }

  /**
   * Deletes a user by ID
   */
  async deleteUser(userId: number): Promise<void> {
    try {
      const store = this.getStore();
      const predicates = new relationalStore.RdbPredicates(Tables.USERS)
        .equalTo(UserColumns.ID, userId);

      const affectedRows = await store.delete(predicates);
      this.log(`Deleted user ${userId}, affected rows: ${affectedRows}`);
    } catch (error) {
      const message = `Failed to delete user ${userId}: ${error}`;
      this.logError(message);
      throw new Error(message);
    }
  }

  /**
   * Clears all users from the database
   */
  async clearAll(): Promise<void> {
    try {
      const store = this.getStore();

      // Delete all users
      const userPredicates = new relationalStore.RdbPredicates(Tables.USERS);
      await store.delete(userPredicates);

      // Delete all sync metadata
      const metadataPredicates = new relationalStore.RdbPredicates(Tables.SYNC_METADATA);
      await store.delete(metadataPredicates);

      this.log('Cleared all local data');
    } catch (error) {
      const message = `Failed to clear data: ${error}`;
      this.logError(message);
      throw new Error(message);
    }
  }

  /**
   * Updates sync status for a user
   */
  async updateSyncStatus(userId: number, status: SyncStatus, error?: string): Promise<void> {
    try {
      const store = this.getStore();
      const predicates = new relationalStore.RdbPredicates(Tables.USERS)
        .equalTo(UserColumns.ID, userId);

      const values: ValuesBucket = {
        sync_status: status,
        updated_at: Date.now()
      };

      if (error !== undefined) {
        values['sync_error'] = error;
        // Increment sync attempts on error
        const user = await this.getUser(userId);
        if (user) {
          values['sync_attempts'] = user.syncAttempts + 1;
        }
      } else if (status === SyncStatus.SYNCED) {
        values['sync_error'] = null;
        values['sync_attempts'] = 0;
      }

      await store.update(values, predicates);
      this.log(`Updated sync status for user ${userId}: ${status}`);
    } catch (error) {
      const message = `Failed to update sync status: ${error}`;
      this.logError(message);
      throw new Error(message);
    }
  }

  // ===== Sync Metadata Operations =====

  /**
   * Gets the last sync timestamp
   */
  async getLastSyncTime(): Promise<number | undefined> {
    try {
      const store = this.getStore();
      const predicates = new relationalStore.RdbPredicates(Tables.SYNC_METADATA)
        .equalTo(SyncMetadataColumns.KEY, LAST_SYNC_KEY);

      const resultSet = await store.query(predicates, [SyncMetadataColumns.VALUE]);

      let timestamp: number | undefined;
      if (resultSet.goToFirstRow()) {
        const valueStr = resultSet.getString(resultSet.getColumnIndex(SyncMetadataColumns.VALUE));
        const parsed = parseInt(valueStr, 10);
        timestamp = isNaN(parsed) ? undefined : parsed;
      }
      resultSet.close();

      return timestamp;
    } catch (error) {
      this.logError(`Failed to get last sync time: ${error}`);
      return undefined;
    }
  }

  /**
   * Sets the last sync timestamp
   */
  async setLastSyncTime(timestamp: number): Promise<void> {
    try {
      const store = this.getStore();

      // Try to update first
      const predicates = new relationalStore.RdbPredicates(Tables.SYNC_METADATA)
        .equalTo(SyncMetadataColumns.KEY, LAST_SYNC_KEY);

      const values: ValuesBucket = {
        key: LAST_SYNC_KEY,
        value: timestamp.toString()
      };

      const affectedRows = await store.update(values, predicates);

      if (affectedRows === 0) {
        // Insert if not exists
        await store.insert(Tables.SYNC_METADATA, values);
      }

      this.log(`Set last sync time: ${new Date(timestamp).toISOString()}`);
    } catch (error) {
      this.logError(`Failed to set last sync time: ${error}`);
    }
  }

  // ===== Private Helper Methods =====

  /**
   * Inserts a user into the database
   */
  private async insertUserInternal(store: relationalStore.RdbStore, user: LocalUser): Promise<number> {
    const values = this.userToValuesBucket(user);
    const rowId = await store.insert(Tables.USERS, values);
    return rowId;
  }

  /**
   * Updates a user in the database
   */
  private async updateUserInternal(store: relationalStore.RdbStore, user: LocalUser): Promise<number> {
    const predicates = new relationalStore.RdbPredicates(Tables.USERS)
      .equalTo(UserColumns.ID, user.id);

    const values = this.userToValuesBucket(user);
    const affectedRows = await store.update(values, predicates);
    return affectedRows;
  }

  /**
   * Converts a LocalUser to ValuesBucket for insert/update
   */
  private userToValuesBucket(user: LocalUser): ValuesBucket {
    const values: ValuesBucket = {
      id: user.id,
      email: user.email,
      first_name: user.firstName,
      last_name: user.lastName,
      avatar: user.avatar,
      sync_status: user.syncStatus,
      local_id: user.localId,
      created_at: user.createdAt,
      updated_at: user.updatedAt,
      sync_attempts: user.syncAttempts,
      version: user.version
    };

    if (user.syncError !== undefined) {
      values['sync_error'] = user.syncError;
    }

    return values;
  }

  /**
   * Maps a ResultSet to an array of LocalUser objects
   * IMPORTANT: Always closes the ResultSet to prevent memory leaks
   */
  private mapResultSetToUsers(resultSet: relationalStore.ResultSet): LocalUser[] {
    const users: LocalUser[] = [];

    try {
      while (resultSet.goToNextRow()) {
        const user = this.mapRowToUser(resultSet);
        users.push(user);
      }
    } finally {
      resultSet.close(); // Always close to prevent memory leaks
    }

    return users;
  }

  /**
   * Maps a single ResultSet row to a LocalUser object
   */
  private mapRowToUser(resultSet: relationalStore.ResultSet): LocalUser {
    const id = resultSet.getLong(resultSet.getColumnIndex(UserColumns.ID));
    const email = resultSet.getString(resultSet.getColumnIndex(UserColumns.EMAIL));
    const firstName = resultSet.getString(resultSet.getColumnIndex(UserColumns.FIRST_NAME));
    const lastName = resultSet.getString(resultSet.getColumnIndex(UserColumns.LAST_NAME));
    const avatar = resultSet.getString(resultSet.getColumnIndex(UserColumns.AVATAR));
    const syncStatus = resultSet.getString(resultSet.getColumnIndex(UserColumns.SYNC_STATUS)) as SyncStatus;
    const localId = resultSet.getString(resultSet.getColumnIndex(UserColumns.LOCAL_ID));
    const createdAt = resultSet.getLong(resultSet.getColumnIndex(UserColumns.CREATED_AT));
    const updatedAt = resultSet.getLong(resultSet.getColumnIndex(UserColumns.UPDATED_AT));
    const syncAttempts = resultSet.getLong(resultSet.getColumnIndex(UserColumns.SYNC_ATTEMPTS));

    // Handle nullable sync_error
    let syncError: string | undefined;
    const syncErrorIndex = resultSet.getColumnIndex(UserColumns.SYNC_ERROR);
    if (!resultSet.isColumnNull(syncErrorIndex)) {
      syncError = resultSet.getString(syncErrorIndex);
    }

    // Handle version with default fallback for migration
    let version = 1;
    const versionIndex = resultSet.getColumnIndex(UserColumns.VERSION);
    if (versionIndex >= 0 && !resultSet.isColumnNull(versionIndex)) {
      version = resultSet.getLong(versionIndex);
    }

    return new LocalUserImpl(
      id,
      email,
      firstName,
      lastName,
      avatar,
      syncStatus,
      localId,
      createdAt,
      updatedAt,
      syncAttempts,
      syncError,
      version
    );
  }

  // ===== Logging =====

  private log(message: string): void {
    if (this.logger) {
      this.logger.d(TAG, message);
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
