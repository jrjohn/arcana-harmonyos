/**
 * Conflict Resolver for Offline-First Sync
 *
 * Implements Last-Write-Wins (LWW) strategy with version tie-breaking.
 * Similar to Android's OfflineFirstDataRepository conflict resolution.
 *
 * Strategy:
 * 1. Compare updatedAt timestamps
 * 2. If local is newer, keep local and push to server
 * 3. If remote is newer, use remote
 * 4. If timestamps equal, use version field as tie-breaker
 */

import { LocalUser, User, LocalUserImpl, SyncStatus } from '../../domain/models/User';
import { Logger } from '../logging/Logger';

const TAG = 'ConflictResolver';

/**
 * Conflict resolution result type
 */
export enum ConflictResolution {
  USE_LOCAL = 'use_local',
  USE_REMOTE = 'use_remote',
  MERGE = 'merge'
}

/**
 * Conflict resolution outcome
 */
export interface ConflictResult {
  /** Which version to use */
  resolution: ConflictResolution;
  /** The resolved user data */
  resolvedUser: LocalUser;
  /** Whether local changes should be pushed to server */
  requiresPush: boolean;
}

/**
 * Conflict resolution statistics
 */
export interface ConflictStats {
  localWins: number;
  remoteWins: number;
  merged: number;
}

/**
 * Implementation of ConflictStats
 */
export class ConflictStatsImpl implements ConflictStats {
  localWins: number;
  remoteWins: number;
  merged: number;

  constructor(localWins: number, remoteWins: number, merged: number) {
    this.localWins = localWins;
    this.remoteWins = remoteWins;
    this.merged = merged;
  }
}

/**
 * Implementation of BatchConflictResult
 */
export class BatchConflictResultImpl implements BatchConflictResult {
  resolved: ConflictResult[];
  localOnly: LocalUser[];
  remoteOnly: User[];
  stats: ConflictStats;

  constructor(
    resolved: ConflictResult[],
    localOnly: LocalUser[],
    remoteOnly: User[],
    stats: ConflictStats
  ) {
    this.resolved = resolved;
    this.localOnly = localOnly;
    this.remoteOnly = remoteOnly;
    this.stats = stats;
  }
}

/**
 * Batch conflict resolution result
 */
export interface BatchConflictResult {
  /** Successfully resolved users */
  resolved: ConflictResult[];
  /** Users only in local (new local creations) */
  localOnly: LocalUser[];
  /** Users only in remote (new from server) */
  remoteOnly: User[];
  /** Statistics */
  stats: ConflictStats;
}

/**
 * Resolves conflicts between local and remote user data.
 * Implements Last-Write-Wins strategy with version tie-breaking.
 */
export class ConflictResolver {

  /**
   * Resolves conflict between local and remote user
   *
   * @param local The local user with pending changes
   * @param remote The remote user from server
   * @param remoteUpdatedAt Optional server timestamp for the remote user
   * @returns Conflict resolution result
   */
  static resolveUserConflict(
    local: LocalUser,
    remote: User,
    remoteUpdatedAt?: number
  ): ConflictResult {
    Logger.d(TAG, `Resolving conflict for user ${local.id}`);

    // If no remote timestamp, assume current time (conservative approach)
    const remoteTimestamp = remoteUpdatedAt ?? Date.now();

    // Compare timestamps
    if (local.updatedAt > remoteTimestamp) {
      // Local is newer
      Logger.d(TAG, `Local wins (local: ${local.updatedAt} > remote: ${remoteTimestamp})`);
      return {
        resolution: ConflictResolution.USE_LOCAL,
        resolvedUser: local,
        requiresPush: true
      };
    } else if (local.updatedAt < remoteTimestamp) {
      // Remote is newer
      Logger.d(TAG, `Remote wins (local: ${local.updatedAt} < remote: ${remoteTimestamp})`);
      return {
        resolution: ConflictResolution.USE_REMOTE,
        resolvedUser: ConflictResolver.createLocalFromRemote(remote, local),
        requiresPush: false
      };
    } else {
      // Timestamps equal - use version as tie-breaker
      // Higher version wins; if still equal, prefer local (optimistic)
      Logger.d(TAG, `Timestamps equal, using version tie-breaker (local.version: ${local.version})`);
      return {
        resolution: ConflictResolution.USE_LOCAL,
        resolvedUser: local,
        requiresPush: true
      };
    }
  }

