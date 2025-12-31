/**
 * User Database using HarmonyOS Relational Database (RDB)
 * Replaces Preferences-based storage with proper SQL database
 */

import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { injectable, postConstruct, preDestroy } from '../../core/di/decorators';
import { ILogger } from '../../core/di/interfaces';
import { LocalUser, SyncStatus } from '../../domain/models/User';

const TAG = 'UserDatabase';

// Database configuration
const DB_NAME = 'arcana_users.db';
const DB_VERSION = 1;

// Table and column names
const TABLE_USERS = 'users';
const COL_ID = 'id';
const COL_LOCAL_ID = 'local_id';
const COL_EMAIL = 'email';
const COL_FIRST_NAME = 'first_name';
const COL_LAST_NAME = 'last_name';
const COL_AVATAR = 'avatar';
const COL_SYNC_STATUS = 'sync_status';
const COL_SYNC_ATTEMPTS = 'sync_attempts';
const COL_SYNC_ERROR = 'sync_error';
const COL_CREATED_AT = 'created_at';
const COL_UPDATED_AT = 'updated_at';

// Table for metadata
const TABLE_METADATA = 'metadata';
const COL_KEY = 'key';
const COL_VALUE = 'value';

/**
 * SQL statements
 */
const SQL_CREATE_USERS_TABLE = `
  CREATE TABLE IF NOT EXISTS ${TABLE_USERS} (
    ${COL_ID} INTEGER PRIMARY KEY,
    ${COL_LOCAL_ID} TEXT NOT NULL UNIQUE,
    ${COL_EMAIL} TEXT NOT NULL,
    ${COL_FIRST_NAME} TEXT NOT NULL,
    ${COL_LAST_NAME} TEXT NOT NULL,
    ${COL_AVATAR} TEXT,
    ${COL_SYNC_STATUS} TEXT NOT NULL DEFAULT 'synced',
    ${COL_SYNC_ATTEMPTS} INTEGER NOT NULL DEFAULT 0,
    ${COL_SYNC_ERROR} TEXT,
    ${COL_CREATED_AT} INTEGER NOT NULL,
    ${COL_UPDATED_AT} INTEGER NOT NULL
  )
`;

const SQL_CREATE_METADATA_TABLE = `
  CREATE TABLE IF NOT EXISTS ${TABLE_METADATA} (
    ${COL_KEY} TEXT PRIMARY KEY,
    ${COL_VALUE} TEXT
  )
`;

const SQL_CREATE_INDEX_SYNC_STATUS = `
  CREATE INDEX IF NOT EXISTS idx_sync_status ON ${TABLE_USERS}(${COL_SYNC_STATUS})
`;

const SQL_CREATE_INDEX_EMAIL = `
  CREATE INDEX IF NOT EXISTS idx_email ON ${TABLE_USERS}(${COL_EMAIL})
`;

/**
 * Database store configuration
 */
const STORE_CONFIG: relationalStore.StoreConfig = {
  name: DB_NAME,
  securityLevel: relationalStore.SecurityLevel.S1
};

/**
 * User Database interface
 */
export interface IUserDatabase {
  /** Initialize the database */
  initialize(): Promise<void>;

  /** Insert or update a user */
  upsertUser(user: LocalUser): Promise<void>;

  /** Insert or update multiple users */
  upsertUsers(users: LocalUser[]): Promise<void>;

  /** Get all users */
  getAllUsers(): Promise<LocalUser[]>;

  /** Get user by ID */
  getUserById(id: number): Promise<LocalUser | undefined>;

  /** Get users by sync status */
  getUsersBySyncStatus(statuses: SyncStatus[]): Promise<LocalUser[]>;

  /** Search users by query */
  searchUsers(query: string): Promise<LocalUser[]>;

  /** Get users with pagination */
  getUsersPaginated(page: number, pageSize: number): Promise<LocalUser[]>;

  /** Delete user by ID */
  deleteUser(id: number): Promise<void>;

