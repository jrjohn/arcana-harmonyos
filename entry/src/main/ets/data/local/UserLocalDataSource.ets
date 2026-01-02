import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { LocalUser, SyncStatus, LocalUserImpl } from '../../domain/models/User';
import { Result, ResultFactory } from '../../domain/models/Result';
import { AppError, AppErrorFactory } from '../../domain/models/AppError';
import { Logger } from '../../core/logging/Logger';

const TAG = 'UserLocalDataSource';
const PREFERENCES_NAME = 'arcana_users';
const USERS_KEY = 'users_data';
const LAST_SYNC_KEY = 'last_sync_time';

/**
 * Local data source for user persistence.
 * Uses HarmonyOS Preferences for lightweight storage.
 */
export class UserLocalDataSource {
  private context: common.UIAbilityContext;
  private preferencesInstance: preferences.Preferences | null = null;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  /**
   * Initializes the preferences store
   */
  async initialize(): Promise<void> {
    try {
      this.preferencesInstance = await preferences.getPreferences(this.context, PREFERENCES_NAME);
      Logger.d(TAG, 'Preferences initialized successfully');
    } catch (error) {
      Logger.e(TAG, `Failed to initialize preferences: ${error}`);
      if (error instanceof Error) {
        throw error;
      }
      throw new Error(String(error));
    }
  }

  /**
   * Gets the preferences instance, initializing if needed
   */
  private async getPreferences(): Promise<preferences.Preferences> {
    if (!this.preferencesInstance) {
      await this.initialize();
    }
    return this.preferencesInstance!;
  }

  /**
   * Saves a list of users to local storage
   */
  async saveUsers(users: LocalUser[]): Promise<Result<void, AppError>> {
    try {
      const prefs = await this.getPreferences();
      const existingUsers = await this.getAllUsersInternal();

      // Merge with existing users (update existing, add new)
      const userMap = new Map<number, LocalUser>();
      existingUsers.forEach(u => userMap.set(u.id, u));
      users.forEach(u => userMap.set(u.id, u));

      const mergedUsers = Array.from(userMap.values());
      await prefs.put(USERS_KEY, JSON.stringify(mergedUsers));
      await prefs.flush();

      Logger.d(TAG, `Saved ${users.length} users, total: ${mergedUsers.length}`);
      return ResultFactory.success(undefined);
    } catch (error) {
      Logger.e(TAG, `Failed to save users: ${error}`);
      return ResultFactory.failure(AppErrorFactory.databaseError('save users', error as Error));
    }
  }

  /**
   * Saves a single user to local storage
   */
  async saveUser(user: LocalUser): Promise<Result<LocalUser, AppError>> {
    try {
      const prefs = await this.getPreferences();
      const users = await this.getAllUsersInternal();

      const index = users.findIndex(u => u.id === user.id || u.localId === user.localId);
      if (index >= 0) {
        users[index] = user;
      } else {
        users.push(user);
      }

      await prefs.put(USERS_KEY, JSON.stringify(users));
      await prefs.flush();

      Logger.d(TAG, `Saved user: ${user.id}`);
      return ResultFactory.success(user);
    } catch (error) {
      Logger.e(TAG, `Failed to save user: ${error}`);
      return ResultFactory.failure(AppErrorFactory.databaseError('save user', error as Error));
    }
  }

  /**
   * Gets all users from local storage
   */
  async getAllUsers(): Promise<Result<LocalUser[], AppError>> {
    try {
      const users = await this.getAllUsersInternal();
      Logger.d(TAG, `Retrieved ${users.length} users`);
      return ResultFactory.success(users);
    } catch (error) {
      Logger.e(TAG, `Failed to get all users: ${error}`);
      return ResultFactory.failure(AppErrorFactory.databaseError('get users', error as Error));
    }
  }

  /**
   * Gets users for a specific page
   */
  async getUsersForPage(page: number, perPage: number): Promise<Result<LocalUser[], AppError>> {
    try {
      const users = await this.getAllUsersInternal();
      const startIndex = (page - 1) * perPage;
      const endIndex = startIndex + perPage;
      const pageUsers = users
        .filter(u => u.syncStatus !== SyncStatus.PENDING_DELETE)
        .slice(startIndex, endIndex);

      Logger.d(TAG, `Retrieved ${pageUsers.length} users for page ${page}`);
      return ResultFactory.success(pageUsers);
    } catch (error) {
      Logger.e(TAG, `Failed to get users for page: ${error}`);
      return ResultFactory.failure(AppErrorFactory.databaseError('get page users', error as Error));
    }
  }

  /**
   * Gets a single user by ID
   */
  async getUserById(userId: number): Promise<Result<LocalUser | undefined, AppError>> {
    try {
      const users = await this.getAllUsersInternal();
      const user = users.find(u => u.id === userId);
      Logger.d(TAG, user ? `Found user: ${userId}` : `User not found: ${userId}`);
      return ResultFactory.success(user);
    } catch (error) {
      Logger.e(TAG, `Failed to get user by ID: ${error}`);
      return ResultFactory.failure(AppErrorFactory.databaseError('get user', error as Error));
    }
  }

