/**
 * Container Modules
 * Organizes service bindings into logical groups
 * Similar to InversifyJS ContainerModule pattern
 */

import { common } from '@kit.AbilityKit';
import { IContainerModule, IAsyncContainerModule, ServiceIdentifier, IBindingTo } from './types';
import { TYPES, MODULES } from './tokens';
import {
  INetworkMonitor,
  ILogger,
  ISyncManager,
  IAnalyticsService,
  IUserRepositoryService,
  IUserApiService,
  IUserLocalDataSource,
  IContextProvider
} from './interfaces';

// Import implementations
import { NetworkMonitorService } from '../network/impl/NetworkMonitorService';
import { LoggerService } from '../logging/impl/LoggerService';
import { SyncManagerService } from '../sync/impl/SyncManagerService';
import { AnalyticsServiceImpl } from '../analytics/impl/AnalyticsServiceImpl';
import { UserRepositoryService } from '../../domain/repository/impl/UserRepositoryService';
import { UserApiServiceImpl } from '../../data/api/impl/UserApiServiceImpl';
import { UserLocalDataSourceImpl } from '../../data/local/impl/UserLocalDataSourceImpl';

/**
 * Context provider implementation
 * Holds the UIAbilityContext for services that need it
 */
class ContextProviderImpl implements IContextProvider {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  getContext(): common.UIAbilityContext {
    return this.context;
  }
}

/**
 * Creates the core services module
 * Binds: Logger, NetworkMonitor, AnalyticsService
 */
export function createCoreModule(context: common.UIAbilityContext): IContainerModule {
  return {
    id: MODULES.Core,
    registry: (bind) => {
      // Context provider (singleton, set immediately)
      bind<IContextProvider>(TYPES.ContextProvider)
        .toConstantValue(new ContextProviderImpl(context));

      // Logger (singleton)
      bind<ILogger>(TYPES.Logger)
        .toDynamicValue(() => new LoggerService())
        .inSingletonScope();

      // Network monitor (singleton, requires async init)
      bind<INetworkMonitor>(TYPES.NetworkMonitor)
        .toDynamicValue(() => new NetworkMonitorService())
        .inSingletonScope();

      // Analytics (singleton, requires async init)
      bind<IAnalyticsService>(TYPES.AnalyticsService)
        .toDynamicValue(() => new AnalyticsServiceImpl())
        .inSingletonScope();
    }
  };
}

/**
 * Creates the data layer module
 * Binds: UserApiService, UserLocalDataSource, UserRepository
 */
export function createDataModule(): IContainerModule {
  return {
    id: MODULES.Data,
    registry: (bind) => {
      // API service (singleton)
      bind<IUserApiService>(TYPES.UserApiService)
        .toDynamicValue(() => new UserApiServiceImpl())
        .inSingletonScope();

      // Local data source (singleton, needs context)
      bind<IUserLocalDataSource>(TYPES.UserLocalDataSource)
        .toDynamicValue((container) => {
          const contextProvider = container.get<IContextProvider>(TYPES.ContextProvider);
          return new UserLocalDataSourceImpl(contextProvider.getContext());
        })
        .inSingletonScope();

      // Repository (singleton, combines API and local)
      bind<IUserRepositoryService>(TYPES.UserRepository)
        .toDynamicValue((container) => {
          const apiService = container.get<IUserApiService>(TYPES.UserApiService);
          const localDataSource = container.get<IUserLocalDataSource>(TYPES.UserLocalDataSource);
          const logger = container.get<ILogger>(TYPES.Logger);
          return new UserRepositoryService(apiService, localDataSource, logger);
        })
        .inSingletonScope();
    }
  };
}

/**
 * Creates the sync module
 * Binds: SyncManager (depends on repository and network)
 */
export function createSyncModule(): IContainerModule {
  return {
    id: MODULES.Domain,
    registry: (bind) => {
      // Sync manager (singleton)
      bind<ISyncManager>(TYPES.SyncManager)
        .toDynamicValue((container) => {
          const repository = container.get<IUserRepositoryService>(TYPES.UserRepository);
          const networkMonitor = container.get<INetworkMonitor>(TYPES.NetworkMonitor);
          const logger = container.get<ILogger>(TYPES.Logger);
          return new SyncManagerService(repository, networkMonitor, logger);
        })
        .inSingletonScope();
    }
  };
}

/**
 * Async module for services requiring initialization
 */
export function createAsyncInitModule(): IAsyncContainerModule {
  return {
    id: 'AsyncInitModule',
    registry: async (bind) => {
      // This module doesn't add bindings, but initializes existing ones
      // The actual initialization happens in ContainerInitializer
    }
  };
}

/**
 * Testing module with mock implementations
 * Use this to override production bindings in tests
 */
export function createTestingModule(): IContainerModule {
  return {
    id: MODULES.Testing,
    registry: (bind) => {
      // Override with mock implementations
      // Example:
      // bind<ILogger>(TYPES.Logger)
      //   .toConstantValue(new MockLogger())
      //   .inSingletonScope();
    }
  };
}

/**
 * Container module loader helper
 */
export interface ModuleLoader {
  loadCoreModule(context: common.UIAbilityContext): void;
  loadDataModule(): void;
  loadSyncModule(): void;
  loadTestingModule(): void;
}
