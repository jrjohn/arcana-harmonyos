/**
 * Injectable User Local Data Source
 * Implements IUserLocalDataSource interface for DI container
 */

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { injectable, preDestroy } from '../../core/di/decorators';
import { IUserLocalDataSource, ILogger } from '../../core/di/interfaces';
import { LocalUser, SyncStatus } from '../../domain/models/User';

const TAG = 'UserLocalDataSourceImpl';
const PREFERENCES_NAME = 'arcana_users';
const USERS_KEY = 'users_data';
const LAST_SYNC_KEY = 'last_sync_time';

/**
 * Injectable user local data source implementation
 */
@injectable()
export class UserLocalDataSourceImpl implements IUserLocalDataSource {
  private context: common.UIAbilityContext;
  private preferencesInstance: preferences.Preferences | null = null;
  private logger?: ILogger;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  /**
   * Sets the logger (for manual injection)
   */
  setLogger(logger: ILogger): void {
    this.logger = logger;
  }

  async initialize(): Promise<void> {
    try {
      this.preferencesInstance = await preferences.getPreferences(this.context, PREFERENCES_NAME);
      this.log('Preferences initialized successfully');
    } catch (error) {
      this.logError(`Failed to initialize preferences: ${error}`);
      throw new Error(`Failed to initialize preferences: ${error}`);
    }
  }

  private async getPreferences(): Promise<preferences.Preferences> {
    if (!this.preferencesInstance) {
      await this.initialize();
    }
    return this.preferencesInstance!;
  }

  async getAllUsers(): Promise<LocalUser[]> {
    try {
      const users = await this.getAllUsersInternal();
      this.log(`Retrieved ${users.length} users`);
      return users;
    } catch (error) {
      this.logError(`Failed to get all users: ${error}`);
      return [];
    }
  }

  async getUser(userId: number): Promise<LocalUser | undefined> {
    try {
      const users = await this.getAllUsersInternal();
      const user = users.find(u => u.id === userId);
      this.log(user ? `Found user: ${userId}` : `User not found: ${userId}`);
      return user;
    } catch (error) {
      this.logError(`Failed to get user by ID: ${error}`);
      return undefined;
    }
  }

  async saveUser(user: LocalUser): Promise<void> {
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

      this.log(`Saved user: ${user.id}`);
    } catch (error) {
      this.logError(`Failed to save user: ${error}`);
      throw new Error(`Failed to save user: ${error}`);
    }
  }

  async saveUsers(users: LocalUser[]): Promise<void> {
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

      this.log(`Saved ${users.length} users, total: ${mergedUsers.length}`);
    } catch (error) {
      this.logError(`Failed to save users: ${error}`);
      throw new Error(`Failed to save users: ${error}`);
    }
  }

  async deleteUser(userId: number): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      const users = await this.getAllUsersInternal();
      const filteredUsers = users.filter(u => u.id !== userId);

      await prefs.put(USERS_KEY, JSON.stringify(filteredUsers));
      await prefs.flush();

      this.log(`Deleted user: ${userId}`);
    } catch (error) {
      this.logError(`Failed to delete user: ${error}`);
      throw new Error(`Failed to delete user: ${error}`);
    }
  }

  async clearAll(): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      await prefs.clear();
      await prefs.flush();
      this.log('Cleared all local data');
    } catch (error) {
      this.logError(`Failed to clear data: ${error}`);
      throw new Error(`Failed to clear data: ${error}`);
    }
  }

  async getUsersBySyncStatus(statuses: SyncStatus[]): Promise<LocalUser[]> {
    try {
      const users = await this.getAllUsersInternal();
      const filteredUsers = users.filter(u => statuses.includes(u.syncStatus));
      this.log(`Found ${filteredUsers.length} users with statuses: ${statuses.join(', ')}`);
      return filteredUsers;
    } catch (error) {
      this.logError(`Failed to get users by sync status: ${error}`);
      return [];
    }
  }

  async getLastSyncTime(): Promise<number | undefined> {
    try {
      const prefs = await this.getPreferences();
      const timestamp = await prefs.get(LAST_SYNC_KEY, 0) as number;
      return timestamp > 0 ? timestamp : undefined;
    } catch (error) {
      this.logError(`Failed to get last sync time: ${error}`);
      return undefined;
    }
  }

  async setLastSyncTime(timestamp: number): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      await prefs.put(LAST_SYNC_KEY, timestamp);
      await prefs.flush();
      this.log(`Set last sync time: ${new Date(timestamp).toISOString()}`);
    } catch (error) {
      this.logError(`Failed to set last sync time: ${error}`);
    }
  }

  private async getAllUsersInternal(): Promise<LocalUser[]> {
    const prefs = await this.getPreferences();
    const usersJson = await prefs.get(USERS_KEY, '[]') as string;
    return JSON.parse(usersJson) as LocalUser[];
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