  /** Get total user count */
  getUserCount(): Promise<number>;

  /** Clear all users */
  clearAllUsers(): Promise<void>;

  /** Get metadata value */
  getMetadata(key: string): Promise<string | undefined>;

  /** Set metadata value */
  setMetadata(key: string, value: string): Promise<void>;

  /** Close database connection */
  close(): Promise<void>;
}

/**
 * User Database implementation using RDB
 */
@injectable()
export class UserDatabase implements IUserDatabase {
  private context: common.UIAbilityContext;
  private rdbStore: relationalStore.RdbStore | null = null;
  private logger?: ILogger;
  private initialized = false;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  setLogger(logger: ILogger): void {
    this.logger = logger;
  }

  @postConstruct()
  async onPostConstruct(): Promise<void> {
    // Initialization will be called separately
  }

  async initialize(): Promise<void> {
    if (this.initialized) return;

    try {
      // Get RDB store
      this.rdbStore = await relationalStore.getRdbStore(this.context, STORE_CONFIG);

      // Create tables
      await this.rdbStore.executeSql(SQL_CREATE_USERS_TABLE);
      await this.rdbStore.executeSql(SQL_CREATE_METADATA_TABLE);
      await this.rdbStore.executeSql(SQL_CREATE_INDEX_SYNC_STATUS);
      await this.rdbStore.executeSql(SQL_CREATE_INDEX_EMAIL);

      this.initialized = true;
      this.log('Database initialized successfully');
    } catch (error) {
      this.logError(`Failed to initialize database: ${error}`);
      throw error;
    }
  }

  async upsertUser(user: LocalUser): Promise<void> {
    this.ensureInitialized();

    const valueBucket = this.userToValueBucket(user);

    try {
      // Try update first
      const predicates = new relationalStore.RdbPredicates(TABLE_USERS);
      predicates.equalTo(COL_ID, user.id);

      const rowsAffected = await this.rdbStore!.update(valueBucket, predicates);

      if (rowsAffected === 0) {
        // Insert if not exists
        await this.rdbStore!.insert(TABLE_USERS, valueBucket);
        this.log(`Inserted user: ${user.id}`);
      } else {
        this.log(`Updated user: ${user.id}`);
      }
    } catch (error) {
      this.logError(`Failed to upsert user: ${error}`);
      throw error;
    }
  }

  async upsertUsers(users: LocalUser[]): Promise<void> {
    this.ensureInitialized();

    try {
      await this.rdbStore!.beginTransaction();

      for (const user of users) {
        const valueBucket = this.userToValueBucket(user);
        const predicates = new relationalStore.RdbPredicates(TABLE_USERS);
        predicates.equalTo(COL_ID, user.id);

        const rowsAffected = await this.rdbStore!.update(valueBucket, predicates);
        if (rowsAffected === 0) {
          await this.rdbStore!.insert(TABLE_USERS, valueBucket);
        }
      }

      await this.rdbStore!.commit();
      this.log(`Upserted ${users.length} users`);
    } catch (error) {
      await this.rdbStore!.rollBack();
      this.logError(`Failed to upsert users: ${error}`);
      throw error;
    }
  }

  async getAllUsers(): Promise<LocalUser[]> {
    this.ensureInitialized();

    try {
      const predicates = new relationalStore.RdbPredicates(TABLE_USERS);
      predicates.orderByDesc(COL_UPDATED_AT);

      const resultSet = await this.rdbStore!.query(predicates);
      const users = this.resultSetToUsers(resultSet);
      resultSet.close();

      this.log(`Retrieved ${users.length} users`);
      return users;
    } catch (error) {
      this.logError(`Failed to get all users: ${error}`);
      return [];
    }
  }

  async getUserById(id: number): Promise<LocalUser | undefined> {
    this.ensureInitialized();

    try {
      const predicates = new relationalStore.RdbPredicates(TABLE_USERS);
      predicates.equalTo(COL_ID, id);

      const resultSet = await this.rdbStore!.query(predicates);
      const users = this.resultSetToUsers(resultSet);
      resultSet.close();

      return users.length > 0 ? users[0] : undefined;
    } catch (error) {
      this.logError(`Failed to get user by ID: ${error}`);
      return undefined;
    }
  }

