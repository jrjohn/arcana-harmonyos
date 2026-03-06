/**
 * Custom Jest transformer for .ets (ArkTS) files.
 * Uses TypeScript's transpileModule to compile ArkTS as TypeScript (CommonJS output).
 * This bypasses ts-jest's extension detection issues and Babel's coverage instrumentation.
 */
'use strict';

const ts = require('typescript');

const COMPILER_OPTIONS = {
  module: ts.ModuleKind.CommonJS,
  target: ts.ScriptTarget.ES2020,
  experimentalDecorators: true,
  emitDecoratorMetadata: true,
  allowSyntheticDefaultImports: true,
  esModuleInterop: true,
  strict: false,
  skipLibCheck: true,
  noEmit: false,
};

module.exports = {
  process(sourceText, sourcePath) {
    // Treat .ets as .ts for TypeScript compiler
    const fakeFileName = sourcePath.replace(/\.ets$/, '.ts');
    const result = ts.transpileModule(sourceText, {
      compilerOptions: COMPILER_OPTIONS,
      fileName: fakeFileName,
      reportDiagnostics: false,
    });
    return { code: result.outputText };
  },

  getCacheKey(fileData, filePath, options) {
    // Simple cache key
    return require('crypto')
      .createHash('md5')
      .update(fileData)
      .update(filePath)
      .update(JSON.stringify(options?.configString ?? ''))
      .digest('hex');
  },
};
