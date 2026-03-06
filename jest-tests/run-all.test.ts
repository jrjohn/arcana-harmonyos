/**
 * Jest entry point for ArkTS domain-layer tests.
 * Only runs tests for pure TypeScript domain code (no @kit.* dependencies).
 * Coverage is collected over domain + data cache + presentation viewmodel layers.
 *
 * @ohos/hypium is shimmed to Jest describe/it/expect via moduleNameMapper.
 */

// Domain layer — pure TypeScript, no @kit dependencies
import AppErrorTest from '../entry/src/ohosTest/ets/test/domain/AppError.test.ts';
import ResultTest from '../entry/src/ohosTest/ets/test/domain/Result.test.ts';
import UserTest from '../entry/src/ohosTest/ets/test/domain/User.test.ts';
import EmailValidatorTest from '../entry/src/ohosTest/ets/test/domain/EmailValidator.test.ts';
import NameValidatorTest from '../entry/src/ohosTest/ets/test/domain/NameValidator.test.ts';
import UserValidatorTest from '../entry/src/ohosTest/ets/test/domain/UserValidator.test.ts';

// Data — pure logic, no @kit dependencies
import LruCacheTest from '../entry/src/ohosTest/ets/test/data/LruCache.test.ts';
import ApiConfigTest from '../entry/src/ohosTest/ets/test/data/ApiConfig.test.ts';
import UserDtoTest from '../entry/src/ohosTest/ets/test/data/UserDto.test.ts';

// Register all tests
AppErrorTest();
ResultTest();
UserTest();
EmailValidatorTest();
NameValidatorTest();
UserValidatorTest();

LruCacheTest();
ApiConfigTest();
UserDtoTest();
