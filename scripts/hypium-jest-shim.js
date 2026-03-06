/**
 * @ohos/hypium → Jest shim
 * Maps ArkTS hypium test assertions to Jest equivalents.
 */
'use strict';

const jestGlobals = require('@jest/globals');

/**
 * Wraps a value in a hypium-compatible assertion object that delegates to Jest.
 */
function expect(value) {
  const jResult = jestGlobals.expect(value);

  return {
    // Hypium-style assertions
    assertTrue() {
      jResult.toBe(true);
    },
    assertFalse() {
      jResult.toBe(false);
    },
    assertEqual(expected) {
      jResult.toBe(expected);
    },
    assertUndefined() {
      jResult.toBeUndefined();
    },
    assertNull() {
      jResult.toBeNull();
    },
    assertNotNull() {
      jResult.not.toBeNull();
    },
    assertNotUndefined() {
      jResult.not.toBeUndefined();
    },
    assertLarger(other) {
      jResult.toBeGreaterThan(other);
    },
    assertLargerOrEqual(other) {
      jResult.toBeGreaterThanOrEqual(other);
    },
    assertLess(other) {
      jResult.toBeLessThan(other);
    },
    assertLessOrEqual(other) {
      jResult.toBeLessThanOrEqual(other);
    },
    assertContain(item) {
      jResult.toContain(item);
    },
    assertInstanceOf(type) {
      jResult.toBeInstanceOf(type);
    },
    assertDeepEquals(expected) {
      jResult.toEqual(expected);
    },
    assertStrictEquals(expected) {
      jResult.toBe(expected);
    },
    assertStringContains(substr) {
      jResult.toContain(substr);
    },
    assertPromiseIsRejected() {
      return jResult.rejects;
    },
    assertPromiseIsRejectedWithError(...args) {
      return jResult.rejects.toThrow(...args);
    },
    // Also support Jest-style chaining (some tests use both)
    toBe: jResult.toBe.bind(jResult),
    toEqual: jResult.toEqual.bind(jResult),
    toBeNull: jResult.toBeNull.bind(jResult),
    toBeUndefined: jResult.toBeUndefined.bind(jResult),
    toBeTruthy: jResult.toBeTruthy.bind(jResult),
    toBeFalsy: jResult.toBeFalsy.bind(jResult),
    toContain: jResult.toContain.bind(jResult),
    toBeGreaterThan: jResult.toBeGreaterThan.bind(jResult),
    toBeGreaterThanOrEqual: jResult.toBeGreaterThanOrEqual.bind(jResult),
    toBeLessThan: jResult.toBeLessThan.bind(jResult),
    toHaveLength: jResult.toHaveLength.bind(jResult),
    toBeInstanceOf: jResult.toBeInstanceOf.bind(jResult),
    toThrow: jResult.toThrow.bind(jResult),
    not: jResult.not,
    resolves: jResult.resolves,
    rejects: jResult.rejects,
  };
}

module.exports = {
  describe: jestGlobals.describe,
  it: jestGlobals.it,
  test: jestGlobals.test,
  expect,
  beforeAll: jestGlobals.beforeAll,
  afterAll: jestGlobals.afterAll,
  beforeEach: jestGlobals.beforeEach,
  afterEach: jestGlobals.afterEach,
};
