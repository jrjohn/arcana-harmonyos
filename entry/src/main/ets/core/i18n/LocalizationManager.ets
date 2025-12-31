/**
 * Localization Manager for HarmonyOS
 * Provides i18n support with resource-based translations
 */

import { i18n } from '@kit.LocalizationKit';
import { resourceManager } from '@kit.LocalizationKit';
import { common } from '@kit.AbilityKit';
import { injectable, postConstruct, preDestroy } from '../di/decorators';
import { ILogger } from '../di/interfaces';

const TAG = 'LocalizationManager';

/**
 * Supported locales
 */
export enum Locale {
  EN_US = 'en-US',
  ZH_CN = 'zh-CN',
  ZH_TW = 'zh-TW',
  JA_JP = 'ja-JP',
  KO_KR = 'ko-KR',
  DE_DE = 'de-DE',
  FR_FR = 'fr-FR',
  ES_ES = 'es-ES'
}

/**
 * Locale change callback
 */
export type LocaleChangeCallback = (locale: Locale) => void;

/**
 * Pluralization rules
 */
export enum PluralCategory {
  ZERO = 'zero',
  ONE = 'one',
  TWO = 'two',
  FEW = 'few',
  MANY = 'many',
  OTHER = 'other'
}

/**
 * Localization manager interface
 */
export interface ILocalizationManager {
  /** Initialize the manager */
  initialize(context: common.UIAbilityContext): Promise<void>;

  /** Get current locale */
  getCurrentLocale(): Locale;

  /** Set locale */
  setLocale(locale: Locale): Promise<void>;

  /** Get localized string by key */
  getString(key: string, ...args: (string | number)[]): string;

  /** Get plural string */
  getPlural(key: string, count: number, ...args: (string | number)[]): string;

  /** Get string array */
  getStringArray(key: string): string[];

  /** Check if key exists */
  hasString(key: string): boolean;

  /** Subscribe to locale changes */
  onLocaleChange(callback: LocaleChangeCallback): () => void;

  /** Get all supported locales */
  getSupportedLocales(): Locale[];

  /** Get display name for locale */
  getLocaleDisplayName(locale: Locale): string;

  /** Format number for current locale */
  formatNumber(value: number): string;

  /** Format currency for current locale */
  formatCurrency(value: number, currency?: string): string;

  /** Format date for current locale */
  formatDate(date: Date, options?: DateFormatOptions): string;

  /** Format relative time */
  formatRelativeTime(date: Date): string;
}

/**
 * Date format options
 */
export interface DateFormatOptions {
  dateStyle?: 'full' | 'long' | 'medium' | 'short';
  timeStyle?: 'full' | 'long' | 'medium' | 'short';
}

/**
 * String resource cache
 */
interface StringCache {
  strings: Map<string, string>;
  plurals: Map<string, Map<PluralCategory, string>>;
  arrays: Map<string, string[]>;
}

/**
 * Localization Manager implementation
 */
@injectable()
export class LocalizationManager implements ILocalizationManager {
  private logger?: ILogger;
  private context?: common.UIAbilityContext;
  private resourceMgr?: resourceManager.ResourceManager;
  private currentLocale: Locale = Locale.EN_US;
  private callbacks: Set<LocaleChangeCallback> = new Set();
  private cache: StringCache = {
    strings: new Map(),
    plurals: new Map(),
    arrays: new Map()
  };
  private initialized = false;

  // Fallback strings when resource not found
  private fallbackStrings = new Map<string, string>();

  constructor() {
    this.initializeFallbacks();
  }

  setLogger(logger: ILogger): void {
    this.logger = logger;
  }

  @postConstruct()
  async onPostConstruct(): Promise<void> {
    // Initialization requires context, will be called separately
  }

  async initialize(context: common.UIAbilityContext): Promise<void> {
    if (this.initialized) return;

    try {
      this.context = context;
      this.resourceMgr = context.resourceManager;

      // Get system locale
      const systemLocale = i18n.System.getSystemLocale();
      this.currentLocale = this.parseLocale(systemLocale);

      this.log(`Initialized with locale: ${this.currentLocale}`);
      this.initialized = true;
    } catch (error) {
      this.logError(`Failed to initialize: ${error}`);
      throw error;
    }
  }

  getCurrentLocale(): Locale {
    return this.currentLocale;
  }

