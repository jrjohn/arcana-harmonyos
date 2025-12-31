import { connection } from '@kit.NetworkKit';
import { Logger } from '../logging/Logger';

const TAG = 'NetworkMonitor';

/**
 * Network connectivity status
 */
export enum NetworkStatus {
  AVAILABLE = 'available',
  UNAVAILABLE = 'unavailable',
  UNKNOWN = 'unknown'
}

/**
 * Network type
 */
export enum NetworkType {
  WIFI = 'wifi',
  CELLULAR = 'cellular',
  ETHERNET = 'ethernet',
  NONE = 'none',
  UNKNOWN = 'unknown'
}

/**
 * Network state information
 */
export interface NetworkState {
  status: NetworkStatus;
  type: NetworkType;
  isMetered: boolean;
}

/**
 * Network state change callback
 */
export type NetworkStateCallback = (state: NetworkState) => void;

/**
 * Unsubscribe callback class to avoid standalone this
 */
export class UnsubscribeCallback {
  private callback: NetworkStateCallback;
  private callbacks: Set<NetworkStateCallback>;

  constructor(callback: NetworkStateCallback, callbacks: Set<NetworkStateCallback>) {
    this.callback = callback;
    this.callbacks = callbacks;
  }

  unsubscribe(): void {
    this.callbacks.delete(this.callback);
  }
}

// Module-level state to avoid this in static methods
let networkCallbacks: Set<NetworkStateCallback> = new Set();
let networkCurrentState: NetworkState = {
  status: NetworkStatus.UNKNOWN,
  type: NetworkType.UNKNOWN,
  isMetered: false
};
let networkNetConnection: connection.NetConnection | null = null;
let networkInitialized: boolean = false;

/**
 * Monitors network connectivity status.
 * Provides methods to check current status and subscribe to changes.
 */
export class NetworkMonitor {

  /**
   * Initializes the network monitor
   */
  static async initialize(): Promise<void> {
    if (networkInitialized) return;

    try {
      // Get initial state
      await NetworkMonitor.updateNetworkState();

      // Register for network changes
      networkNetConnection = connection.createNetConnection();

      networkNetConnection.on('netAvailable', () => {
        Logger.d(TAG, 'Network available');
        NetworkMonitor.updateAndNotify(NetworkStatus.AVAILABLE);
      });

      networkNetConnection.on('netUnavailable', () => {
        Logger.d(TAG, 'Network unavailable');
        NetworkMonitor.updateAndNotify(NetworkStatus.UNAVAILABLE);
      });

      networkNetConnection.on('netLost', () => {
        Logger.d(TAG, 'Network lost');
        NetworkMonitor.updateAndNotify(NetworkStatus.UNAVAILABLE);
      });

      networkNetConnection.register((err) => {
        if (err) {
          Logger.e(TAG, `Failed to register network callback: ${JSON.stringify(err)}`);
          return;
        }
        Logger.d(TAG, 'Network callback registered');
      });

      networkInitialized = true;
      Logger.d(TAG, 'NetworkMonitor initialized');
    } catch (error) {
      Logger.e(TAG, `Failed to initialize NetworkMonitor: ${error}`);
    }
  }

  /**
   * Checks if network is currently available
   */
  static async isNetworkAvailable(): Promise<boolean> {
    try {
      const hasNet = await connection.hasDefaultNet();
      return hasNet;
    } catch (error) {
      Logger.e(TAG, `Error checking network availability: ${error}`);
      return false;
    }
  }

  /**
   * Gets current network state
   */
  static async getNetworkState(): Promise<NetworkState> {
    await NetworkMonitor.updateNetworkState();
    return NetworkMonitor.copyState(networkCurrentState);
  }

  /**
   * Subscribes to network state changes
   */
  static subscribe(callback: NetworkStateCallback): UnsubscribeCallback {
    networkCallbacks.add(callback);

    // Immediately call with current state
    callback(NetworkMonitor.copyState(networkCurrentState));

    // Return unsubscribe callback object
    const unsubscribe = new UnsubscribeCallback(callback, networkCallbacks);
    return unsubscribe;
  }

  /**
   * Creates a copy of the network state
   */
  private static copyState(state: NetworkState): NetworkState {
    const copy: NetworkState = {
      status: state.status,
      type: state.type,
      isMetered: state.isMetered
    };
    return copy;
  }

  /**
   * Updates the network state from system
   */
  private static async updateNetworkState(): Promise<void> {
    try {
      const hasNet = await connection.hasDefaultNet();

      if (hasNet) {
        const netHandle = await connection.getDefaultNet();
        const netCapabilities = await connection.getNetCapabilities(netHandle);

        networkCurrentState = {
          status: NetworkStatus.AVAILABLE,
          type: NetworkMonitor.getNetworkType(netCapabilities),
          isMetered: !netCapabilities.networkCap?.includes(connection.NetCap.NET_CAPABILITY_NOT_METERED)
        };
      } else {
        networkCurrentState = {
          status: NetworkStatus.UNAVAILABLE,
          type: NetworkType.NONE,
          isMetered: false
        };
      }
    } catch (error) {
      Logger.e(TAG, `Error updating network state: ${error}`);
      networkCurrentState = {
        status: NetworkStatus.UNKNOWN,
        type: NetworkType.UNKNOWN,
        isMetered: false
      };
    }
  }

  /**
   * Updates state and notifies subscribers
   */
  private static updateAndNotify(status: NetworkStatus): void {
    networkCurrentState.status = status;

    if (status === NetworkStatus.UNAVAILABLE) {
      networkCurrentState.type = NetworkType.NONE;
    }

    NetworkMonitor.notifySubscribers();
  }

  /**
   * Notifies all subscribers of state change
   */
  private static notifySubscribers(): void {
    const state = NetworkMonitor.copyState(networkCurrentState);
    networkCallbacks.forEach(callback => {
      try {
        callback(state);
      } catch (error) {
        Logger.e(TAG, `Error in network callback: ${error}`);
      }
    });
  }

  /**
   * Gets network type from capabilities
   */
  private static getNetworkType(capabilities: connection.NetCapabilities): NetworkType {
    const bearerTypes = capabilities.bearerTypes || [];

    if (bearerTypes.includes(connection.NetBearType.BEARER_WIFI)) {
      return NetworkType.WIFI;
    } else if (bearerTypes.includes(connection.NetBearType.BEARER_CELLULAR)) {
      return NetworkType.CELLULAR;
    } else if (bearerTypes.includes(connection.NetBearType.BEARER_ETHERNET)) {
      return NetworkType.ETHERNET;
    }

    return NetworkType.UNKNOWN;
  }

  /**
   * Cleanup resources
   */
  static destroy(): void {
    if (networkNetConnection) {
      networkNetConnection.unregister((err) => {
        if (err) {
          Logger.e(TAG, `Failed to unregister network callback: ${JSON.stringify(err)}`);
        }
      });
      networkNetConnection = null;
    }
    networkCallbacks.clear();
    networkInitialized = false;
    Logger.d(TAG, 'NetworkMonitor destroyed');
  }
}
