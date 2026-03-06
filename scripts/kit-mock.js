/**
 * Generic HarmonyOS @kit.* module mock.
 * Returns a Proxy that provides no-op implementations for all accessed symbols.
 * This allows source files that import @kit.* to be loaded in Node.js/Jest.
 */
'use strict';

/**
 * Creates a deep Proxy that returns no-op functions for any access.
 */
function createMock(name) {
  return new Proxy(
    {},
    {
      get(_target, prop) {
        if (prop === '__esModule') return true;
        if (prop === 'default') return createMock(`${name}.default`);
        if (prop === Symbol.iterator) return undefined;
        if (prop === Symbol.toPrimitive) return undefined;
        if (prop === 'then') return undefined; // prevent thenable detection
        // Return a callable Proxy for everything else
        return new Proxy(function mockFn() {
          return createMock(`${name}.${String(prop)}.return`);
        }, {
          get(_fn, innerProp) {
            if (innerProp === '__esModule') return true;
            if (innerProp === 'then') return undefined;
            if (innerProp === Symbol.iterator) return undefined;
            return createMock(`${name}.${String(prop)}.${String(innerProp)}`);
          },
          construct(_fn, _args) {
            return createMock(`${name}.${String(prop)}.instance`);
          }
        });
      },
      set() { return true; },
      has() { return true; },
    }
  );
}

module.exports = createMock('@kit');