  async setLocale(locale: Locale): Promise<void> {
    if (this.currentLocale === locale) return;

    const previousLocale = this.currentLocale;
    this.currentLocale = locale;

    // Clear cache for new locale
    this.clearCache();

    // Notify listeners
    this.notifyLocaleChange(locale);

    this.log(`Locale changed: ${previousLocale} -> ${locale}`);
  }

  getString(key: string, ...args: (string | number)[]): string {
    // Check cache first
    const cached = this.cache.strings.get(key);
    if (cached) {
      return this.formatString(cached, args);
    }

    try {
      if (this.resourceMgr) {
        // Try to get from resources
        const resourceId = this.getResourceId(key);
        if (resourceId !== -1) {
          const value = this.resourceMgr.getStringSync(resourceId);
          this.cache.strings.set(key, value);
          return this.formatString(value, args);
        }
      }
    } catch (error) {
      this.logError(`Failed to get string '${key}': ${error}`);
    }

    // Fallback
    const fallback = this.fallbackStrings.get(key) || key;
    return this.formatString(fallback, args);
  }

  getPlural(key: string, count: number, ...args: (string | number)[]): string {
    const category = this.getPluralCategory(count);

    // Check cache
    const cachedPlural = this.cache.plurals.get(key);
    if (cachedPlural?.has(category)) {
      return this.formatString(cachedPlural.get(category)!, [count, ...args]);
    }

    try {
      if (this.resourceMgr) {
        const pluralKey = `${key}_${category}`;
        const resourceId = this.getResourceId(pluralKey);
        if (resourceId !== -1) {
          const value = this.resourceMgr.getStringSync(resourceId);

          // Cache the plural
          if (!this.cache.plurals.has(key)) {
            this.cache.plurals.set(key, new Map());
          }
          this.cache.plurals.get(key)!.set(category, value);

          return this.formatString(value, [count, ...args]);
        }
      }
    } catch (error) {
      this.logError(`Failed to get plural '${key}': ${error}`);
    }

    // Fallback: try to construct from key
    return this.formatString(`${count} ${key}`, args);
  }

  getStringArray(key: string): string[] {
    // Check cache
    const cached = this.cache.arrays.get(key);
    if (cached) {
      return [...cached];
    }

    try {
      if (this.resourceMgr) {
        const resourceId = this.getResourceId(key);
        if (resourceId !== -1) {
          const value = this.resourceMgr.getStringArrayValueSync(resourceId);
          this.cache.arrays.set(key, value);
          return [...value];
        }
      }
    } catch (error) {
      this.logError(`Failed to get string array '${key}': ${error}`);
    }

    return [];
  }

  hasString(key: string): boolean {
    if (this.cache.strings.has(key)) return true;
    if (this.fallbackStrings.has(key)) return true;

    try {
      return this.getResourceId(key) !== -1;
    } catch {
      return false;
    }
  }

  onLocaleChange(callback: LocaleChangeCallback): () => void {
    this.callbacks.add(callback);
    return () => this.callbacks.delete(callback);
  }

  getSupportedLocales(): Locale[] {
    return Object.values(Locale);
  }

  getLocaleDisplayName(locale: Locale): string {
    const displayNames: Record<Locale, string> = {
      [Locale.EN_US]: 'English (US)',
      [Locale.ZH_CN]: '简体中文',
      [Locale.ZH_TW]: '繁體中文',
      [Locale.JA_JP]: '日本語',
      [Locale.KO_KR]: '한국어',
      [Locale.DE_DE]: 'Deutsch',
      [Locale.FR_FR]: 'Français',
      [Locale.ES_ES]: 'Español'
    };
    return displayNames[locale] || locale;
  }

  formatNumber(value: number): string {
    try {
      const formatter = new i18n.NumberFormat(this.currentLocale, {
        style: 'decimal'
      });
      return formatter.format(value);
    } catch {
      return value.toString();
    }
  }

  formatCurrency(value: number, currency: string = 'USD'): string {
    try {
      const formatter = new i18n.NumberFormat(this.currentLocale, {
        style: 'currency',
        currency: currency
      });
      return formatter.format(value);
    } catch {
      return `${currency} ${value.toFixed(2)}`;
    }
  }

  formatDate(date: Date, options?: DateFormatOptions): string {
    try {
      const formatter = new i18n.DateTimeFormat(this.currentLocale, {
        dateStyle: options?.dateStyle || 'medium',
        timeStyle: options?.timeStyle
      });
      return formatter.format(date);
    } catch {
      return date.toLocaleDateString();
    }
  }

