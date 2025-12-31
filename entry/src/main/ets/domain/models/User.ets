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
    syncError?: string
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
      undefined
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
      undefined
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
      user.syncError
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
      user.syncError
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
      undefined
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
      error
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
      user.syncError
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