  async getUsersBySyncStatus(statuses: SyncStatus[]): Promise<LocalUser[]> {
    this.ensureInitialized();

    try {
      const predicates = new relationalStore.RdbPredicates(TABLE_USERS);
      predicates.in(COL_SYNC_STATUS, statuses);

      const resultSet = await this.rdbStore!.query(predicates);
      const users = this.resultSetToUsers(resultSet);
      resultSet.close();

      this.log(`Found ${users.length} users with statuses: ${statuses.join(', ')}`);
      return users;
    } catch (error) {
      this.logError(`Failed to get users by sync status: ${error}`);
      return [];
    }
  }

  async searchUsers(query: string): Promise<LocalUser[]> {
    this.ensureInitialized();

    try {
      const searchPattern = `%${query}%`;
      const predicates = new relationalStore.RdbPredicates(TABLE_USERS);
      predicates.like(COL_EMAIL, searchPattern)
        .or()
        .like(COL_FIRST_NAME, searchPattern)
        .or()
        .like(COL_LAST_NAME, searchPattern);
      predicates.notEqualTo(COL_SYNC_STATUS, SyncStatus.PENDING_DELETE);

      const resultSet = await this.rdbStore!.query(predicates);
      const users = this.resultSetToUsers(resultSet);
      resultSet.close();

      this.log(`Search '${query}' found ${users.length} users`);
      return users;
    } catch (error) {
      this.logError(`Failed to search users: ${error}`);
      return [];
    }
  }

  async getUsersPaginated(page: number, pageSize: number): Promise<LocalUser[]> {
    this.ensureInitialized();

    try {
      const offset = (page - 1) * pageSize;
      const predicates = new relationalStore.RdbPredicates(TABLE_USERS);
      predicates.notEqualTo(COL_SYNC_STATUS, SyncStatus.PENDING_DELETE);
      predicates.orderByDesc(COL_UPDATED_AT);
      predicates.limitAs(pageSize);
      predicates.offsetAs(offset);

      const resultSet = await this.rdbStore!.query(predicates);
      const users = this.resultSetToUsers(resultSet);
      resultSet.close();

      this.log(`Page ${page}: Retrieved ${users.length} users`);
      return users;
    } catch (error) {
      this.logError(`Failed to get paginated users: ${error}`);
      return [];
    }
  }

  async deleteUser(id: number): Promise<void> {
    this.ensureInitialized();

    try {
      const predicates = new relationalStore.RdbPredicates(TABLE_USERS);
      predicates.equalTo(COL_ID, id);

      await this.rdbStore!.delete(predicates);
      this.log(`Deleted user: ${id}`);
    } catch (error) {
      this.logError(`Failed to delete user: ${error}`);
      throw error;
    }
  }

  async getUserCount(): Promise<number> {
    this.ensureInitialized();

    try {
      const predicates = new relationalStore.RdbPredicates(TABLE_USERS);
      predicates.notEqualTo(COL_SYNC_STATUS, SyncStatus.PENDING_DELETE);

      const resultSet = await this.rdbStore!.query(predicates);
      const count = resultSet.rowCount;
      resultSet.close();

      return count;
    } catch (error) {
      this.logError(`Failed to get user count: ${error}`);
      return 0;
    }
  }

  async clearAllUsers(): Promise<void> {
    this.ensureInitialized();

    try {
      const predicates = new relationalStore.RdbPredicates(TABLE_USERS);
      await this.rdbStore!.delete(predicates);
      this.log('Cleared all users');
    } catch (error) {
      this.logError(`Failed to clear users: ${error}`);
      throw error;
    }
  }