  formatRelativeTime(date: Date): string {
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffSecs = Math.floor(diffMs / 1000);
    const diffMins = Math.floor(diffSecs / 60);
    const diffHours = Math.floor(diffMins / 60);
    const diffDays = Math.floor(diffHours / 24);

    try {
      const formatter = new i18n.RelativeTimeFormat(this.currentLocale, {
        numeric: 'auto'
      });

      if (diffDays > 0) {
        return formatter.format(-diffDays, 'day');
      } else if (diffHours > 0) {
        return formatter.format(-diffHours, 'hour');
      } else if (diffMins > 0) {
        return formatter.format(-diffMins, 'minute');
      } else {
        return formatter.format(-diffSecs, 'second');
      }
    } catch {
      if (diffDays > 0) return `${diffDays} days ago`;
      if (diffHours > 0) return `${diffHours} hours ago`;
      if (diffMins > 0) return `${diffMins} minutes ago`;
      return 'just now';
    }
  }

  @preDestroy()
  destroy(): void {
    this.callbacks.clear();
    this.clearCache();
    this.initialized = false;
  }

  // ===== Private Methods =====

  private parseLocale(localeString: string): Locale {
    // Map common locale formats to our enum
    const localeMap: Record<string, Locale> = {
      'en': Locale.EN_US,
      'en-US': Locale.EN_US,
      'en_US': Locale.EN_US,
      'zh': Locale.ZH_CN,
      'zh-CN': Locale.ZH_CN,
      'zh_CN': Locale.ZH_CN,
      'zh-Hans': Locale.ZH_CN,
      'zh-TW': Locale.ZH_TW,
      'zh_TW': Locale.ZH_TW,
      'zh-Hant': Locale.ZH_TW,
      'ja': Locale.JA_JP,
      'ja-JP': Locale.JA_JP,
      'ja_JP': Locale.JA_JP,
      'ko': Locale.KO_KR,
      'ko-KR': Locale.KO_KR,
      'ko_KR': Locale.KO_KR,
      'de': Locale.DE_DE,
      'de-DE': Locale.DE_DE,
      'de_DE': Locale.DE_DE,
      'fr': Locale.FR_FR,
      'fr-FR': Locale.FR_FR,
      'fr_FR': Locale.FR_FR,
      'es': Locale.ES_ES,
      'es-ES': Locale.ES_ES,
      'es_ES': Locale.ES_ES
    };

    return localeMap[localeString] || Locale.EN_US;
  }

  private getPluralCategory(count: number): PluralCategory {
    // Simplified plural rules (English-like)
    // For full ICU compliance, use i18n.PluralRules
    try {
      const rules = new i18n.PluralRules(this.currentLocale);
      const category = rules.select(count);
      return category as PluralCategory;
    } catch {
      // Fallback to simple English rules
      if (count === 0) return PluralCategory.ZERO;
      if (count === 1) return PluralCategory.ONE;
      return PluralCategory.OTHER;
    }
  }

  private formatString(template: string, args: (string | number)[]): string {
    if (args.length === 0) return template;

    // Support both {0}, {1} style and %s, %d style
    let result = template;

    // Replace {0}, {1}, etc.
    args.forEach((arg, index) => {
      result = result.replace(new RegExp(`\\{${index}\\}`, 'g'), String(arg));
    });

    // Replace %s, %d (first occurrence for each arg)
    let argIndex = 0;
    result = result.replace(/%[sd]/g, () => {
      if (argIndex < args.length) {
        return String(args[argIndex++]);
      }
      return '';
    });

    return result;
  }

  private getResourceId(key: string): number {
    // HarmonyOS resource IDs are typically defined in resources/base/element/string.json
    // This is a simplified lookup - in production, use proper resource references
    try {
      // Resource IDs would be defined in $r('app.string.key')
      // For dynamic key lookup, we'd need a mapping
      return -1; // Placeholder - actual implementation depends on resource setup
    } catch {
      return -1;
    }
  }

  private clearCache(): void {
    this.cache.strings.clear();
    this.cache.plurals.clear();
    this.cache.arrays.clear();
  }

  private notifyLocaleChange(locale: Locale): void {
    this.callbacks.forEach(callback => {
      try {
        callback(locale);
      } catch (error) {
        this.logError(`Callback error: ${error}`);
      }
    });
  }

