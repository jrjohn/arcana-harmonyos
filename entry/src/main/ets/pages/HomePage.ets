import { router } from '@kit.ArkUI';
import { HomeViewModel, HomeState, HomeInput, HomeEffect } from '../presentation/viewmodel/HomeViewModel';
import { StateUnsubscribe, EffectUnsubscribe } from '../presentation/viewmodel/BaseViewModel';
import { getContainer } from '../core/di/AppContainer';
import { Logger } from '../core/logging/Logger';

const TAG = 'HomePage';

// Arcana Theme Colors
const ArcanaBackground = '#1A1A2E';
const ArcanaIndigo = '#16213E';
const ArcanaPurple = '#0F3460';
const ArcanaViolet = '#7C3AED';
const ArcanaCyan = '#00D9FF';
const ArcanaGold = '#FFD700';
const ArcanaGlow = '#E8E4F0';
const ArcanaAmber = '#FFC107';
const ArcanaBackgroundLight = '#2A2A4E';

/**
 * Home Page - Fancy landing screen with mystical theme and user statistics.
 */
@Entry
@Component
struct HomePage {
  @State private state: HomeState = {
    isLoading: true,
    error: undefined,
    totalUserCount: 0,
    loadedUserCount: 0,
    users: []
  };

  private viewModel: HomeViewModel | null = null;
  private stateUnsubscribe: StateUnsubscribe<HomeState> | null = null;
  private effectUnsubscribe: EffectUnsubscribe<HomeEffect> | null = null;

  aboutToAppear(): void {
    Logger.d(TAG, 'HomePage appearing');

    try {
      const container = getContainer();
      const repository = container.getUserRepository();
      const analytics = container.getAnalyticsService();

      this.viewModel = new HomeViewModel(repository, analytics);

      // Subscribe to state changes
      this.stateUnsubscribe = this.viewModel.subscribeToState((newState) => {
        this.state = newState;
      });

      // Subscribe to effects
      this.effectUnsubscribe = this.viewModel.subscribeToEffects((effect) => {
        this.handleEffect(effect);
      });

      // Track screen
      analytics.trackScreen('HomePage', 'HomePage');

      // Load data
      this.viewModel.onEvent({ type: 'LoadData' });
    } catch (error) {
      Logger.e(TAG, `Failed to initialize: ${error}`);
    }
  }

  aboutToDisappear(): void {
    Logger.d(TAG, 'HomePage disappearing');

    if (this.stateUnsubscribe !== null) {
      this.stateUnsubscribe.unsubscribe();
    }
    if (this.effectUnsubscribe !== null) {
      this.effectUnsubscribe.unsubscribe();
    }
    if (this.viewModel !== null) {
      this.viewModel.destroy();
    }
  }

  private handleEffect(effect: HomeEffect): void {
    Logger.d(TAG, `Handling effect: ${effect.type}`);

    switch (effect.type) {
      case 'NavigateToUsers':
        try {
          this.getUIContext().getRouter().pushUrl({
            url: 'pages/UserListPage'
          });
        } catch (err) {
          console.error(`pushUrl error: ${err}`);
        }
        break;

      case 'ShowError':
        try {
          this.getUIContext().getPromptAction().showToast({
            message: effect.message,
            duration: 3000
          });
        } catch (err) {
          console.error(`showToast error: ${err}`);
        }
        break;
    }
  }

