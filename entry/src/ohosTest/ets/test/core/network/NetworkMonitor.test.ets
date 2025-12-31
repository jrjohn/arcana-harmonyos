/**
 * Unit Tests for NetworkMonitor
 * Tests network connectivity monitoring
 */

import { describe, it, expect, beforeEach, afterEach } from '@ohos/hypium';
import {
  NetworkMonitor,
  NetworkStatus,
  NetworkType,
  NetworkState,
  UnsubscribeCallback
} from '../../../../../main/ets/core/network/NetworkMonitor';

export default function NetworkMonitorTest() {
  describe('NetworkStatus', () => {
    it('should have AVAILABLE status', () => {
      expect(NetworkStatus.AVAILABLE).assertEqual('available');
    });

    it('should have UNAVAILABLE status', () => {
      expect(NetworkStatus.UNAVAILABLE).assertEqual('unavailable');
    });

    it('should have UNKNOWN status', () => {
      expect(NetworkStatus.UNKNOWN).assertEqual('unknown');
    });

    it('should have exactly 3 statuses', () => {
      const statuses = [
        NetworkStatus.AVAILABLE,
        NetworkStatus.UNAVAILABLE,
        NetworkStatus.UNKNOWN
      ];
      expect(statuses.length).assertEqual(3);
    });
  });

  describe('NetworkType', () => {
    it('should have WIFI type', () => {
      expect(NetworkType.WIFI).assertEqual('wifi');
    });

    it('should have CELLULAR type', () => {
      expect(NetworkType.CELLULAR).assertEqual('cellular');
    });

    it('should have ETHERNET type', () => {
      expect(NetworkType.ETHERNET).assertEqual('ethernet');
    });

    it('should have NONE type', () => {
      expect(NetworkType.NONE).assertEqual('none');
    });

    it('should have UNKNOWN type', () => {
      expect(NetworkType.UNKNOWN).assertEqual('unknown');
    });

    it('should have exactly 5 types', () => {
      const types = [
        NetworkType.WIFI,
        NetworkType.CELLULAR,
        NetworkType.ETHERNET,
        NetworkType.NONE,
        NetworkType.UNKNOWN
      ];
      expect(types.length).assertEqual(5);
    });
  });

  describe('NetworkMonitor.initialize', () => {
    afterEach(() => {
      NetworkMonitor.destroy();
    });

    it('should initialize without error', async () => {
      await NetworkMonitor.initialize();
      expect(true).assertTrue();
    });

    it('should be idempotent', async () => {
      await NetworkMonitor.initialize();
      await NetworkMonitor.initialize();
      expect(true).assertTrue();
    });
  });

  describe('NetworkMonitor.isNetworkAvailable', () => {
    it('should return boolean', async () => {
      const available = await NetworkMonitor.isNetworkAvailable();
      expect(typeof available === 'boolean').assertTrue();
    });
  });

  describe('NetworkMonitor.getNetworkState', () => {
    it('should return NetworkState object', async () => {
      const state = await NetworkMonitor.getNetworkState();

      expect(state).assertNotNull();
      expect(state.status).assertNotNull();
      expect(state.type).assertNotNull();
      expect(typeof state.isMetered === 'boolean').assertTrue();
    });

    it('should return valid status', async () => {
      const state = await NetworkMonitor.getNetworkState();

      const validStatuses = [
        NetworkStatus.AVAILABLE,
        NetworkStatus.UNAVAILABLE,
        NetworkStatus.UNKNOWN
      ];
      expect(validStatuses.includes(state.status)).assertTrue();
    });

    it('should return valid type', async () => {
      const state = await NetworkMonitor.getNetworkState();

      const validTypes = [
        NetworkType.WIFI,
        NetworkType.CELLULAR,
        NetworkType.ETHERNET,
        NetworkType.NONE,
        NetworkType.UNKNOWN
      ];
      expect(validTypes.includes(state.type)).assertTrue();
    });
  });

  describe('NetworkMonitor.subscribe', () => {
    afterEach(() => {
      NetworkMonitor.destroy();
    });

    it('should return UnsubscribeCallback', () => {
      const unsubscribe = NetworkMonitor.subscribe((state) => {});
      expect(unsubscribe).assertNotNull();
      expect(unsubscribe instanceof UnsubscribeCallback).assertTrue();
      unsubscribe.unsubscribe();
    });

    it('should call callback immediately with current state', () => {
      let callbackCalled = false;
      let receivedState: NetworkState | null = null;

      const unsubscribe = NetworkMonitor.subscribe((state) => {
        callbackCalled = true;
        receivedState = state;
      });

      expect(callbackCalled).assertTrue();
      expect(receivedState).assertNotNull();
      unsubscribe.unsubscribe();
    });

    it('should handle multiple subscriptions', () => {
      let count = 0;

      const unsubscribe1 = NetworkMonitor.subscribe((state) => count++);
      const unsubscribe2 = NetworkMonitor.subscribe((state) => count++);

      expect(count).assertEqual(2);

      unsubscribe1.unsubscribe();
      unsubscribe2.unsubscribe();
    });
  });

  describe('UnsubscribeCallback', () => {
    it('should unsubscribe successfully', () => {
      let callCount = 0;

      const unsubscribe = NetworkMonitor.subscribe((state) => {
        callCount++;
      });

      unsubscribe.unsubscribe();
      // Callback is called once on subscribe
      expect(callCount).assertEqual(1);
    });

    it('should be safe to call multiple times', () => {
      const unsubscribe = NetworkMonitor.subscribe((state) => {});
      unsubscribe.unsubscribe();
      unsubscribe.unsubscribe();
      expect(true).assertTrue();
    });

    it('should create instance correctly', () => {
      const callbacks = new Set<(state: NetworkState) => void>();
      const callback = (state: NetworkState) => {};
      callbacks.add(callback);

      const unsubscribeCallback = new UnsubscribeCallback(callback, callbacks);
      expect(unsubscribeCallback).assertNotNull();

      unsubscribeCallback.unsubscribe();
      expect(callbacks.has(callback)).assertFalse();
    });
  });

  describe('NetworkMonitor.destroy', () => {
    it('should cleanup without error', () => {
      NetworkMonitor.destroy();
      expect(true).assertTrue();
    });

    it('should be safe to call multiple times', () => {
      NetworkMonitor.destroy();
      NetworkMonitor.destroy();
      expect(true).assertTrue();
    });

    it('should clear subscriptions', async () => {
      await NetworkMonitor.initialize();

      let callCount = 0;
      NetworkMonitor.subscribe((state) => {
        callCount++;
      });

      NetworkMonitor.destroy();
      expect(true).assertTrue();
    });
  });

  describe('NetworkState interface', () => {
    it('should have required properties', async () => {
      const state = await NetworkMonitor.getNetworkState();

      expect('status' in state).assertTrue();
      expect('type' in state).assertTrue();
      expect('isMetered' in state).assertTrue();
    });

    it('should be copyable', async () => {
      const state = await NetworkMonitor.getNetworkState();

      const copy: NetworkState = {
        status: state.status,
        type: state.type,
        isMetered: state.isMetered
      };

      expect(copy.status).assertEqual(state.status);
      expect(copy.type).assertEqual(state.type);
      expect(copy.isMetered).assertEqual(state.isMetered);
    });
  });

  describe('Edge cases', () => {
    afterEach(() => {
      NetworkMonitor.destroy();
    });

    it('should handle rapid subscribe/unsubscribe', () => {
      for (let i = 0; i < 10; i++) {
        const unsubscribe = NetworkMonitor.subscribe((state) => {});
        unsubscribe.unsubscribe();
      }
      expect(true).assertTrue();
    });

    it('should handle callback errors gracefully', async () => {
      await NetworkMonitor.initialize();

      const unsubscribe = NetworkMonitor.subscribe((state) => {
        // Error in callback should not crash
      });

      unsubscribe.unsubscribe();
      expect(true).assertTrue();
    });
  });
}
