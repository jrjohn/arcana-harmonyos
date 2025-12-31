/**
 * Unit Tests for Mock Services (Testing Infrastructure)
 */

import { describe, it, expect, beforeEach } from '@ohos/hypium';
import {
  MockLogger,
  MockNetworkMonitor,
  MockSyncManager,
  MockAnalyticsService,
  MockUserApiService,
  MockUserLocalDataSource,
  createTestContainer,
  createSampleUser,
  createSampleLocalUser
} from '../../../main/ets/core/di/testing';
import { TYPES } from '../../../main/ets/core/di/tokens';
import { NetworkStatus } from '../../../main/ets/core/network/NetworkMonitor';
import { SyncStatus } from '../../../main/ets/domain/models/User';

export default function MockServicesTest() {
  describe('MockLogger', () => {
    let logger: MockLogger;

    beforeEach(() => {
      logger = new MockLogger();
    });

    it('should record debug logs', () => {
      logger.d('TestTag', 'Debug message');

      expect(logger.logs.length).assertEqual(1);
      expect(logger.logs[0].level).assertEqual('DEBUG');
      expect(logger.logs[0].tag).assertEqual('TestTag');
      expect(logger.logs[0].message).assertEqual('Debug message');
    });

    it('should record all log levels', () => {
      logger.d('Tag', 'debug');
      logger.i('Tag', 'info');
      logger.w('Tag', 'warn');
      logger.e('Tag', 'error');
      logger.f('Tag', 'fatal');

      expect(logger.logs.length).assertEqual(5);
    });

    it('should not record when disabled', () => {
      logger.setEnabled(false);
      logger.d('Tag', 'message');

      expect(logger.logs.length).assertEqual(0);
    });

    it('should clear logs', () => {
      logger.d('Tag', 'message1');
      logger.d('Tag', 'message2');
      logger.clear();

      expect(logger.logs.length).assertEqual(0);
    });

    it('should check for log existence', () => {
      logger.e('ErrorTag', 'Something failed');

      expect(logger.hasLog('ERROR', 'failed')).assertTrue();
      expect(logger.hasLog('DEBUG', 'failed')).assertFalse();
    });
  });

  describe('MockNetworkMonitor', () => {
    let networkMonitor: MockNetworkMonitor;

    beforeEach(() => {
      networkMonitor = new MockNetworkMonitor(true);
    });

    it('should start as online by default', async () => {
      const available = await networkMonitor.isNetworkAvailable();
      expect(available).assertTrue();
    });

    it('should allow setting offline', async () => {
      networkMonitor.setOnline(false);

      const available = await networkMonitor.isNetworkAvailable();
      expect(available).assertFalse();
    });

    it('should notify subscribers of state changes', async () => {
      let notifiedState: any;
      networkMonitor.subscribe((state) => {
        notifiedState = state;
      });

      networkMonitor.setOnline(false);

      expect(notifiedState.status).assertEqual(NetworkStatus.UNAVAILABLE);
    });

    it('should allow unsubscribe', () => {
      let callCount = 0;
      const unsubscribe = networkMonitor.subscribe(() => {
        callCount++;
      });

      // Initial call
      expect(callCount).assertEqual(1);

      unsubscribe();
      networkMonitor.setOnline(false);

      // Should not be called after unsubscribe
      expect(callCount).assertEqual(1);
    });
  });

  describe('MockSyncManager', () => {
    let syncManager: MockSyncManager;

    beforeEach(() => {
      syncManager = new MockSyncManager();
    });

    it('should start not syncing', () => {
      const state = syncManager.getState();
      expect(state.isSyncing).assertFalse();
    });

    it('should track trigger sync calls', async () => {
      await syncManager.triggerSync();
      await syncManager.triggerSync();

      expect(syncManager.syncTriggerCount).assertEqual(2);
    });

    it('should allow setting state', () => {
      syncManager.setState({
        isSyncing: true,
        pendingCount: 5
      });

      const state = syncManager.getState();
      expect(state.isSyncing).assertTrue();
      expect(state.pendingCount).assertEqual(5);
    });

    it('should notify subscribers of state changes', () => {
      let notifiedState: any;
      syncManager.subscribe((state) => {
        notifiedState = state;
      });

      syncManager.setState({ pendingCount: 10 });

      expect(notifiedState.pendingCount).assertEqual(10);
    });
  });

  describe('MockAnalyticsService', () => {
    let analytics: MockAnalyticsService;

    beforeEach(() => {
      analytics = new MockAnalyticsService();
    });

    it('should track screens', () => {
      analytics.trackScreen('HomeScreen');
      analytics.trackScreen('DetailScreen');

      expect(analytics.screens.length).assertEqual(2);
      expect(analytics.screens[0]).assertEqual('HomeScreen');
      expect(analytics.getCurrentScreen()).assertEqual('DetailScreen');
    });

    it('should track events', () => {
      analytics.trackEvent('button_click', { button: 'submit' });

      expect(analytics.events.length).assertEqual(1);
      expect(analytics.events[0].type).assertEqual('event');
      expect(analytics.events[0].name).assertEqual('button_click');
    });

    it('should track actions', () => {
      analytics.trackAction('tap', 'user_card');

      expect(analytics.hasEvent('tap:user_card')).assertTrue();
    });

    it('should track errors', () => {
      analytics.trackError('E001', 'Network failed');

      expect(analytics.hasEvent('E001')).assertTrue();
    });

    it('should clear tracking data', () => {
      analytics.trackScreen('Screen');
      analytics.trackEvent('event');
      analytics.clear();

      expect(analytics.screens.length).assertEqual(0);
      expect(analytics.events.length).assertEqual(0);
    });
  });

  describe('MockUserApiService', () => {
    let apiService: MockUserApiService;

    beforeEach(() => {
      apiService = new MockUserApiService();
    });

    it('should return empty users initially', async () => {
      const result = await apiService.getUsers();

      expect(result.isSuccess).assertTrue();
      if (result.isSuccess) {
        expect(result.value.users.length).assertEqual(0);
      }
    });

    it('should add and retrieve users', async () => {
      const user = createSampleUser({ id: 1, firstName: 'John' });
      apiService.addUser(user);

      const result = await apiService.getUser(1);

      expect(result.isSuccess).assertTrue();
      if (result.isSuccess) {
        expect(result.value.firstName).assertEqual('John');
      }
    });

    it('should paginate users', async () => {
      for (let i = 1; i <= 15; i++) {
        apiService.addUser(createSampleUser({ id: i }));
      }

      const page1 = await apiService.getUsers(1, 10);
      const page2 = await apiService.getUsers(2, 10);

      if (page1.isSuccess && page2.isSuccess) {
        expect(page1.value.users.length).assertEqual(10);
        expect(page2.value.users.length).assertEqual(5);
        expect(page1.value.totalPages).assertEqual(2);
      }
    });

    it('should create user', async () => {
      const result = await apiService.createUser({
        email: 'new@example.com',
        firstName: 'New',
        lastName: 'User'
      });

      expect(result.isSuccess).assertTrue();
      if (result.isSuccess) {
        expect(result.value.email).assertEqual('new@example.com');
        expect(result.value.id).toBeGreaterThan(0);
      }
    });

    it('should update user', async () => {
      apiService.addUser(createSampleUser({ id: 1, firstName: 'Original' }));

      const result = await apiService.updateUser({
        id: 1,
        email: 'updated@example.com',
        firstName: 'Updated',
        lastName: 'Name'
      });

      expect(result.isSuccess).assertTrue();
      if (result.isSuccess) {
        expect(result.value.firstName).assertEqual('Updated');
      }
    });

    it('should delete user', async () => {
      apiService.addUser(createSampleUser({ id: 1 }));

      await apiService.deleteUser(1);

      const result = await apiService.getUser(1);
      expect(result.isSuccess).assertFalse();
    });

    it('should simulate failures', async () => {
      apiService.setFailure({ code: 'E1001', message: 'Network error' } as any);

      const result = await apiService.getUsers();

      expect(result.isSuccess).assertFalse();
    });

    it('should clear failures', async () => {
      apiService.setFailure({ code: 'E1001', message: 'Error' } as any);
      apiService.clearFailure();

      const result = await apiService.getUsers();
      expect(result.isSuccess).assertTrue();
    });
  });

  describe('MockUserLocalDataSource', () => {
    let localDataSource: MockUserLocalDataSource;

    beforeEach(() => {
      localDataSource = new MockUserLocalDataSource();
    });

    it('should start empty', async () => {
      const users = await localDataSource.getAllUsers();
      expect(users.length).assertEqual(0);
    });

    it('should save and retrieve user', async () => {
      const user = createSampleLocalUser({ id: 1, firstName: 'Local' });
      await localDataSource.saveUser(user);

      const retrieved = await localDataSource.getUser(1);
      expect(retrieved?.firstName).assertEqual('Local');
    });

    it('should update existing user', async () => {
      const user = createSampleLocalUser({ id: 1, firstName: 'Original' });
      await localDataSource.saveUser(user);

      const updated = { ...user, firstName: 'Updated' };
      await localDataSource.saveUser(updated);

      const retrieved = await localDataSource.getUser(1);
      expect(retrieved?.firstName).assertEqual('Updated');
    });

    it('should get users by sync status', async () => {
      await localDataSource.saveUser(createSampleLocalUser({ id: 1, syncStatus: SyncStatus.SYNCED }));
      await localDataSource.saveUser(createSampleLocalUser({ id: 2, syncStatus: SyncStatus.PENDING_CREATE }));
      await localDataSource.saveUser(createSampleLocalUser({ id: 3, syncStatus: SyncStatus.PENDING_UPDATE }));

      const pending = await localDataSource.getUsersBySyncStatus([
        SyncStatus.PENDING_CREATE,
        SyncStatus.PENDING_UPDATE
      ]);

      expect(pending.length).assertEqual(2);
    });

    it('should track last sync time', async () => {
      const now = Date.now();
      await localDataSource.setLastSyncTime(now);

      const syncTime = await localDataSource.getLastSyncTime();
      expect(syncTime).assertEqual(now);
    });

    it('should clear all data', async () => {
      await localDataSource.saveUser(createSampleLocalUser({ id: 1 }));
      await localDataSource.setLastSyncTime(Date.now());

      await localDataSource.clearAll();

      const users = await localDataSource.getAllUsers();
      const syncTime = await localDataSource.getLastSyncTime();

      expect(users.length).assertEqual(0);
      expect(syncTime).toBeUndefined();
    });
  });

  describe('Test Container Factory', () => {
    it('should create container with all mock services', () => {
      const container = createTestContainer();

      expect(container.isBound(TYPES.Logger)).assertTrue();
      expect(container.isBound(TYPES.NetworkMonitor)).assertTrue();
      expect(container.isBound(TYPES.SyncManager)).assertTrue();
      expect(container.isBound(TYPES.AnalyticsService)).assertTrue();
      expect(container.isBound(TYPES.UserApiService)).assertTrue();
      expect(container.isBound(TYPES.UserLocalDataSource)).assertTrue();
    });

    it('should resolve mock logger', () => {
      const container = createTestContainer();
      const logger = container.get<MockLogger>(TYPES.Logger);

      logger.d('Test', 'message');
      expect(logger.logs.length).assertEqual(1);
    });
  });

  describe('Sample Data Factories', () => {
    it('should create sample user with defaults', () => {
      const user = createSampleUser();

      expect(user.id).assertEqual(1);
      expect(user.email).assertEqual('test@example.com');
    });

    it('should create sample user with overrides', () => {
      const user = createSampleUser({ id: 99, firstName: 'Custom' });

      expect(user.id).assertEqual(99);
      expect(user.firstName).assertEqual('Custom');
      expect(user.lastName).assertEqual('User'); // default
    });

    it('should create sample local user with defaults', () => {
      const user = createSampleLocalUser();

      expect(user.syncStatus).assertEqual(SyncStatus.SYNCED);
      expect(user.syncAttempts).assertEqual(0);
    });

    it('should create sample local user with overrides', () => {
      const user = createSampleLocalUser({
        syncStatus: SyncStatus.PENDING_CREATE,
        syncAttempts: 3
      });

      expect(user.syncStatus).assertEqual(SyncStatus.PENDING_CREATE);
      expect(user.syncAttempts).assertEqual(3);
    });
  });
}