  private sendEvent(input: HomeInput): void {
    this.viewModel?.onEvent(input);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // Background gradient
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [
            [ArcanaBackground, 0],
            [ArcanaIndigo, 0.5],
            [ArcanaPurple, 1]
          ]
        })

      // Decorative circle - top right
      Stack()
        .width(200)
        .height(200)
        .borderRadius(100)
        .radialGradient({
          center: ['50%', '50%'],
          radius: 100,
          colors: [
            ['rgba(124, 58, 237, 0.3)', 0],
            ['rgba(124, 58, 237, 0)', 1]
          ]
        })
        .position({ x: '60%', y: 50 })

      // Decorative circle - bottom left
      Stack()
        .width(150)
        .height(150)
        .borderRadius(75)
        .radialGradient({
          center: ['50%', '50%'],
          radius: 75,
          colors: [
            ['rgba(0, 217, 255, 0.2)', 0],
            ['rgba(0, 217, 255, 0)', 1]
          ]
        })
        .position({ x: 30, y: '70%' })

      // Decorative circle - center background glow
      Stack()
        .width(300)
        .height(300)
        .borderRadius(150)
        .radialGradient({
          center: ['50%', '50%'],
          radius: 150,
          colors: [
            ['rgba(124, 58, 237, 0.15)', 0],
            ['rgba(124, 58, 237, 0)', 1]
          ]
        })
        .position({ x: '15%', y: '25%' })

      // Main content
      Column() {
        if (this.state.isLoading) {
          // Loading state
          this.BuildLoadingContent()
        } else {
          // Main content
          this.BuildMainContent()
        }
      }
      .width('100%')
      .padding(32)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private BuildLoadingContent() {
    Column() {
      // Loading indicator
      LoadingProgress()
        .width(48)
        .height(48)
        .color(ArcanaGold)

      Text($r('app.string.loading'))
        .fontSize(16)
        .fontColor(ArcanaGlow)
        .margin({ top: 16 })
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private BuildMainContent() {
    Column() {
      // App title with sparkles
      Text($r('app.string.home_title'))
        .fontSize(36)
        .fontWeight(FontWeight.Bold)
        .fontColor(ArcanaGold)
        .textAlign(TextAlign.Center)

      // Subtitle
      Text($r('app.string.home_subtitle'))
        .fontSize(16)
        .fontColor(ArcanaGlow)
        .margin({ top: 8 })
        .textAlign(TextAlign.Center)

      // Stats card
      Column() {
        Text($r('app.string.total_users'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(ArcanaCyan)

        Text(`${this.state.totalUserCount}`)
          .fontSize(56)
          .fontWeight(FontWeight.Bold)
          .fontColor(ArcanaGold)
          .margin({ top: 8 })

        Text() {
          Span($r('app.string.loaded_users'))
          Span(`: ${this.state.loadedUserCount}`)
        }
        .fontSize(14)
        .fontColor(ArcanaGlow)
        .margin({ top: 8 })
      }
      .width('80%')
      .padding(24)
      .margin({ top: 48 })
      .borderRadius(16)
      .alignItems(HorizontalAlign.Center)
      .linearGradient({
        angle: 135,
        colors: [
          ['rgba(42, 42, 78, 0.7)', 0],
          ['rgba(22, 33, 62, 0.5)', 1]
        ]
      })
      .border({
        width: 1,
        color: 'rgba(124, 58, 237, 0.3)'
      })

      // Action button
      Button() {
        Row() {
          Image($r('sys.media.ohos_ic_public_more'))
            .width(20)
            .height(20)
            .fillColor(ArcanaIndigo)

          Text($r('app.string.manage_users'))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(ArcanaIndigo)
            .margin({ left: 8 })
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      }
      .width('80%')
      .height(52)
      .margin({ top: 48 })
      .borderRadius(26)
      .backgroundColor(Color.Transparent)
      .linearGradient({
        direction: GradientDirection.Right,
        colors: [
          [ArcanaAmber, 0],
          [ArcanaGold, 1]
        ]
      })
      .shadow({
        radius: 16,
        color: 'rgba(255, 215, 0, 0.3)',
        offsetX: 0,
        offsetY: 4
      })
      .onClick(() => this.sendEvent({ type: 'NavigateToUsers' }))

      // Version info at bottom
      Text($r('app.string.app_version'))
        .fontSize(12)
        .fontColor('rgba(232, 228, 240, 0.5)')
        .margin({ top: 64 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
