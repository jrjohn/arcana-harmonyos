/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: 'node',

  // Recognize .ets as TypeScript
  moduleFileExtensions: ['ets', 'ts', 'tsx', 'js', 'jsx', 'json'],

  // Transform .ets and .ts via ts-jest (diagnostics: false = transpile-only, no type errors for .ets resolution)
  transform: {
    '^.+\\.(ets|ts)$': ['ts-jest', {
      tsconfig: 'tsconfig.jest.json',
      diagnostics: false,  // Skip TS type-checking; Jest resolver handles .ets via moduleFileExtensions
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

  // Coverage: collect from main source, exclude UI layers
  collectCoverage: true,
  collectCoverageFrom: [
    'entry/src/main/ets/**/*.ets',
    // Exclude UI-only files (ArkUI decorators, pages, components)
    '!entry/src/main/ets/pages/**',
    '!entry/src/main/ets/entryability/**',
    '!entry/src/main/ets/presentation/components/**',
    '!entry/src/main/ets/workers/**',
  ],
  coverageReporters: ['lcov', 'text-summary', 'text'],
  coverageDirectory: 'coverage/jest',
};
