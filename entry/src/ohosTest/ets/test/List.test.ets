/**
 * Test Suite Entry Point
 * Registers all unit test modules
 */

// Existing Tests
import ContainerTest from './Container.test';
import RateLimiterTest from './RateLimiter.test';
import NavigationTest from './Navigation.test';
import MockServicesTest from './MockServices.test';
import LocalizationTest from './Localization.test';

// Domain Layer Tests
import UserTest from './domain/User.test';
import ResultTest from './domain/Result.test';
import AppErrorTest from './domain/AppError.test';
import EmailValidatorTest from './domain/EmailValidator.test';
import NameValidatorTest from './domain/NameValidator.test';
import UserValidatorTest from './domain/UserValidator.test';

// Data Layer Tests
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

// Presentation Layer Tests
import BaseViewModelTest from './presentation/BaseViewModel.test';
import UserListViewModelTest from './presentation/UserListViewModel.test';

export default function testsuite() {
  // ===== Core Infrastructure Tests =====
  ContainerTest();
  RateLimiterTest();
  NavigationTest();
  MockServicesTest();
  LocalizationTest();

  // ===== Domain Layer Tests =====
  // Models
  UserTest();
  ResultTest();
  AppErrorTest();

  // Validators
  EmailValidatorTest();
  NameValidatorTest();
  UserValidatorTest();

  // ===== Data Layer Tests =====
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
  BaseViewModelTest();
  UserListViewModelTest();
}
