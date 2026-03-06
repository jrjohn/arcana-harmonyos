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
  // Note: collectCoverageFrom targets .ts copies of .ets; lcov is sed-patched back to .ets
  coverageProvider: 'v8',
  collectCoverage: true,
  collectCoverageFrom: [
    'entry/src/main/ets/**/*.ts',
    '!entry/src/main/ets/pages/**',
    '!entry/src/main/ets/entryability/**',
    '!entry/src/main/ets/presentation/components/**',
    '!entry/src/main/ets/workers/**',
  ],
  coverageReporters: ['lcov', 'text-summary'],
  coverageDirectory: 'coverage/jest',
};
