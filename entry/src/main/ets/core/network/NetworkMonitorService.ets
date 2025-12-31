/**
 * Injectable Network Monitor Service
 * Implements INetworkMonitor interface for DI container
 */

import { connection } from '@kit.NetworkKit';
import { injectable, inject, postConstruct, preDestroy } from '../di/decorators';
import { INetworkMonitor, ILogger } from '../di/interfaces';
import { TYPES } from '../di/tokens';
import { NetworkStatus, NetworkType, NetworkState, NetworkStateCallback } from './NetworkMonitor';

const TAG = 'NetworkMonitorService';

/**
 * Injectable network monitor service implementation
 */
@injectable()
export class NetworkMonitorService implements INetworkMonitor {
  private callbacks: Set<NetworkStateCallback> = new Set();
  private currentState: NetworkState = {
    status: NetworkStatus.UNKNOWN,
    type: NetworkType.UNKNOWN,
    isMetered: false
  };
  private netConnection: connection.NetConnection | null = null;
  private initialized: boolean = false;
  private logger?: ILogger;

  constructor() {
    // Logger will be injected via property or set manually
  }

  /**
   * Sets the logger (for manual injection when decorator not available)
   */
  setLogger(logger: ILogger): void {
    this.logger = logger;
  }

  @postConstruct()
  async onPostConstruct(): Promise<void> {
    // Initialize will be called separately
  }

  async initialize(): Promise<void> {
    if (this.initialized) return;

    try {
      // Get initial state
      await this.updateNetworkState();

      // Register for network changes
      this.netConnection = connection.createNetConnection();

      this.netConnection.on('netAvailable', () => {
        this.log('Network available');
        this.updateAndNotify(NetworkStatus.AVAILABLE);
      });

      this.netConnection.on('netUnavailable', () => {
        this.log('Network unavailable');
        this.updateAndNotify(NetworkStatus.UNAVAILABLE);
      });

      this.netConnection.on('netLost', () => {
        this.log('Network lost');
        this.updateAndNotify(NetworkStatus.UNAVAILABLE);
      });

      this.netConnection.register((err) => {
        if (err) {
          this.logError(`Failed to register network callback: ${JSON.stringify(err)}`);
          return;
        }
        this.log('Network callback registered');
      });

      this.initialized = true;
      this.log('NetworkMonitorService initialized');
    } catch (error) {
      this.logError(`Failed to initialize: ${error}`);
    }
  }

  async isNetworkAvailable(): Promise<boolean> {
    try {
      const hasNet = await connection.hasDefaultNet();
      return hasNet;
    } catch (error) {
      this.logError(`Error checking network availability: ${error}`);
      return false;
    }
  }

  async getNetworkState(): Promise<NetworkState> {
    await this.updateNetworkState();
    return { ...this.currentState };
  }

  subscribe(callback: NetworkStateCallback): () => void {
    this.callbacks.add(callback);

    // Immediately call with current state
    callback({ ...this.currentState });

    // Return unsubscribe function
    return () => {
      this.callbacks.delete(callback);
    };
  }

  @preDestroy()
  destroy(): void {
    if (this.netConnection) {
      this.netConnection.unregister();
      this.netConnection = null;
    }
    this.callbacks.clear();
    this.initialized = false;
    this.log('NetworkMonitorService destroyed');
  }

  private async updateNetworkState(): Promise<void> {
    try {
      const hasNet = await connection.hasDefaultNet();

      if (hasNet) {
        const netHandle = await connection.getDefaultNet();
        const netCapabilities = await connection.getNetCapabilities(netHandle);

        this.currentState = {
          status: NetworkStatus.AVAILABLE,
          type: this.getNetworkType(netCapabilities),
          isMetered: !netCapabilities.networkCap?.includes(connection.NetCap.NET_CAPABILITY_NOT_METERED)
        };
      } else {
        this.currentState = {
          status: NetworkStatus.UNAVAILABLE,
          type: NetworkType.NONE,
          isMetered: false
        };
      }
    } catch (error) {
      this.logError(`Error updating network state: ${error}`);
      this.currentState = {
        status: NetworkStatus.UNKNOWN,
        type: NetworkType.UNKNOWN,
        isMetered: false
      };
    }
  }

  private updateAndNotify(status: NetworkStatus): void {
    this.currentState.status = status;

    if (status === NetworkStatus.UNAVAILABLE) {
      this.currentState.type = NetworkType.NONE;
    }

    this.notifySubscribers();
  }

  private notifySubscribers(): void {
    const state = { ...this.currentState };
    this.callbacks.forEach(callback => {
      try {
        callback(state);
      } catch (error) {
        this.logError(`Error in network callback: ${error}`);
      }
    });
  }

  private getNetworkType(capabilities: connection.NetCapabilities): NetworkType {
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

  private log(message: string): void {
    if (this.logger) {
      this.logger.d(TAG, message);
    }
  }

  private logError(message: string): void {
    if (this.logger) {
      this.logger.e(TAG, message);
    }
  }
}
