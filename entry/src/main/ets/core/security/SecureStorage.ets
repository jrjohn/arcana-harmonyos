/**
 * Secure Storage using HarmonyOS HUKS (Hardware Universal Key Store)
 * Provides encryption at rest for sensitive data
 */

import { huks } from '@kit.UniversalKeystoreKit';
import { util } from '@kit.ArkTS';
import { injectable, postConstruct, preDestroy } from '../di/decorators';
import { ILogger } from '../di/interfaces';

const TAG = 'SecureStorage';

/**
 * HUKS key properties for AES encryption
 */
const AES_KEY_PROPERTIES: huks.HuksOptions = {
  properties: [
    { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
    { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT | huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT },
    { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
    { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
    { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE }
  ]
};

/**
 * Encryption options for AES-GCM
 */
function getEncryptOptions(iv: Uint8Array): huks.HuksOptions {
  return {
    properties: [
      { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
      { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT },
      { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
      { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
      { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
      { tag: huks.HuksTag.HUKS_TAG_NONCE, value: iv },
      { tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: stringToUint8Array('arcana_aad') }
    ]
  };
}

/**
 * Decryption options for AES-GCM
 */
function getDecryptOptions(iv: Uint8Array): huks.HuksOptions {
  return {
    properties: [
      { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
      { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT },
      { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
      { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
      { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
      { tag: huks.HuksTag.HUKS_TAG_NONCE, value: iv },
      { tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: stringToUint8Array('arcana_aad') }
    ]
  };
}

/**
 * Secure storage interface
 */
export interface ISecureStorage {
  /** Initialize the secure storage */
  initialize(): Promise<void>;

  /** Encrypt and store a value */
  setSecure(key: string, value: string): Promise<void>;

  /** Retrieve and decrypt a value */
  getSecure(key: string): Promise<string | undefined>;

  /** Remove a secure value */
  removeSecure(key: string): Promise<void>;

  /** Check if a key exists */
  hasSecure(key: string): Promise<boolean>;

  /** Clear all secure storage */
  clearAll(): Promise<void>;
}

/**
 * Encrypted data format stored in preferences
 */
interface EncryptedData {
  /** Initialization vector (base64) */
  iv: string;
  /** Encrypted data (base64) */
  data: string;
  /** GCM authentication tag (base64) */
  tag: string;
}

/**
 * Secure Storage implementation using HUKS
 */
@injectable()
export class SecureStorage implements ISecureStorage {
  private static readonly KEY_ALIAS = 'arcana_master_key';
  private static readonly IV_LENGTH = 12; // GCM recommended IV length
  private static readonly TAG_LENGTH = 16; // GCM tag length

  private logger?: ILogger;
  private initialized = false;
  private storage = new Map<string, EncryptedData>();

  constructor() {}

  setLogger(logger: ILogger): void {
    this.logger = logger;
  }

  @postConstruct()
  async onPostConstruct(): Promise<void> {
    // Initialization will be called separately
  }

  async initialize(): Promise<void> {
    if (this.initialized) return;

    try {
      // Check if master key exists
      const keyExists = await this.isKeyExists();

      if (!keyExists) {
        // Generate master key
        await this.generateMasterKey();
        this.log('Master key generated');
      } else {
        this.log('Master key already exists');
      }

      this.initialized = true;
      this.log('SecureStorage initialized');
    } catch (error) {
      this.logError(`Failed to initialize: ${error}`);
      throw error;
    }
  }

  async setSecure(key: string, value: string): Promise<void> {
    this.ensureInitialized();

    try {
      // Generate random IV
      const iv = this.generateIV();

      // Encrypt the value
      const encrypted = await this.encrypt(value, iv);

      // Store encrypted data
      this.storage.set(key, {
        iv: uint8ArrayToBase64(iv),
        data: uint8ArrayToBase64(encrypted.ciphertext),
        tag: uint8ArrayToBase64(encrypted.tag)
      });

      this.log(`Stored encrypted value for key: ${key}`);
    } catch (error) {
      this.logError(`Failed to store secure value: ${error}`);
      throw error;
    }
  }

  async getSecure(key: string): Promise<string | undefined> {
    this.ensureInitialized();

    try {
      const encryptedData = this.storage.get(key);
      if (!encryptedData) {
        return undefined;
      }

      // Decode stored data
      const iv = base64ToUint8Array(encryptedData.iv);
      const ciphertext = base64ToUint8Array(encryptedData.data);
      const tag = base64ToUint8Array(encryptedData.tag);

      // Decrypt the value
      const decrypted = await this.decrypt(ciphertext, iv, tag);

      return uint8ArrayToString(decrypted);
    } catch (error) {
      this.logError(`Failed to retrieve secure value: ${error}`);
      return undefined;
    }
  }

  async removeSecure(key: string): Promise<void> {
    this.storage.delete(key);
    this.log(`Removed secure value for key: ${key}`);
  }

  async hasSecure(key: string): Promise<boolean> {
    return this.storage.has(key);
  }

  async clearAll(): Promise<void> {
    this.storage.clear();
    this.log('Cleared all secure storage');
  }

  @preDestroy()
  destroy(): void {
    this.storage.clear();
    this.initialized = false;
  }

  // ===== Private Methods =====

  private async isKeyExists(): Promise<boolean> {
    try {
      await huks.isKeyItemExist(SecureStorage.KEY_ALIAS, AES_KEY_PROPERTIES);
      return true;
    } catch {
      return false;
    }
  }

  private async generateMasterKey(): Promise<void> {
    const options: huks.HuksOptions = {
      properties: [
        ...AES_KEY_PROPERTIES.properties!,
        { tag: huks.HuksTag.HUKS_TAG_KEY_GENERATE_TYPE, value: huks.HuksKeyGenerateType.HUKS_KEY_GENERATE_TYPE_DEFAULT }
      ]
    };

    await huks.generateKeyItem(SecureStorage.KEY_ALIAS, options);
  }

  private async encrypt(plaintext: string, iv: Uint8Array): Promise<{ ciphertext: Uint8Array; tag: Uint8Array }> {
    const plaintextBytes = stringToUint8Array(plaintext);
    const options = getEncryptOptions(iv);
    options.inData = plaintextBytes;

    // Init session
    const initResult = await huks.initSession(SecureStorage.KEY_ALIAS, options);
    const handle = initResult.handle!;

    try {
      // Finish encryption
      const finishOptions: huks.HuksOptions = {
        properties: options.properties,
        inData: plaintextBytes
      };

      const result = await huks.finishSession(handle, finishOptions);
      const outputData = result.outData!;

      // GCM appends tag to ciphertext
      const tagStart = outputData.length - SecureStorage.TAG_LENGTH;
      const ciphertext = outputData.slice(0, tagStart);
      const tag = outputData.slice(tagStart);

      return { ciphertext, tag };
    } catch (error) {
      await huks.abortSession(handle, options);
      throw error;
    }
  }

  private async decrypt(ciphertext: Uint8Array, iv: Uint8Array, tag: Uint8Array): Promise<Uint8Array> {
    // Combine ciphertext and tag for GCM
    const combined = new Uint8Array(ciphertext.length + tag.length);
    combined.set(ciphertext, 0);
    combined.set(tag, ciphertext.length);

    const options = getDecryptOptions(iv);
    options.inData = combined;

    // Init session
    const initResult = await huks.initSession(SecureStorage.KEY_ALIAS, options);
    const handle = initResult.handle!;

    try {
      // Finish decryption
      const finishOptions: huks.HuksOptions = {
        properties: options.properties,
        inData: combined
      };

      const result = await huks.finishSession(handle, finishOptions);
      return result.outData!;
    } catch (error) {
      await huks.abortSession(handle, options);
      throw error;
    }
  }

  private generateIV(): Uint8Array {
    const iv = new Uint8Array(SecureStorage.IV_LENGTH);
    for (let i = 0; i < iv.length; i++) {
      iv[i] = Math.floor(Math.random() * 256);
    }
    return iv;
  }

  private ensureInitialized(): void {
    if (!this.initialized) {
      throw new Error('SecureStorage not initialized. Call initialize() first.');
    }
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

// ===== Utility Functions =====

function stringToUint8Array(str: string): Uint8Array {
  const encoder = new util.TextEncoder();
  return encoder.encodeInto(str);
}

function uint8ArrayToString(arr: Uint8Array): string {
  const decoder = new util.TextDecoder();
  return decoder.decodeToString(arr);
}

function uint8ArrayToBase64(arr: Uint8Array): string {
  const base64Helper = new util.Base64Helper();
  return base64Helper.encodeToStringSync(arr);
}

function base64ToUint8Array(str: string): Uint8Array {
  const base64Helper = new util.Base64Helper();
  return base64Helper.decodeSync(str);
}
