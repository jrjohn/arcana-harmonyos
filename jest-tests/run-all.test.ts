/**
 * Jest entry point for ArkTS unit tests.
 * Imports all hypium test modules and calls them to register tests with Jest.
 *
 * @ohos/hypium is shimmed to Jest describe/it/expect via moduleNameMapper.
 * @kit.* platform APIs are mocked via kit-mock.js Proxy.
 */

// Domain layer
import AppErrorTest from '../entry/src/ohosTest/ets/test/domain/AppError.test';
import ResultTest from '../entry/src/ohosTest/ets/test/domain/Result.test';
import UserTest from '../entry/src/ohosTest/ets/test/domain/User.test';
import EmailValidatorTest from '../entry/src/ohosTest/ets/test/domain/EmailValidator.test';
import NameValidatorTest from '../entry/src/ohosTest/ets/test/domain/NameValidator.test';
import UserValidatorTest from '../entry/src/ohosTest/ets/test/domain/UserValidator.test';

// Core layer
import LoggerTest from '../entry/src/ohosTest/ets/test/core/logging/Logger.test';
import RateLimiterTest from '../entry/src/ohosTest/ets/test/RateLimiter.test';
import NetworkMonitorTest from '../entry/src/ohosTest/ets/test/core/network/NetworkMonitor.test';
import AnalyticsServiceTest from '../entry/src/ohosTest/ets/test/core/analytics/AnalyticsService.test';

// DI layer
import TypesTest from '../entry/src/ohosTest/ets/test/core/di/types.test';
import DecoratorsTest from '../entry/src/ohosTest/ets/test/core/di/decorators.test';
import ContainerTest from '../entry/src/ohosTest/ets/test/Container.test';

// Data layer
import LruCacheTest from '../entry/src/ohosTest/ets/test/data/LruCache.test';
import ApiConfigTest from '../entry/src/ohosTest/ets/test/data/ApiConfig.test';
import UserDtoTest from '../entry/src/ohosTest/ets/test/data/UserDto.test';
import SyncExecutorTest from '../entry/src/ohosTest/ets/test/data/SyncExecutor.test';

// Presentation layer
import BaseViewModelTest from '../entry/src/ohosTest/ets/test/presentation/BaseViewModel.test';
import UserListViewModelTest from '../entry/src/ohosTest/ets/test/presentation/UserListViewModel.test';
import UserDetailViewModelTest from '../entry/src/ohosTest/ets/test/presentation/UserDetailViewModel.test';
import UserFormViewModelTest from '../entry/src/ohosTest/ets/test/presentation/UserFormViewModel.test';

// Register all tests (hypium functions call describe/it from shim → jest)
AppErrorTest();
ResultTest();
UserTest();
EmailValidatorTest();
NameValidatorTest();
UserValidatorTest();

LoggerTest();
RateLimiterTest();
NetworkMonitorTest();
AnalyticsServiceTest();

TypesTest();
DecoratorsTest();
ContainerTest();

LruCacheTest();
ApiConfigTest();
UserDtoTest();
SyncExecutorTest();

BaseViewModelTest();
UserListViewModelTest();
UserDetailViewModelTest();
UserFormViewModelTest();
