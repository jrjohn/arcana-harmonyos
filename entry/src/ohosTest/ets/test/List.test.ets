/**
 * Test Suite Entry Point
 * Registers all unit test and integration test modules
 *
 * Test Coverage Target: 100%
 * Includes: Unit Tests, Integration Tests, End-to-End Tests
 */

// ===== Existing Core Tests =====
import ContainerTest from './Container.test';
import RateLimiterTest from './RateLimiter.test';
import NavigationTest from './Navigation.test';
import MockServicesTest from './MockServices.test';
import LocalizationTest from './Localization.test';

// ===== Core DI Tests =====
import TypesTest from './core/di/types.test';
import DecoratorsTest from './core/di/decorators.test';

// ===== Core Logging Tests =====
import LoggerTest from './core/logging/Logger.test';

// ===== Core Network Tests =====
import NetworkMonitorTest from './core/network/NetworkMonitor.test';

// ===== Core Analytics Tests =====
import AnalyticsServiceTest from './core/analytics/AnalyticsService.test';

// ===== Core Navigation Tests =====
import NavigationCoreTest from './core/navigation/Navigation.test';

// ===== Core Security Tests =====
import SecureStorageTest from './core/security/SecureStorage.test';

// ===== Core Sync Tests =====
import SyncManagerTest from './core/sync/SyncManager.test';

// ===== Domain Layer Tests =====
import UserTest from './domain/User.test';
import ResultTest from './domain/Result.test';
import AppErrorTest from './domain/AppError.test';
import EmailValidatorTest from './domain/EmailValidator.test';
import NameValidatorTest from './domain/NameValidator.test';
import UserValidatorTest from './domain/UserValidator.test';

// ===== Data Layer Tests =====
import LruCacheTest from './data/LruCache.test';
import ApiConfigTest from './data/ApiConfig.test';
import UserDtoTest from './data/UserDto.test';
import UserApiServiceImplTest from './data/UserApiServiceImpl.test';
import UserApiServiceIntegrationTest from './data/UserApiServiceIntegration.test';
import SyncExecutorTest from './data/SyncExecutor.test';
import BackgroundSchedulerTest from './data/BackgroundScheduler.test';
import RdbStoreManagerTest from './data/RdbStoreManager.test';
import UserLocalDataSourceRdbTest from './data/UserLocalDataSourceRdb.test';
import DataMigrationTest from './data/DataMigration.test';

// ===== Presentation Layer Tests =====
import BaseViewModelTest from './presentation/BaseViewModel.test';
import UserListViewModelTest from './presentation/UserListViewModel.test';
import UserFormViewModelTest from './presentation/UserFormViewModel.test';
import UserDetailViewModelTest from './presentation/UserDetailViewModel.test';

// ===== Worker Tests =====
import SyncWorkerTest from './workers/SyncWorker.test';

// ===== Integration Tests =====
import EndToEndTest from './integration/EndToEnd.test';
import DataFlowTest from './integration/DataFlow.test';

export default function testsuite() {
  // ===== Core Infrastructure Tests =====
  console.info('Running Core Infrastructure Tests...');
  ContainerTest();
  RateLimiterTest();
  NavigationTest();
  MockServicesTest();
  LocalizationTest();

  // ===== Core DI Tests =====
  console.info('Running Core DI Tests...');
  TypesTest();
  DecoratorsTest();

  // ===== Core Logging Tests =====
  console.info('Running Core Logging Tests...');
  LoggerTest();

  // ===== Core Network Tests =====
  console.info('Running Core Network Tests...');
  NetworkMonitorTest();

  // ===== Core Analytics Tests =====
  console.info('Running Core Analytics Tests...');
  AnalyticsServiceTest();

  // ===== Core Navigation Tests =====
  console.info('Running Core Navigation Tests...');
  NavigationCoreTest();

  // ===== Core Security Tests =====
  console.info('Running Core Security Tests...');
  SecureStorageTest();

  // ===== Core Sync Tests =====
  console.info('Running Core Sync Tests...');
  SyncManagerTest();

  // ===== Domain Layer Tests =====
  console.info('Running Domain Layer Tests...');
  // Models
  UserTest();
  ResultTest();
  AppErrorTest();

  // Validators
  EmailValidatorTest();
  NameValidatorTest();
  UserValidatorTest();

  // ===== Data Layer Tests =====
  console.info('Running Data Layer Tests...');
  // Cache
  LruCacheTest();

  // API Configuration
  ApiConfigTest();

  // DTOs and Mappers
  UserDtoTest();

  // API Services (Unit Tests)
  UserApiServiceImplTest();

  // API Services (Integration Tests)
  UserApiServiceIntegrationTest();

  // Background Sync (WorkScheduler)
  SyncExecutorTest();
  BackgroundSchedulerTest();

  // RDB (RelationalStore) Tests
  RdbStoreManagerTest();
  UserLocalDataSourceRdbTest();
  DataMigrationTest();

  // ===== Presentation Layer Tests =====
  console.info('Running Presentation Layer Tests...');
  BaseViewModelTest();
  UserListViewModelTest();
  UserFormViewModelTest();
  UserDetailViewModelTest();

  // ===== Worker Tests =====
  console.info('Running Worker Tests...');
  SyncWorkerTest();

  // ===== Integration Tests =====
  console.info('Running Integration Tests...');
  EndToEndTest();
  DataFlowTest();

  console.info('All tests registered successfully!');
}
