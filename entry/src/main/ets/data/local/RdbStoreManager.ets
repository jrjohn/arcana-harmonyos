/**
 * RdbStoreManager - Singleton manager for RelationalStore database
 *
 * Manages database lifecycle, schema creation, and migrations.
 * Built on HarmonyOS RelationalStore (SQLite-based) via @kit.ArkData.
 *
 * @see https://developer.harmonyos.com/en/docs/documentation/doc-references-V3/js-apis-data-relationalstore
 */

import { relationalStore, ValuesBucket } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

// Re-export for convenience
export { relationalStore, ValuesBucket };

const TAG = 'RdbStoreManager';

/**
 * Database configuration
 */
export class DB_CONFIG {
  static readonly NAME: string = 'arcana.db';
  static readonly VERSION: number = 1;
  static readonly SECURITY_LEVEL: relationalStore.SecurityLevel = relationalStore.SecurityLevel.S1;
}

/**
 * Table names
 */
export class Tables {
  static readonly USERS: string = 'users';
  static readonly SYNC_METADATA: string = 'sync_metadata';
}

/**
 * User table columns
 */
export class UserColumns {
  static readonly ID: string = 'id';
  static readonly EMAIL: string = 'email';
  static readonly FIRST_NAME: string = 'first_name';
  static readonly LAST_NAME: string = 'last_name';
  static readonly AVATAR: string = 'avatar';
  static readonly SYNC_STATUS: string = 'sync_status';
  static readonly LOCAL_ID: string = 'local_id';
  static readonly CREATED_AT: string = 'created_at';
  static readonly UPDATED_AT: string = 'updated_at';
  static readonly SYNC_ATTEMPTS: string = 'sync_attempts';
  static readonly SYNC_ERROR: string = 'sync_error';
  static readonly VERSION: string = 'version';
}

/**
 * Sync metadata columns
 */
export class SyncMetadataColumns {
  static readonly KEY: string = 'key';
  static readonly VALUE: string = 'value';
}

/**
 * SQL statements for table creation
 */
const CREATE_USERS_TABLE = `
  CREATE TABLE IF NOT EXISTS ${Tables.USERS} (
    ${UserColumns.ID} INTEGER PRIMARY KEY,
    ${UserColumns.EMAIL} TEXT NOT NULL,
    ${UserColumns.FIRST_NAME} TEXT NOT NULL,
    ${UserColumns.LAST_NAME} TEXT NOT NULL,
    ${UserColumns.AVATAR} TEXT DEFAULT '',
    ${UserColumns.SYNC_STATUS} TEXT DEFAULT 'synced',
    ${UserColumns.LOCAL_ID} TEXT NOT NULL UNIQUE,
    ${UserColumns.CREATED_AT} INTEGER NOT NULL,
    ${UserColumns.UPDATED_AT} INTEGER NOT NULL,
    ${UserColumns.SYNC_ATTEMPTS} INTEGER DEFAULT 0,
    ${UserColumns.SYNC_ERROR} TEXT,
    ${UserColumns.VERSION} INTEGER DEFAULT 1
  )
`;

const CREATE_SYNC_METADATA_TABLE = `
  CREATE TABLE IF NOT EXISTS ${Tables.SYNC_METADATA} (
    ${SyncMetadataColumns.KEY} TEXT PRIMARY KEY,
    ${SyncMetadataColumns.VALUE} TEXT
  )
`;

/**
 * Index creation for performance
 */
const CREATE_INDEXES = [
  `CREATE INDEX IF NOT EXISTS idx_users_sync_status ON ${Tables.USERS} (${UserColumns.SYNC_STATUS})`,
  `CREATE INDEX IF NOT EXISTS idx_users_email ON ${Tables.USERS} (${UserColumns.EMAIL})`,
  `CREATE INDEX IF NOT EXISTS idx_users_updated_at ON ${Tables.USERS} (${UserColumns.UPDATED_AT})`
];

/**
 * RdbStoreManager - Manages database lifecycle
 */
export class RdbStoreManager {
  private static instance: RdbStoreManager | null = null;
  private store: relationalStore.RdbStore | null = null;
  private context: common.UIAbilityContext | null = null;
  private isInitialized: boolean = false;

  private constructor() {}

  /**
   * Gets the singleton instance
   */
  static getInstance(): RdbStoreManager {
    if (!RdbStoreManager.instance) {
      RdbStoreManager.instance = new RdbStoreManager();
    }
    return RdbStoreManager.instance;
  }

