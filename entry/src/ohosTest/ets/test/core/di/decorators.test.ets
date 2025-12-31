/**
 * Unit Tests for DI Decorators
 * Tests injectable, inject, injectProperty, postConstruct, preDestroy decorators
 */

import { describe, it, expect, beforeEach, afterEach } from '@ohos/hypium';
import {
  injectable,
  inject,
  injectProperty,
  named,
  optional,
  multiInject,
  postConstruct,
  preDestroy,
  getInjectableMetadata,
  getPropertyInjections,
  isOptionalParam,
  getMultiInjectIdentifier,
  getPostConstructMethod,
  getPreDestroyMethod,
  clearAllMetadata
} from '../../../../../main/ets/core/di/decorators';

export default function DecoratorsTest() {
  describe('injectable decorator', () => {
    beforeEach(() => {
      clearAllMetadata();
    });

    afterEach(() => {
      clearAllMetadata();
    });

    it('should mark class as injectable', () => {
      @injectable()
      class TestService {}

      const metadata = getInjectableMetadata(TestService);
      expect(metadata).assertNotNull();
    });

    it('should initialize empty dependencies', () => {
      @injectable()
      class TestService {}

      const metadata = getInjectableMetadata(TestService);
      expect(metadata?.dependencies).assertNotNull();
      expect(metadata?.dependencies.length).assertEqual(0);
    });

    it('should return the same class', () => {
      @injectable()
      class TestService {
        getValue(): number {
          return 42;
        }
      }

      const instance = new TestService();
      expect(instance.getValue()).assertEqual(42);
    });
  });

  describe('inject decorator', () => {
    beforeEach(() => {
      clearAllMetadata();
    });

    afterEach(() => {
      clearAllMetadata();
    });

    it('should register dependency at correct index', () => {
      @injectable()
      class TestService {
        constructor(@inject('LOGGER') logger: Object) {}
      }

      const metadata = getInjectableMetadata(TestService);
      expect(metadata?.dependencies[0]).assertEqual('LOGGER');
    });

    it('should handle multiple dependencies', () => {
      @injectable()
      class TestService {
        constructor(
          @inject('DEP_A') depA: Object,
          @inject('DEP_B') depB: Object
        ) {}
      }

      const metadata = getInjectableMetadata(TestService);
      expect(metadata?.dependencies[0]).assertEqual('DEP_A');
      expect(metadata?.dependencies[1]).assertEqual('DEP_B');
    });

    it('should track parameter indices', () => {
      @injectable()
      class TestService {
        constructor(
          @inject('DEP') dep: Object
        ) {}
      }

      const metadata = getInjectableMetadata(TestService);
      expect(metadata?.parameterIndices).assertNotNull();
      expect(metadata?.parameterIndices.includes(0)).assertTrue();
    });
  });

  describe('injectProperty decorator', () => {
    beforeEach(() => {
      clearAllMetadata();
    });

    afterEach(() => {
      clearAllMetadata();
    });

    it('should register property injection', () => {
      @injectable()
      class TestService {
        @injectProperty('LOGGER')
        private logger!: Object;
      }

      const injections = getPropertyInjections(TestService);
      expect(injections.length).assertEqual(1);
      expect(injections[0].identifier).assertEqual('LOGGER');
      expect(injections[0].propertyKey).assertEqual('logger');
    });

    it('should handle multiple property injections', () => {
      @injectable()
      class TestService {
        @injectProperty('DEP_A')
        private depA!: Object;

        @injectProperty('DEP_B')
        private depB!: Object;
      }

      const injections = getPropertyInjections(TestService);
      expect(injections.length).assertEqual(2);
    });
  });

  describe('optional decorator', () => {
    beforeEach(() => {
      clearAllMetadata();
    });

    afterEach(() => {
      clearAllMetadata();
    });

    it('should mark parameter as optional', () => {
      @injectable()
      class TestService {
        constructor(@inject('OPT') @optional() opt?: Object) {}
      }

      expect(isOptionalParam(TestService, 0)).assertTrue();
    });

    it('should not mark non-optional as optional', () => {
      @injectable()
      class TestService {
        constructor(@inject('REQ') req: Object) {}
      }

      expect(isOptionalParam(TestService, 0)).assertFalse();
    });
  });

  describe('multiInject decorator', () => {
    beforeEach(() => {
      clearAllMetadata();
    });

    afterEach(() => {
      clearAllMetadata();
    });

    it('should register multi-inject identifier', () => {
      @injectable()
      class TestService {
        constructor(@multiInject('PLUGINS') plugins: Object[]) {}
      }

      const identifier = getMultiInjectIdentifier(TestService, 0);
      expect(identifier).assertEqual('PLUGINS');
    });

    it('should return undefined for non-multi-inject', () => {
      @injectable()
      class TestService {
        constructor(@inject('DEP') dep: Object) {}
      }

      const identifier = getMultiInjectIdentifier(TestService, 0);
      expect(identifier).assertUndefined();
    });
  });

  describe('postConstruct decorator', () => {
    beforeEach(() => {
      clearAllMetadata();
    });

    afterEach(() => {
      clearAllMetadata();
    });

    it('should register post-construct method', () => {
      @injectable()
      class TestService {
        @postConstruct()
        initialize(): void {}
      }

      const methodName = getPostConstructMethod(TestService);
      expect(methodName).assertEqual('initialize');
    });

    it('should return undefined when not set', () => {
      @injectable()
      class TestService {}

      const methodName = getPostConstructMethod(TestService);
      expect(methodName).assertUndefined();
    });
  });

  describe('preDestroy decorator', () => {
    beforeEach(() => {
      clearAllMetadata();
    });

    afterEach(() => {
      clearAllMetadata();
    });

    it('should register pre-destroy method', () => {
      @injectable()
      class TestService {
        @preDestroy()
        cleanup(): void {}
      }

      const methodName = getPreDestroyMethod(TestService);
      expect(methodName).assertEqual('cleanup');
    });

    it('should return undefined when not set', () => {
      @injectable()
      class TestService {}

      const methodName = getPreDestroyMethod(TestService);
      expect(methodName).assertUndefined();
    });
  });

  describe('clearAllMetadata', () => {
    it('should clear all registries', () => {
      @injectable()
      class TestService {
        @injectProperty('DEP')
        dep!: Object;

        @postConstruct()
        init(): void {}

        @preDestroy()
        cleanup(): void {}
      }

      clearAllMetadata();

      expect(getInjectableMetadata(TestService)).assertUndefined();
      expect(getPropertyInjections(TestService).length).assertEqual(0);
      expect(getPostConstructMethod(TestService)).assertUndefined();
      expect(getPreDestroyMethod(TestService)).assertUndefined();
    });
  });

  describe('named decorator', () => {
    it('should be usable as marker decorator', () => {
      @injectable()
      class TestService {
        constructor(
          @inject('LOGGER') @named('file') logger: Object
        ) {}
      }

      // named is a marker decorator, just verify no errors
      expect(true).assertTrue();
    });
  });
}
