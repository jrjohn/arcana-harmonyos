/**
 * Jest entry point for ArkTS unit tests.
 * Imports all hypium test modules and calls them to register tests with Jest.
 *
 * @ohos/hypium is shimmed to Jest describe/it/expect via moduleNameMapper.
 * @kit.* platform APIs are mocked via kit-mock.js Proxy.
 */

// Domain layer
import AppErrorTest from '../entry/src/ohosTest/ets/test/domain/AppError.test.ts';
import ResultTest from '../entry/src/ohosTest/ets/test/domain/Result.test.ts';
import UserTest from '../entry/src/ohosTest/ets/test/domain/User.test.ts';
import EmailValidatorTest from '../entry/src/ohosTest/ets/test/domain/EmailValidator.test.ts';
import NameValidatorTest from '../entry/src/ohosTest/ets/test/domain/NameValidator.test.ts';
import UserValidatorTest from '../entry/src/ohosTest/ets/test/domain/UserValidator.test.ts';

// Core layer
import LoggerTest from '../entry/src/ohosTest/ets/test/core/logging/Logger.test.ts';
import RateLimiterTest from '../entry/src/ohosTest/ets/test/RateLimiter.test.ts';
import NetworkMonitorTest from '../entry/src/ohosTest/ets/test/core/network/NetworkMonitor.test.ts';
import AnalyticsServiceTest from '../entry/src/ohosTest/ets/test/core/analytics/AnalyticsService.test.ts';

// DI layer
import TypesTest from '../entry/src/ohosTest/ets/test/core/di/types.test.ts';
import DecoratorsTest from '../entry/src/ohosTest/ets/test/core/di/decorators.test.ts';
import ContainerTest from '../entry/src/ohosTest/ets/test/Container.test.ts';

// Data layer
import LruCacheTest from '../entry/src/ohosTest/ets/test/data/LruCache.test.ts';
import ApiConfigTest from '../entry/src/ohosTest/ets/test/data/ApiConfig.test.ts';
import UserDtoTest from '../entry/src/ohosTest/ets/test/data/UserDto.test.ts';
import SyncExecutorTest from '../entry/src/ohosTest/ets/test/data/SyncExecutor.test.ts';

// Presentation layer
import BaseViewModelTest from '../entry/src/ohosTest/ets/test/presentation/BaseViewModel.test.ts';
import UserListViewModelTest from '../entry/src/ohosTest/ets/test/presentation/UserListViewModel.test.ts';
import UserDetailViewModelTest from '../entry/src/ohosTest/ets/test/presentation/UserDetailViewModel.test.ts';
import UserFormViewModelTest from '../entry/src/ohosTest/ets/test/presentation/UserFormViewModel.test.ts';

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