  /**
   * Deletes a user from local storage
   */
  async deleteUser(userId: number): Promise<Result<void, AppError>> {
    try {
      const prefs = await this.getPreferences();
      const users = await this.getAllUsersInternal();
      const filteredUsers = users.filter(u => u.id !== userId);

      await prefs.put(USERS_KEY, JSON.stringify(filteredUsers));
      await prefs.flush();

      Logger.d(TAG, `Deleted user: ${userId}`);
      return ResultFactory.success(undefined);
    } catch (error) {
      Logger.e(TAG, `Failed to delete user: ${error}`);
      return ResultFactory.failure(AppErrorFactory.databaseError('delete user', error as Error));
    }
  }

  /**
   * Gets users pending synchronization
   */
  async getPendingSyncUsers(): Promise<Result<LocalUser[], AppError>> {
    try {
      const users = await this.getAllUsersInternal();
      const pendingUsers = users.filter(u => LocalUserImpl.needsSync(u));
      Logger.d(TAG, `Found ${pendingUsers.length} users pending sync`);
      return ResultFactory.success(pendingUsers);
    } catch (error) {
      Logger.e(TAG, `Failed to get pending sync users: ${error}`);
      return ResultFactory.failure(AppErrorFactory.databaseError('get pending users', error as Error));
    }
  }

  /**
   * Updates sync status for a user
   */
  async updateSyncStatus(userId: number, status: SyncStatus, errorMessage?: string): Promise<Result<void, AppError>> {
    try {
      const prefs = await this.getPreferences();
      const users = await this.getAllUsersInternal();
      const index = users.findIndex(u => u.id === userId);

      if (index >= 0) {
        const user = users[index];
        if (status === SyncStatus.SYNC_FAILED && errorMessage) {
          users[index] = LocalUserImpl.markSyncFailed(user, errorMessage);
        } else if (status === SyncStatus.SYNCED) {
          users[index] = LocalUserImpl.markAsSynced(user);
        } else {
          users[index] = new LocalUserImpl(
            user.id,
            user.email,
            user.firstName,
            user.lastName,
            user.avatar,
            status,
            user.localId,
            user.createdAt,
            Date.now(),
            user.syncAttempts,
            user.syncError,
            user.version
          );
        }

        await prefs.put(USERS_KEY, JSON.stringify(users));
        await prefs.flush();
        Logger.d(TAG, `Updated sync status for user ${userId} to ${status}`);
      }

      return ResultFactory.success(undefined);
    } catch (error) {
      Logger.e(TAG, `Failed to update sync status: ${error}`);
      return ResultFactory.failure(AppErrorFactory.databaseError('update sync status', error as Error));
    }
  }

  /**
   * Gets the last sync timestamp
   */
  async getLastSyncTime(): Promise<number | undefined> {
    try {
      const prefs = await this.getPreferences();
      const timestamp = await prefs.get(LAST_SYNC_KEY, 0) as number;
      return timestamp > 0 ? timestamp : undefined;
    } catch (error) {
      Logger.e(TAG, `Failed to get last sync time: ${error}`);
      return undefined;
    }
  }

  /**
   * Sets the last sync timestamp
   */
  async setLastSyncTime(timestamp: number): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      await prefs.put(LAST_SYNC_KEY, timestamp);
      await prefs.flush();
      Logger.d(TAG, `Set last sync time: ${new Date(timestamp).toISOString()}`);
    } catch (error) {
      Logger.e(TAG, `Failed to set last sync time: ${error}`);
    }
  }

  /**
   * Clears all user data
   */
  async clearAllData(): Promise<Result<void, AppError>> {
    try {
      const prefs = await this.getPreferences();
      await prefs.clear();
      await prefs.flush();
      Logger.d(TAG, 'Cleared all local data');
      return ResultFactory.success(undefined);
    } catch (error) {
      Logger.e(TAG, `Failed to clear data: ${error}`);
      return ResultFactory.failure(AppErrorFactory.databaseError('clear data', error as Error));
    }
  }

  /**
   * Gets total user count
   */
  async getUserCount(): Promise<Result<number, AppError>> {
    try {
      const users = await this.getAllUsersInternal();
      const count = users.filter(u => u.syncStatus !== SyncStatus.PENDING_DELETE).length;
      return ResultFactory.success(count);
    } catch (error) {
      Logger.e(TAG, `Failed to get user count: ${error}`);
      return ResultFactory.failure(AppErrorFactory.databaseError('get count', error as Error));
    }
  }

  /**
   * Internal method to get all users
   */
  private async getAllUsersInternal(): Promise<LocalUser[]> {
    try {
      const prefs = await this.getPreferences();
      const usersJson = await prefs.get(USERS_KEY, '[]') as string;
      return JSON.parse(usersJson) as LocalUser[];
    } catch (err) {
      console.error(`getAllUsersInternal error: ${err}`);
      return [];
    }
  }
}