  async getMetadata(key: string): Promise<string | undefined> {
    this.ensureInitialized();

    try {
      const predicates = new relationalStore.RdbPredicates(TABLE_METADATA);
      predicates.equalTo(COL_KEY, key);

      const resultSet = await this.rdbStore!.query(predicates);

      if (resultSet.goToFirstRow()) {
        const valueIndex = resultSet.getColumnIndex(COL_VALUE);
        const value = resultSet.getString(valueIndex);
        resultSet.close();
        return value;
      }

      resultSet.close();
      return undefined;
    } catch (error) {
      this.logError(`Failed to get metadata: ${error}`);
      return undefined;
    }
  }

  async setMetadata(key: string, value: string): Promise<void> {
    this.ensureInitialized();

    try {
      const valueBucket: relationalStore.ValuesBucket = {
        [COL_KEY]: key,
        [COL_VALUE]: value
      };

      const predicates = new relationalStore.RdbPredicates(TABLE_METADATA);
      predicates.equalTo(COL_KEY, key);

      const rowsAffected = await this.rdbStore!.update(valueBucket, predicates);
      if (rowsAffected === 0) {
        await this.rdbStore!.insert(TABLE_METADATA, valueBucket);
      }

      this.log(`Set metadata: ${key}`);
    } catch (error) {
      this.logError(`Failed to set metadata: ${error}`);
      throw error;
    }
  }

  @preDestroy()
  async close(): Promise<void> {
    if (this.rdbStore) {
      this.rdbStore = null;
      this.initialized = false;
      this.log('Database closed');
    }
  }

  // ===== Private Methods =====

  private userToValueBucket(user: LocalUser): relationalStore.ValuesBucket {
    return {
      [COL_ID]: user.id,
      [COL_LOCAL_ID]: user.localId,
      [COL_EMAIL]: user.email,
      [COL_FIRST_NAME]: user.firstName,
      [COL_LAST_NAME]: user.lastName,
      [COL_AVATAR]: user.avatar || '',
      [COL_SYNC_STATUS]: user.syncStatus,
      [COL_SYNC_ATTEMPTS]: user.syncAttempts,
      [COL_SYNC_ERROR]: user.syncError || '',
      [COL_CREATED_AT]: user.createdAt,
      [COL_UPDATED_AT]: user.updatedAt
    };
  }

  private resultSetToUsers(resultSet: relationalStore.ResultSet): LocalUser[] {
    const users: LocalUser[] = [];

    while (resultSet.goToNextRow()) {
      users.push({
        id: resultSet.getLong(resultSet.getColumnIndex(COL_ID)),
        localId: resultSet.getString(resultSet.getColumnIndex(COL_LOCAL_ID)),
        email: resultSet.getString(resultSet.getColumnIndex(COL_EMAIL)),
        firstName: resultSet.getString(resultSet.getColumnIndex(COL_FIRST_NAME)),
        lastName: resultSet.getString(resultSet.getColumnIndex(COL_LAST_NAME)),
        avatar: resultSet.getString(resultSet.getColumnIndex(COL_AVATAR)) || undefined,
        syncStatus: resultSet.getString(resultSet.getColumnIndex(COL_SYNC_STATUS)) as SyncStatus,
        syncAttempts: resultSet.getLong(resultSet.getColumnIndex(COL_SYNC_ATTEMPTS)),
        syncError: resultSet.getString(resultSet.getColumnIndex(COL_SYNC_ERROR)) || undefined,
        createdAt: resultSet.getLong(resultSet.getColumnIndex(COL_CREATED_AT)),
        updatedAt: resultSet.getLong(resultSet.getColumnIndex(COL_UPDATED_AT))
      });
    }

    return users;
  }

  private ensureInitialized(): void {
    if (!this.initialized || !this.rdbStore) {
      throw new Error('Database not initialized. Call initialize() first.');
    }
  }

  private log(message: string): void {
    if (this.logger) {
      this.logger.d(TAG, message);
    }
  }

  private logError(message: string): void {
    if (this.logger) {
      this.logger.e(TAG, message);
    }
  }
}
