/**
 * Domain model representing a User entity.
 * This is a pure domain model with no framework dependencies.
 */
export interface User {
  /** Unique identifier for the user */
  readonly id: number;
  /** User's email address */
  readonly email: string;
  /** User's first name */
  readonly firstName: string;
  /** User's lastName */
  readonly lastName: string;
  /** URL to user's avatar image */
  readonly avatar: string;
}

/**
 * User update fields (without id)
 */
export interface UserUpdateFields {
  email?: string;
  firstName?: string;
  lastName?: string;
  avatar?: string;
}

/**
 * User class implementation for ArkTS compatibility
 */
export class UserImpl implements User {
  readonly id: number;
  readonly email: string;
  readonly firstName: string;
  readonly lastName: string;
  readonly avatar: string;

  constructor(id: number, email: string, firstName: string, lastName: string, avatar: string) {
    this.id = id;
    this.email = email;
    this.firstName = firstName;
    this.lastName = lastName;
    this.avatar = avatar;
  }

  static create(id: number, email: string, firstName: string, lastName: string, avatar: string): User {
    return new UserImpl(id, email, firstName, lastName, avatar);
  }

  static copyWith(user: User, updates: UserUpdateFields): User {
    return new UserImpl(
      user.id,
      updates.email !== undefined ? updates.email : user.email,
      updates.firstName !== undefined ? updates.firstName : user.firstName,
      updates.lastName !== undefined ? updates.lastName : user.lastName,
      updates.avatar !== undefined ? updates.avatar : user.avatar
    );
  }

  static getFullName(user: User): string {
    return `${user.firstName} ${user.lastName}`;
  }

  static getInitials(user: User): string {
    const firstInitial = user.firstName.charAt(0).toUpperCase();
    const lastInitial = user.lastName.charAt(0).toUpperCase();
    return `${firstInitial}${lastInitial}`;
  }
}

/**
 * Request model for creating a new user
 */
export interface CreateUserRequest {
  readonly email: string;
  readonly firstName: string;
  readonly lastName: string;
  readonly avatar: string;
}

/**
 * Request model for updating an existing user
 */
export interface UpdateUserRequest {
  readonly id: number;
  readonly email: string;
  readonly firstName: string;
  readonly lastName: string;
  readonly avatar: string;
}

/**
 * Paginated response containing users
 */
export interface PaginatedUsers {
  readonly users: User[];
  readonly page: number;
  readonly perPage: number;
  readonly total: number;
  readonly totalPages: number;
}

/**
 * PaginatedUsers class implementation for ArkTS compatibility
 */
export class PaginatedUsersImpl implements PaginatedUsers {
  readonly users: User[];
  readonly page: number;
  readonly perPage: number;
  readonly total: number;
  readonly totalPages: number;

  constructor(users: User[], page: number, perPage: number, total: number, totalPages: number) {
    this.users = users;
    this.page = page;
    this.perPage = perPage;
    this.total = total;
    this.totalPages = totalPages;
  }
}

/**
 * Sync status for offline-first operations
 */
export enum SyncStatus {
  SYNCED = 'synced',
  PENDING_CREATE = 'pending_create',
  PENDING_UPDATE = 'pending_update',
  PENDING_DELETE = 'pending_delete',
  SYNC_FAILED = 'sync_failed'
}

/**
 * Local user entity with sync metadata
 */
export interface LocalUser extends User {
  readonly syncStatus: SyncStatus;
  readonly localId: string;
  readonly createdAt: number;
  readonly updatedAt: number;
  readonly syncAttempts: number;
  readonly syncError?: string;
  /** Version for conflict resolution tie-breaking */
  readonly version: number;
}

/**
 * LocalUser class implementation for ArkTS compatibility
 */
export class LocalUserImpl implements LocalUser {
  readonly id: number;
  readonly email: string;
  readonly firstName: string;
  readonly lastName: string;
  readonly avatar: string;
  readonly syncStatus: SyncStatus;
  readonly localId: string;
  readonly createdAt: number;
  readonly updatedAt: number;
  readonly syncAttempts: number;
  readonly syncError?: string;
  readonly version: number;

  constructor(
    id: number,
    email: string,
    firstName: string,
    lastName: string,
    avatar: string,
    syncStatus: SyncStatus,
    localId: string,
    createdAt: number,
    updatedAt: number,
    syncAttempts: number,
    syncError: string | undefined,
    version: number
  ) {
    this.id = id;
    this.email = email;
    this.firstName = firstName;
    this.lastName = lastName;
    this.avatar = avatar;
    this.syncStatus = syncStatus;
    this.localId = localId;
    this.createdAt = createdAt;
    this.updatedAt = updatedAt;
    this.syncAttempts = syncAttempts;
    this.syncError = syncError;
    this.version = version;
  }

  static fromUser(user: User, syncStatus: SyncStatus = SyncStatus.SYNCED): LocalUser {
    const now = Date.now();
    return new LocalUserImpl(
      user.id,
      user.email,
      user.firstName,
      user.lastName,
      user.avatar,
      syncStatus,
      `local_${user.id}_${now}`,
      now,
      now,
      0,
      undefined,
      1  // Initial version
    );
  }

  static createPending(
    email: string,
    firstName: string,
    lastName: string,
    avatar: string
  ): LocalUser {
    const now = Date.now();
    const tempId = -Math.floor(Math.random() * 1000000);
    return new LocalUserImpl(
      tempId,
      email,
      firstName,
      lastName,
      avatar,
      SyncStatus.PENDING_CREATE,
      `local_pending_${now}`,
      now,
      now,
      0,
      undefined,
      1  // Initial version
    );
  }

