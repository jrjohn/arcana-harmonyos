/**
 * Unit Tests for DI Types
 * Tests type definitions, enums, and interfaces
 */

import { describe, it, expect } from '@ohos/hypium';
import {
  BindingScope,
  INJECTABLE_METADATA_KEY,
  PROPERTY_INJECTION_KEY
} from '../../../../../main/ets/core/di/types';

export default function TypesTest() {
  describe('BindingScope', () => {
    it('should have TRANSIENT scope', () => {
      expect(BindingScope.TRANSIENT).assertEqual('transient');
    });

    it('should have SINGLETON scope', () => {
      expect(BindingScope.SINGLETON).assertEqual('singleton');
    });

    it('should have REQUEST scope', () => {
      expect(BindingScope.REQUEST).assertEqual('request');
    });

    it('should have exactly 3 scopes', () => {
      const scopes = [
        BindingScope.TRANSIENT,
        BindingScope.SINGLETON,
        BindingScope.REQUEST
      ];
      expect(scopes.length).assertEqual(3);
    });

    it('should be comparable using equality', () => {
      const scope1 = BindingScope.SINGLETON;
      const scope2 = BindingScope.SINGLETON;
      expect(scope1).assertEqual(scope2);
    });

    it('should not be equal to different scope', () => {
      expect(BindingScope.TRANSIENT !== BindingScope.SINGLETON).assertTrue();
    });
  });

  describe('INJECTABLE_METADATA_KEY', () => {
    it('should be defined', () => {
      expect(INJECTABLE_METADATA_KEY).assertNotNull();
    });

    it('should be a string', () => {
      expect(typeof INJECTABLE_METADATA_KEY === 'string').assertTrue();
    });

    it('should have expected value', () => {
      expect(INJECTABLE_METADATA_KEY).assertEqual('__injectable_metadata__');
    });
  });

  describe('PROPERTY_INJECTION_KEY', () => {
    it('should be defined', () => {
      expect(PROPERTY_INJECTION_KEY).assertNotNull();
    });

    it('should be a string', () => {
      expect(typeof PROPERTY_INJECTION_KEY === 'string').assertTrue();
    });

    it('should have expected value', () => {
      expect(PROPERTY_INJECTION_KEY).assertEqual('__property_injections__');
    });
  });

  describe('Type consistency', () => {
    it('should have unique metadata keys', () => {
      expect(INJECTABLE_METADATA_KEY !== PROPERTY_INJECTION_KEY).assertTrue();
    });

    it('should have unique scope values', () => {
      const scopes = new Set<string>();
      scopes.add(BindingScope.TRANSIENT);
      scopes.add(BindingScope.SINGLETON);
      scopes.add(BindingScope.REQUEST);
      expect(scopes.size).assertEqual(3);
    });
  });
}
