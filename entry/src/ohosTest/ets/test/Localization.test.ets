/**
 * Unit Tests for Localization Manager
 */

import { describe, it, expect, beforeEach } from '@ohos/hypium';
import {
  LocalizationManager,
  Locale,
  StringRes,
  useLocalization
} from '../../../main/ets/core/i18n/LocalizationManager';
import { MockLogger } from '../../../main/ets/core/di/testing';

export default function LocalizationTest() {
  describe('LocalizationManager', () => {
    let localizationManager: LocalizationManager;
    let mockLogger: MockLogger;

    beforeEach(() => {
      mockLogger = new MockLogger();
      localizationManager = new LocalizationManager();
      localizationManager.setLogger(mockLogger);
    });

    describe('Locale Management', () => {
      it('should have default locale', () => {
        const locale = localizationManager.getCurrentLocale();
        expect(locale).not.toBeUndefined();
      });

      it('should change locale', async () => {
        await localizationManager.setLocale(Locale.ZH_CN);
        expect(localizationManager.getCurrentLocale()).assertEqual(Locale.ZH_CN);
      });

      it('should not change if same locale', async () => {
        const initialLocale = localizationManager.getCurrentLocale();
        await localizationManager.setLocale(initialLocale);
        // No error should be thrown
        expect(localizationManager.getCurrentLocale()).assertEqual(initialLocale);
      });

      it('should return supported locales', () => {
        const locales = localizationManager.getSupportedLocales();

        expect(locales.length).toBeGreaterThan(0);
        expect(locales).toContain(Locale.EN_US);
        expect(locales).toContain(Locale.ZH_CN);
        expect(locales).toContain(Locale.JA_JP);
      });
    });

    describe('Locale Display Names', () => {
      it('should return display name for English', () => {
        const name = localizationManager.getLocaleDisplayName(Locale.EN_US);
        expect(name).assertEqual('English (US)');
      });

      it('should return display name for Chinese', () => {
        const name = localizationManager.getLocaleDisplayName(Locale.ZH_CN);
        expect(name).assertEqual('简体中文');
      });

      it('should return display name for Japanese', () => {
        const name = localizationManager.getLocaleDisplayName(Locale.JA_JP);
        expect(name).assertEqual('日本語');
      });

      it('should return display name for all supported locales', () => {
        const locales = localizationManager.getSupportedLocales();
        for (const locale of locales) {
          const name = localizationManager.getLocaleDisplayName(locale);
          expect(name).not.toBeUndefined();
          expect(name.length).toBeGreaterThan(0);
        }
      });
    });

    describe('String Retrieval', () => {
      it('should return fallback strings', () => {
        const appName = localizationManager.getString(StringRes.APP_NAME);
        expect(appName).assertEqual('Arcana');
      });

      it('should return loading string', () => {
        const loading = localizationManager.getString(StringRes.LOADING);
        expect(loading).assertEqual('Loading...');
      });

      it('should return key if not found', () => {
        const unknown = localizationManager.getString('unknown_key');
        expect(unknown).assertEqual('unknown_key');
      });

      it('should format string with arguments', () => {
        // Test {0} style formatting
        const template = '{0} pending changes';
        const formatted = localizationManager.getString('pending_changes', 5);
        // Since we use fallback, it should contain the formatted value
        expect(formatted).toContain('5');
      });
    });

    describe('Locale Change Subscription', () => {
      it('should notify on locale change', async () => {
        let notifiedLocale: Locale | undefined;
        const unsubscribe = localizationManager.onLocaleChange((locale) => {
          notifiedLocale = locale;
        });

        await localizationManager.setLocale(Locale.ZH_CN);

        expect(notifiedLocale).assertEqual(Locale.ZH_CN);
        unsubscribe();
      });

      it('should allow unsubscribe', async () => {
        let callCount = 0;
        const unsubscribe = localizationManager.onLocaleChange(() => {
          callCount++;
        });

        await localizationManager.setLocale(Locale.ZH_CN);
        expect(callCount).assertEqual(1);

        unsubscribe();
        await localizationManager.setLocale(Locale.JA_JP);
        expect(callCount).assertEqual(1);
      });
    });

    describe('Number Formatting', () => {
      it('should format numbers', () => {
        const formatted = localizationManager.formatNumber(1234567.89);

        // Should contain digits and possibly locale-specific separators
        expect(formatted).toContain('1');
        expect(formatted).toContain('2');
      });

      it('should format currency', () => {
        const formatted = localizationManager.formatCurrency(99.99, 'USD');

        // Should contain currency symbol and value
        expect(formatted.length).toBeGreaterThan(0);
      });
    });

    describe('Date Formatting', () => {
      it('should format date', () => {
        const date = new Date(2024, 0, 15); // January 15, 2024
        const formatted = localizationManager.formatDate(date);

        expect(formatted.length).toBeGreaterThan(0);
      });

      it('should format date with options', () => {
        const date = new Date(2024, 0, 15, 10, 30);
        const formatted = localizationManager.formatDate(date, {
          dateStyle: 'long',
          timeStyle: 'short'
        });

        expect(formatted.length).toBeGreaterThan(0);
      });

      it('should format relative time', () => {
        const pastDate = new Date(Date.now() - 3600000); // 1 hour ago
        const formatted = localizationManager.formatRelativeTime(pastDate);

        expect(formatted.length).toBeGreaterThan(0);
      });
    });

    describe('hasString', () => {
      it('should return true for existing fallback strings', () => {
        expect(localizationManager.hasString(StringRes.APP_NAME)).assertTrue();
        expect(localizationManager.hasString(StringRes.LOADING)).assertTrue();
      });

      it('should return false for unknown keys', () => {
        expect(localizationManager.hasString('completely_unknown_key_xyz')).assertFalse();
      });
    });
  });

  describe('StringRes Constants', () => {
    it('should have app constants', () => {
      expect(StringRes.APP_NAME).assertEqual('app_name');
    });

    it('should have common constants', () => {
      expect(StringRes.LOADING).assertEqual('loading');
      expect(StringRes.ERROR).assertEqual('error');
      expect(StringRes.RETRY).assertEqual('retry');
      expect(StringRes.CANCEL).assertEqual('cancel');
      expect(StringRes.OK).assertEqual('ok');
      expect(StringRes.SAVE).assertEqual('save');
      expect(StringRes.DELETE).assertEqual('delete');
    });

    it('should have user constants', () => {
      expect(StringRes.USERS).assertEqual('users');
      expect(StringRes.USER_DETAIL).assertEqual('user_detail');
      expect(StringRes.CREATE_USER).assertEqual('create_user');
      expect(StringRes.EDIT_USER).assertEqual('edit_user');
    });

    it('should have sync constants', () => {
      expect(StringRes.SYNCING).assertEqual('syncing');
      expect(StringRes.SYNC_COMPLETE).assertEqual('sync_complete');
      expect(StringRes.SYNC_FAILED).assertEqual('sync_failed');
      expect(StringRes.OFFLINE_MODE).assertEqual('offline_mode');
    });
  });

  describe('useLocalization hook', () => {
    it('should return translation function', () => {
      const localizationManager = new LocalizationManager();
      const { t } = useLocalization(localizationManager);

      const result = t(StringRes.APP_NAME);
      expect(result).assertEqual('Arcana');
    });

    it('should return plural function', () => {
      const localizationManager = new LocalizationManager();
      const { tc } = useLocalization(localizationManager);

      const result = tc('user_count', 5);
      expect(result).toContain('5');
    });

    it('should return current locale', () => {
      const localizationManager = new LocalizationManager();
      const { locale } = useLocalization(localizationManager);

      expect(locale).not.toBeUndefined();
    });

    it('should return setLocale function', () => {
      const localizationManager = new LocalizationManager();
      const { setLocale } = useLocalization(localizationManager);

      expect(typeof setLocale).assertEqual('function');
    });

    it('should return formatting functions', () => {
      const localizationManager = new LocalizationManager();
      const { formatNumber, formatCurrency, formatDate, formatRelativeTime } = useLocalization(localizationManager);

      expect(typeof formatNumber).assertEqual('function');
      expect(typeof formatCurrency).assertEqual('function');
      expect(typeof formatDate).assertEqual('function');
      expect(typeof formatRelativeTime).assertEqual('function');
    });
  });
}
