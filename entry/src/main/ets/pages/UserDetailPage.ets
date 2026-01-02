import { router } from '@kit.ArkUI';
import { User, UserFactory } from '../domain/models/User';
import { UserDetailViewModel, UserDetailState, UserDetailInput, UserDetailEffect } from '../presentation/viewmodel/UserDetailViewModel';
import { StateUnsubscribe, EffectUnsubscribe } from '../presentation/viewmodel/BaseViewModel';
import { getContainer } from '../core/di/AppContainer';
import { LoadingView } from '../presentation/components/LoadingView';
import { ErrorView } from '../presentation/components/ErrorView';
import { Logger } from '../core/logging/Logger';

const TAG = 'UserDetailPage';

interface RouterParams {
  userId: number;
}

/**
 * User Detail Page - Shows detailed user information with edit and delete options.
 */
@Entry
@Component
struct UserDetailPage {
  @State private state: UserDetailState = {
    isLoading: true,
    error: undefined,
    user: undefined,
    userId: 0,
    isDeleting: false,
    showDeleteConfirmation: false
  };

  private viewModel: UserDetailViewModel | null = null;
  private stateUnsubscribe: StateUnsubscribe<UserDetailState> | null = null;
  private effectUnsubscribe: EffectUnsubscribe<UserDetailEffect> | null = null;

  aboutToAppear(): void {
    Logger.d(TAG, 'UserDetailPage appearing');

    // Get userId from router params
    let params: RouterParams | undefined;
    try {
      params = this.getUIContext().getRouter().getParams() as RouterParams;
    } catch (err) {
      Logger.e(TAG, `Failed to get params: ${err}`);
    }
    const userId = params?.userId ?? 0;

    if (userId === 0) {
      Logger.e(TAG, 'No userId provided');
      try {
        this.getUIContext().getRouter().back();
      } catch (err) {
        Logger.e(TAG, `Failed to navigate back: ${err}`);
      }
      return;
    }

    try {
      const container = getContainer();

      // Use DI factory instead of manual instantiation
      this.viewModel = container.createUserDetailViewModel(userId);

      // Subscribe to state changes
      this.stateUnsubscribe = this.viewModel.subscribeToState((newState) => {
        this.state = newState;
      });

      // Subscribe to effects
      this.effectUnsubscribe = this.viewModel.subscribeToEffects((effect) => {
        this.handleEffect(effect);
      });

      // Track screen
      const analytics = container.getAnalyticsService();
      analytics.trackScreen('UserDetailPage', 'UserDetailPage');
    } catch (error) {
      Logger.e(TAG, `Failed to initialize: ${error}`);
    }
  }