  private initializeFallbacks(): void {
    // Common UI strings as fallbacks
    this.fallbackStrings.set('app_name', 'Arcana');
    this.fallbackStrings.set('loading', 'Loading...');
    this.fallbackStrings.set('error', 'Error');
    this.fallbackStrings.set('retry', 'Retry');
    this.fallbackStrings.set('cancel', 'Cancel');
    this.fallbackStrings.set('ok', 'OK');
    this.fallbackStrings.set('save', 'Save');
    this.fallbackStrings.set('delete', 'Delete');
    this.fallbackStrings.set('edit', 'Edit');
    this.fallbackStrings.set('create', 'Create');
    this.fallbackStrings.set('search', 'Search');
    this.fallbackStrings.set('no_results', 'No results found');
    this.fallbackStrings.set('network_error', 'Network error. Please check your connection.');
    this.fallbackStrings.set('unknown_error', 'An unknown error occurred');

    // User-related strings
    this.fallbackStrings.set('users', 'Users');
    this.fallbackStrings.set('user_detail', 'User Detail');
    this.fallbackStrings.set('create_user', 'Create User');
    this.fallbackStrings.set('edit_user', 'Edit User');
    this.fallbackStrings.set('email', 'Email');
    this.fallbackStrings.set('first_name', 'First Name');
    this.fallbackStrings.set('last_name', 'Last Name');

    // Sync-related strings
    this.fallbackStrings.set('syncing', 'Syncing...');
    this.fallbackStrings.set('sync_complete', 'Sync complete');
    this.fallbackStrings.set('sync_failed', 'Sync failed');
    this.fallbackStrings.set('offline_mode', 'Offline Mode');
    this.fallbackStrings.set('pending_changes', '{0} pending changes');
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

/**
 * String resources helper for compile-time safety
 */
export class StringRes {
  // App
  static readonly APP_NAME = 'app_name';

  // Common
  static readonly LOADING = 'loading';
  static readonly ERROR = 'error';
  static readonly RETRY = 'retry';
  static readonly CANCEL = 'cancel';
  static readonly OK = 'ok';
  static readonly SAVE = 'save';
  static readonly DELETE = 'delete';
  static readonly EDIT = 'edit';
  static readonly CREATE = 'create';
  static readonly SEARCH = 'search';
  static readonly NO_RESULTS = 'no_results';

  // Errors
  static readonly NETWORK_ERROR = 'network_error';
  static readonly UNKNOWN_ERROR = 'unknown_error';

  // Users
  static readonly USERS = 'users';
  static readonly USER_DETAIL = 'user_detail';
  static readonly CREATE_USER = 'create_user';
  static readonly EDIT_USER = 'edit_user';
  static readonly EMAIL = 'email';
  static readonly FIRST_NAME = 'first_name';
  static readonly LAST_NAME = 'last_name';

  // Sync
  static readonly SYNCING = 'syncing';
  static readonly SYNC_COMPLETE = 'sync_complete';
  static readonly SYNC_FAILED = 'sync_failed';
  static readonly OFFLINE_MODE = 'offline_mode';
  static readonly PENDING_CHANGES = 'pending_changes';
}

/**
 * Localization hook for UI components
 */
export function useLocalization(manager: ILocalizationManager): {
  t: (key: string, ...args: (string | number)[]) => string;
  tc: (key: string, count: number, ...args: (string | number)[]) => string;
  locale: Locale;
  setLocale: (locale: Locale) => Promise<void>;
  formatNumber: (value: number) => string;
  formatCurrency: (value: number, currency?: string) => string;
  formatDate: (date: Date, options?: DateFormatOptions) => string;
  formatRelativeTime: (date: Date) => string;
} {
  return {
    t: (key: string, ...args: (string | number)[]) => manager.getString(key, ...args),
    tc: (key: string, count: number, ...args: (string | number)[]) => manager.getPlural(key, count, ...args),
    locale: manager.getCurrentLocale(),
    setLocale: (locale: Locale) => manager.setLocale(locale),
    formatNumber: (value: number) => manager.formatNumber(value),
    formatCurrency: (value: number, currency?: string) => manager.formatCurrency(value, currency),
    formatDate: (date: Date, options?: DateFormatOptions) => manager.formatDate(date, options),
    formatRelativeTime: (date: Date) => manager.formatRelativeTime(date)
  };
}
