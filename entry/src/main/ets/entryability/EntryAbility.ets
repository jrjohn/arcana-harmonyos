import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppInitializer, ServiceLocator } from '../core/di/AppInitializer';

const TAG = 'EntryAbility';
const DOMAIN = 0x0000;

/**
 * Main entry ability for Arcana HarmonyOS application.
 * Handles application lifecycle and window management.
 */
export default class EntryAbility extends UIAbility {
  private appInitializer: AppInitializer | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'Ability onCreate');

    // Set context for service locator
    ServiceLocator.setContext(this.context);

    // Initialize application dependencies
    this.appInitializer = AppInitializer.getInstance(this.context);
    this.appInitializer.initialize();

    hilog.info(DOMAIN, TAG, 'Application dependencies initialized');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');

    // Cleanup resources
    if (this.appInitializer) {
      this.appInitializer.cleanup();
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageCreate');

    // Set main page
    windowStage.loadContent('pages/UserListPage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Content loaded successfully');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');

    // Trigger sync when app comes to foreground
    if (this.appInitializer) {
      this.appInitializer.onForeground();
    }
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');

    // Schedule background sync
    if (this.appInitializer) {
      this.appInitializer.onBackground();
    }
  }
}