  aboutToDisappear(): void {
    Logger.d(TAG, 'UserDetailPage disappearing');

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

  private handleEffect(effect: UserDetailEffect): void {
    Logger.d(TAG, `Handling effect: ${effect.type}`);

    switch (effect.type) {
      case 'NavigateBack':
        try {
          this.getUIContext().getRouter().back();
        } catch (err) {
          console.error(`back error: ${err}`);
        }
        break;

      case 'NavigateToEdit':
        try {
          this.getUIContext().getRouter().pushUrl({
            url: 'pages/EditUserPage',
            params: { userId: effect.userId }
          });
        } catch (err) {
          console.error(`pushUrl error: ${err}`);
        }
        break;

      case 'ShowMessage':
        try {
          this.getUIContext().getPromptAction().showToast({
            message: effect.message,
            duration: 2000
          });
        } catch (err) {
          console.error(`showToast error: ${err}`);
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

      case 'UserDeleted':
        // Handled by NavigateBack
        break;
    }
  }

  private sendEvent(input: UserDetailInput): void {
    this.viewModel?.onEvent(input);
  }

  @Builder
  private BuildHeader() {
    Column() {
      // Back button and actions
      Row() {
        Button() {
          Image($r('sys.media.ohos_ic_public_arrow_left'))
            .width(24)
            .height(24)
            .fillColor(Color.White)
        }
        .type(ButtonType.Circle)
        .backgroundColor('rgba(255, 255, 255, 0.2)')
        .width(40)
        .height(40)
        .onClick(() => this.sendEvent({ type: 'NavigateBack' }))

        Blank()

        // Edit button
        Button() {
          Image($r('sys.media.ohos_ic_public_edit'))
            .width(24)
            .height(24)
            .fillColor(Color.White)
        }
        .type(ButtonType.Circle)
        .backgroundColor('rgba(255, 255, 255, 0.2)')
        .width(40)
        .height(40)
        .margin({ right: 12 })
        .onClick(() => this.sendEvent({ type: 'EditUser' }))

        // Delete button
        Button() {
          Text('✕')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .type(ButtonType.Circle)
        .backgroundColor('rgba(255, 255, 255, 0.2)')
        .width(40)
        .height(40)
        .onClick(() => this.showDeleteDialog())
      }
      .width('100%')
      .padding({ top: 48, left: 16, right: 16 })

      // Avatar and name
      if (this.state.user) {
        Column() {
          // Avatar
          Stack({ alignContent: Alignment.Center }) {
            if (this.state.user.avatar && this.state.user.avatar.length > 0) {
              Image(this.state.user.avatar)
                .width(100)
                .height(100)
                .borderRadius(50)
                .objectFit(ImageFit.Cover)
                .border({ width: 4, color: Color.White })
            } else {
              Text(UserFactory.getInitials(this.state.user))
                .fontSize(36)
                .fontWeight(FontWeight.Medium)
                .fontColor('#7C3AED')
            }
          }
          .width(100)
          .height(100)
          .borderRadius(50)
          .backgroundColor(Color.White)

          Text(UserFactory.getFullName(this.state.user))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .margin({ top: 16 })

          Text(this.state.user.email)
            .fontSize(16)
            .fontColor('rgba(255, 255, 255, 0.8)')
            .margin({ top: 8 })
        }
        .margin({ top: 24, bottom: 32 })
      }
    }
    .width('100%')
    .linearGradient({
      direction: GradientDirection.RightBottom,
      colors: [['#7C3AED', 0], ['#A78BFA', 1]]
    })
  }

  private showDeleteDialog(): void {
    try {
      const resourceMgr = this.getUIContext().getHostContext()?.resourceManager;
      if (!resourceMgr) return;
      const deleteTitle = resourceMgr.getStringSync($r('app.string.delete').id);
      const confirmMsg = resourceMgr.getStringSync($r('app.string.confirm_delete_message').id);
      const cancelText = resourceMgr.getStringSync($r('app.string.cancel').id);
      const deleteText = resourceMgr.getStringSync($r('app.string.delete').id);

      this.getUIContext().getPromptAction().showDialog({
        title: deleteTitle,
        message: confirmMsg,
        buttons: [
          { text: cancelText, color: '#6B7280' },
          { text: deleteText, color: '#DC2626' }
        ]
      }).then((result) => {
        if (result.index === 1) {
          this.sendEvent({ type: 'ConfirmDelete' });
        }
      }).catch((err: Error) => {
        console.error(`showDialog error: ${err.message}`);
      });
    } catch (err) {
      console.error(`showDialog exception: ${err}`);
    }
  }

  @Builder
  private BuildInfoCardWithResource(icon: Resource, labelResource: Resource, value: string) {
    Row() {
      Image(icon)
        .width(24)
        .height(24)
        .fillColor('#7C3AED')

      Column() {
        Text(labelResource)
          .fontSize(12)
          .fontColor('#6B7280')

        Text(value)
          .fontSize(16)
          .fontColor('#1F2937')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 16 })
      .layoutWeight(1)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin({ bottom: 12 })
  }

  build() {
    Column() {
      if (this.state.isLoading) {
        LoadingView({ messageResource: $r('app.string.loading_user') })
      } else if (this.state.error) {
        ErrorView({
          message: this.state.error,
          showRetry: true,
          onRetry: () => this.sendEvent({ type: 'RefreshUser' })
        })
      } else if (this.state.user) {
        Scroll() {
          Column() {
            // Header with avatar
            this.BuildHeader()

            // User details
            Column() {
              Text($r('app.string.user_information'))
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1F2937')
                .width('100%')
                .margin({ bottom: 16 })

              this.BuildInfoCardWithResource(
                $r('sys.media.ohos_ic_public_email'),
                $r('app.string.email'),
                this.state.user?.email ?? ''
              )

              this.BuildInfoCardWithResource(
                $r('sys.media.ohos_ic_public_arrow_right'),
                $r('app.string.first_name'),
                this.state.user?.firstName ?? ''
              )

              this.BuildInfoCardWithResource(
                $r('sys.media.ohos_ic_public_arrow_right'),
                $r('app.string.last_name'),
                this.state.user?.lastName ?? ''
              )

              this.BuildInfoCardWithResource(
                $r('sys.media.ohos_ic_public_arrow_right'),
                $r('app.string.user_id'),
                this.state.user?.id.toString() ?? ''
              )
            }
            .padding({ left: 16, right: 16, top: 24, bottom: 24 })
          }
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }

      // Deleting overlay
      if (this.state.isDeleting) {
        Stack({ alignContent: Alignment.Center }) {
          Column() {
            LoadingProgress()
              .width(48)
              .height(48)
              .color(Color.White)

            Text($r('app.string.deleting'))
              .fontSize(16)
              .fontColor(Color.White)
              .margin({ top: 16 })
          }
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .position({ x: 0, y: 0 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F3FF')
  }
}
