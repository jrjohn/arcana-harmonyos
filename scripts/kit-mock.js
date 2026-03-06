/**
 * Generic HarmonyOS @kit.* module mock.
 * Returns a Proxy that provides callable no-op implementations for any depth of access.
 * All property accesses return Proxies that are both callable AND have further properties.
 */
'use strict';

const SKIP_PROPS = new Set([
  '__esModule', 'then', 'catch', 'finally',
  Symbol.iterator, Symbol.toPrimitive, Symbol.toStringTag,
]);

/**
 * Creates a deeply callable Proxy mock.
 * Every property access returns another such mock.
 * Every call invocation returns another such mock.
 */
function createMock() {
  // Use a function as the proxy target so the proxy is always callable
  const fn = function mockKitFn() {
    return createMock();
  };

  return new Proxy(fn, {
    get(_target, prop) {
      if (SKIP_PROPS.has(prop)) return undefined;
      if (prop === '__esModule') return true;
      if (prop === 'default') return createMock();
      // Return a callable mock for any property
      return createMock();
    },
    apply(_target, _thisArg, _args) {
      return createMock();
    },
    construct(_target, _args) {
      return createMock();
    },
    set() { return true; },
    has() { return true; },
  });
}

module.exports = createMock();
