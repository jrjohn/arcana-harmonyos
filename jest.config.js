/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: 'node',

  // Recognize .ets as a loadable extension
  moduleFileExtensions: ['ets', 'ts', 'tsx', 'js', 'jsx', 'json'],

  // Transform .ets with our custom transformer (uses ts.transpileModule directly)
  // Transform .ts with ts-jest
  transform: {
    '\\.ets$': '<rootDir>/scripts/ets-transformer.js',
    '\\.ts$': ['ts-jest', {
      tsconfig: 'tsconfig.jest.json',
      diagnostics: false,
      isolatedModules: true,
    }],
  },

  // Ensure all files (including .ets) are transformed — do not ignore any project files
  transformIgnorePatterns: ['<rootDir>/node_modules/'],

  // Map HarmonyOS-specific modules to shims/mocks
  moduleNameMapper: {
    '^@ohos/hypium$': '<rootDir>/scripts/hypium-jest-shim.js',
    // @kit.AbilityKit, @kit.ArkData, etc.
    '^@kit\\.\\w+$': '<rootDir>/scripts/kit-mock.js',
  },

  // Test files: our single aggregator
  testMatch: ['<rootDir>/jest-tests/**/*.test.ts'],

  // Coverage: use V8 (no Babel instrumentation → no ArkTS syntax errors)
  coverageProvider: 'v8',
  collectCoverage: true,
  collectCoverageFrom: [
    'entry/src/main/ets/**/*.ets',
    // Exclude UI-only files (ArkUI decorators, pages, components)
    '!entry/src/main/ets/pages/**',
    '!entry/src/main/ets/entryability/**',
    '!entry/src/main/ets/presentation/components/**',
    '!entry/src/main/ets/workers/**',
  ],
  coverageReporters: ['lcov', 'text-summary'],
  coverageDirectory: 'coverage/jest',
};