  /**
   * Initializes the database
   * Must be called before any database operations
   */
  async initialize(context: common.UIAbilityContext): Promise<void> {
    if (this.isInitialized && this.store) {
      console.info(`${TAG}: Already initialized`);
      return;
    }

    this.context = context;

    try {
      console.info(`${TAG}: Initializing database...`);

      const storeConfig: relationalStore.StoreConfig = {
        name: DB_CONFIG.NAME,
        securityLevel: DB_CONFIG.SECURITY_LEVEL
      };

      this.store = await relationalStore.getRdbStore(context, storeConfig);

      // Check version and run migrations
      await this.runMigrations();

      this.isInitialized = true;
      console.info(`${TAG}: Database initialized successfully`);
    } catch (error) {
      const e = error as BusinessError;
      const message = `Failed to initialize database: ${e.message}`;
      console.error(`${TAG}: ${message}`);
      throw new Error(message);
    }
  }

  /**
   * Gets the RdbStore instance
   * Throws if not initialized
   */
  getStore(): relationalStore.RdbStore {
    if (!this.store) {
      throw new Error('RdbStoreManager not initialized. Call initialize() first.');
    }
    return this.store;
  }

  /**
   * Checks if the manager is initialized
   */
  isReady(): boolean {
    return this.isInitialized && this.store !== null;
  }

  /**
   * Runs database migrations
   */
  private async runMigrations(): Promise<void> {
    if (!this.store) return;

    const currentVersion = this.store.version;
    console.info(`${TAG}: Current database version: ${currentVersion}`);

    if (currentVersion === 0) {
      // Fresh install - create all tables
      await this.createTables();
      this.store.version = DB_CONFIG.VERSION;
      console.info(`${TAG}: Database created with version ${DB_CONFIG.VERSION}`);
    } else if (currentVersion < DB_CONFIG.VERSION) {
      // Run migrations
      await this.migrateDatabase(currentVersion, DB_CONFIG.VERSION);
      this.store.version = DB_CONFIG.VERSION;
      console.info(`${TAG}: Database migrated to version ${DB_CONFIG.VERSION}`);
    }
  }

  /**
   * Creates initial database tables
   */
  private async createTables(): Promise<void> {
    if (!this.store) return;

    console.info(`${TAG}: Creating tables...`);

    // Create users table
    await this.store.executeSql(CREATE_USERS_TABLE);
    console.info(`${TAG}: Created ${Tables.USERS} table`);

    // Create sync metadata table
    await this.store.executeSql(CREATE_SYNC_METADATA_TABLE);
    console.info(`${TAG}: Created ${Tables.SYNC_METADATA} table`);

    // Create indexes
    for (const indexSql of CREATE_INDEXES) {
      await this.store.executeSql(indexSql);
    }
    console.info(`${TAG}: Created indexes`);
  }

  /**
   * Migrates database from one version to another
   */
  private async migrateDatabase(fromVersion: number, toVersion: number): Promise<void> {
    console.info(`${TAG}: Migrating from version ${fromVersion} to ${toVersion}`);

    // Add migration logic here as schema evolves
    // Example:
    // if (fromVersion < 2) {
    //   await this.store.executeSql('ALTER TABLE users ADD COLUMN phone TEXT');
    // }
  }

  /**
   * Closes the database connection
   */
  async close(): Promise<void> {
    if (this.store && this.context) {
      try {
        // Note: HarmonyOS RDB doesn't have an explicit close method
        // The store is managed by the system
        this.store = null;
        this.isInitialized = false;
        console.info(`${TAG}: Database closed`);
      } catch (error) {
        console.error(`${TAG}: Error closing database: ${error}`);
      }
    }
  }

  /**
   * Deletes the database (use with caution!)
   */
  async deleteDatabase(): Promise<void> {
    if (!this.context) {
      throw new Error('Context not available');
    }

    try {
      await relationalStore.deleteRdbStore(this.context, DB_CONFIG.NAME);
      this.store = null;
      this.isInitialized = false;
      console.info(`${TAG}: Database deleted`);
    } catch (error) {
      const message = `Error deleting database: ${error}`;
      console.error(`${TAG}: ${message}`);
      throw new Error(message);
    }
  }

  /**
   * Executes a raw SQL query
   */
  async executeSql(sql: string, bindArgs?: Array<relationalStore.ValueType>): Promise<void> {
    const store = this.getStore();
    await store.executeSql(sql, bindArgs);
  }

  /**
   * Begins a transaction
   */
  async beginTransaction(): Promise<void> {
    const store = this.getStore();
    await store.beginTransaction();
  }

  /**
   * Commits the current transaction
   */
  async commit(): Promise<void> {
    const store = this.getStore();
    await store.commit();
  }

  /**
   * Rolls back the current transaction
   */
  async rollback(): Promise<void> {
    const store = this.getStore();
    await store.rollBack();
  }

  /**
   * Executes operations within a transaction
   */
  async withTransaction<T>(operation: () => Promise<T>): Promise<T> {
    await this.beginTransaction();
    try {
      const result = await operation();
      await this.commit();
      return result;
    } catch (error) {
      await this.rollback();
      if (error instanceof Error) {
        throw error;
      }
      throw new Error(String(error));
    }
  }
}