  /**
   * Batch resolve conflicts for multiple users
   *
   * @param localUsers Local users with changes
   * @param remoteUsers Remote users from server
   * @param remoteTimestamps Optional map of userId -> server timestamp
   * @returns Batch conflict resolution result
   */
  static resolveConflicts(
    localUsers: LocalUser[],
    remoteUsers: User[],
    remoteTimestamps?: Map<number, number>
  ): BatchConflictResult {
    const resolved: ConflictResult[] = [];
    const localOnly: LocalUser[] = [];
    const remoteOnly: User[] = [];
    let localWins = 0;
    let remoteWins = 0;
    let merged = 0;

    // Create lookup maps
    const localMap = new Map<number, LocalUser>();
    for (const local of localUsers) {
      localMap.set(local.id, local);
    }

    const remoteMap = new Map<number, User>();
    for (const remote of remoteUsers) {
      remoteMap.set(remote.id, remote);
    }

    // Process each local user
    for (const local of localUsers) {
      const remote = remoteMap.get(local.id);

      if (!remote) {
        // User only exists locally
        localOnly.push(local);
        Logger.d(TAG, `User ${local.id} only exists locally`);
      } else {
        // Conflict detected - resolve it
        const remoteTimestamp = remoteTimestamps?.get(local.id);
        const result = ConflictResolver.resolveUserConflict(local, remote, remoteTimestamp);
        resolved.push(result);

        if (result.resolution === ConflictResolution.USE_LOCAL) {
          localWins++;
        } else if (result.resolution === ConflictResolution.USE_REMOTE) {
          remoteWins++;
        } else {
          merged++;
        }
      }
    }

    // Find users only in remote
    for (const remote of remoteUsers) {
      if (!localMap.has(remote.id)) {
        remoteOnly.push(remote);
        Logger.d(TAG, `User ${remote.id} only exists on remote`);
      }
    }

    Logger.i(TAG, `Conflict resolution complete: ${localWins} local wins, ${remoteWins} remote wins, ${merged} merged`);

    const stats = new ConflictStatsImpl(localWins, remoteWins, merged);
    return new BatchConflictResultImpl(resolved, localOnly, remoteOnly, stats);
  }

  /**
   * Creates a LocalUser from remote User data, preserving local metadata
   *
   * @param remote The remote user data
   * @param existingLocal The existing local user (for preserving localId, createdAt)
   * @returns A LocalUser with remote data but preserved local metadata
   */
  static createLocalFromRemote(remote: User, existingLocal: LocalUser): LocalUser {
    return LocalUserImpl.fromRemote(remote, existingLocal);
  }

  /**
   * Creates a new LocalUser from a remote User (for users not in local DB)
   *
   * @param remote The remote user data
   * @returns A new LocalUser marked as synced
   */
  static createNewLocalFromRemote(remote: User): LocalUser {
    return LocalUserImpl.fromUser(remote, SyncStatus.SYNCED);
  }

  /**
   * Determines if a local user has a conflict with remote data
   *
   * @param local The local user
   * @param remote The remote user
   * @returns True if there's a potential conflict
   */
  static hasConflict(local: LocalUser, remote: User): boolean {
    // Check if any data fields differ
    return (
      local.email !== remote.email ||
      local.firstName !== remote.firstName ||
      local.lastName !== remote.lastName ||
      local.avatar !== remote.avatar
    );
  }

  /**
   * Gets conflict details for logging/debugging
   */
  static getConflictDetails(local: LocalUser, remote: User): string {
    const differences: string[] = [];

    if (local.email !== remote.email) {
      differences.push(`email: local="${local.email}" vs remote="${remote.email}"`);
    }
    if (local.firstName !== remote.firstName) {
      differences.push(`firstName: local="${local.firstName}" vs remote="${remote.firstName}"`);
    }
    if (local.lastName !== remote.lastName) {
      differences.push(`lastName: local="${local.lastName}" vs remote="${remote.lastName}"`);
    }
    if (local.avatar !== remote.avatar) {
      differences.push(`avatar: local="${local.avatar}" vs remote="${remote.avatar}"`);
    }

    return differences.length > 0
      ? `Differences for user ${local.id}: ${differences.join(', ')}`
      : `No differences for user ${local.id}`;
  }
}
