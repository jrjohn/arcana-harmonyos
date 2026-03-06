/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: 'node',

  // Standard extensions (.ets files are pre-copied to .ts before test run)
  moduleFileExtensions: ['ts', 'tsx', 'js', 'jsx', 'json'],

  // ts-jest handles .ts files (which are .ets copies made before test run)
  transform: {
    '\\.ts$': ['ts-jest', {
      tsconfig: 'tsconfig.jest.json',
      diagnostics: false,
    }],
  },

  // Map HarmonyOS-specific modules to shims/mocks
  moduleNameMapper: {
    '^@ohos/hypium$': '<rootDir>/scripts/hypium-jest-shim.js',
    // @kit.AbilityKit, @kit.ArkData, etc.
    '^@kit\\.\\w+$': '<rootDir>/scripts/kit-mock.js',
  },

  // Test files: our single aggregator
  testMatch: ['<rootDir>/jest-tests/**/*.test.ts'],

  // Coverage: V8 (no Babel instrumentation needed)
  // Scope to domain + pure-TS layers (no @kit dependencies → always compiles cleanly)
  coverageProvider: 'v8',
  collectCoverage: true,
  collectCoverageFrom: [
    // Domain layer — pure TypeScript, 100% @kit-free
    'entry/src/main/ets/domain/**/*.ts',
    '!entry/src/main/ets/domain/repository/impl/UserRepositoryImpl.ts',  // has @kit.AbilityKit
    // Data cache — LruCache only (ObservableCache is untested, excluded)
    'entry/src/main/ets/data/cache/LruCache.ts',
    'entry/src/main/ets/data/api/ApiConfig.ts',
    'entry/src/main/ets/data/api/dto/UserDto.ts',
    'entry/src/main/ets/data/api/UserApiDeclarative.ts',
  ],
  coverageReporters: ['lcov', 'text-summary'],
  coverageDirectory: 'coverage/jest',
};