  static markForUpdate(user: LocalUser): LocalUser {
    return new LocalUserImpl(
      user.id,
      user.email,
      user.firstName,
      user.lastName,
      user.avatar,
      SyncStatus.PENDING_UPDATE,
      user.localId,
      user.createdAt,
      Date.now(),
      user.syncAttempts,
      user.syncError,
      user.version + 1  // Increment version on update
    );
  }

  static markForDeletion(user: LocalUser): LocalUser {
    return new LocalUserImpl(
      user.id,
      user.email,
      user.firstName,
      user.lastName,
      user.avatar,
      SyncStatus.PENDING_DELETE,
      user.localId,
      user.createdAt,
      Date.now(),
      user.syncAttempts,
      user.syncError,
      user.version  // Preserve version on delete
    );
  }

  static markAsSynced(user: LocalUser, serverId?: number): LocalUser {
    return new LocalUserImpl(
      serverId !== undefined ? serverId : user.id,
      user.email,
      user.firstName,
      user.lastName,
      user.avatar,
      SyncStatus.SYNCED,
      user.localId,
      user.createdAt,
      Date.now(),
      0,
      undefined,
      user.version  // Preserve version on sync
    );
  }

  static markSyncFailed(user: LocalUser, error: string): LocalUser {
    return new LocalUserImpl(
      user.id,
      user.email,
      user.firstName,
      user.lastName,
      user.avatar,
      SyncStatus.SYNC_FAILED,
      user.localId,
      user.createdAt,
      Date.now(),
      user.syncAttempts + 1,
      error,
      user.version  // Preserve version on failure
    );
  }

  static needsSync(user: LocalUser): boolean {
    return user.syncStatus !== SyncStatus.SYNCED;
  }

  static copyWithUpdates(
    user: LocalUser,
    email: string,
    firstName: string,
    lastName: string,
    avatar: string
  ): LocalUser {
    return new LocalUserImpl(
      user.id,
      email,
      firstName,
      lastName,
      avatar,
      user.syncStatus,
      user.localId,
      user.createdAt,
      Date.now(),
      user.syncAttempts,
      user.syncError,
      user.version + 1  // Increment version on content update
    );
  }

  /**
   * Increments the version number for conflict resolution
   */
  static incrementVersion(user: LocalUser): LocalUser {
    return new LocalUserImpl(
      user.id,
      user.email,
      user.firstName,
      user.lastName,
      user.avatar,
      user.syncStatus,
      user.localId,
      user.createdAt,
      Date.now(),
      user.syncAttempts,
      user.syncError,
      user.version + 1
    );
  }

  /**
   * Creates a LocalUser from remote data, preserving local metadata
   */
  static fromRemote(remote: User, existingLocal: LocalUser): LocalUser {
    return new LocalUserImpl(
      remote.id,
      remote.email,
      remote.firstName,
      remote.lastName,
      remote.avatar,
      SyncStatus.SYNCED,
      existingLocal.localId,
      existingLocal.createdAt,
      Date.now(),
      0,
      undefined,
      existingLocal.version  // Preserve local version when accepting remote
    );
  }
}

/**
 * Factory utility for User operations (alias for UserImpl static methods)
 */
export class UserFactory {
  static create(id: number, email: string, firstName: string, lastName: string, avatar: string): User {
    return UserImpl.create(id, email, firstName, lastName, avatar);
  }

  static copyWith(user: User, updates: UserUpdateFields): User {
    return UserImpl.copyWith(user, updates);
  }

  static getFullName(user: User): string {
    return UserImpl.getFullName(user);
  }

  static getInitials(user: User): string {
    return UserImpl.getInitials(user);
  }
}

/**
 * Factory utility for LocalUser operations (alias for LocalUserImpl static methods)
 */
export class LocalUserFactory {
  static fromUser(user: User, syncStatus: SyncStatus = SyncStatus.SYNCED): LocalUser {
    return LocalUserImpl.fromUser(user, syncStatus);
  }

  static createPending(email: string, firstName: string, lastName: string, avatar: string): LocalUser {
    return LocalUserImpl.createPending(email, firstName, lastName, avatar);
  }

  static markForUpdate(user: LocalUser): LocalUser {
    return LocalUserImpl.markForUpdate(user);
  }

  static markForDeletion(user: LocalUser): LocalUser {
    return LocalUserImpl.markForDeletion(user);
  }

  static markAsSynced(user: LocalUser, serverId?: number): LocalUser {
    return LocalUserImpl.markAsSynced(user, serverId);
  }

  static markSyncFailed(user: LocalUser, error: string): LocalUser {
    return LocalUserImpl.markSyncFailed(user, error);
  }

  static needsSync(user: LocalUser): boolean {
    return LocalUserImpl.needsSync(user);
  }

  static copyWithUpdates(user: LocalUser, email: string, firstName: string, lastName: string, avatar: string): LocalUser {
    return LocalUserImpl.copyWithUpdates(user, email, firstName, lastName, avatar);
  }

  static incrementVersion(user: LocalUser): LocalUser {
    return LocalUserImpl.incrementVersion(user);
  }

  static fromRemote(remote: User, existingLocal: LocalUser): LocalUser {
    return LocalUserImpl.fromRemote(remote, existingLocal);
  }
}
