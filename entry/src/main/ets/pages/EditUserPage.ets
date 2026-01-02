import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { UserFormViewModel, UserFormState, UserFormInput, UserFormEffect } from '../presentation/viewmodel/UserFormViewModel';
import { StateUnsubscribe, EffectUnsubscribe } from '../presentation/viewmodel/BaseViewModel';
import { ServiceLocator } from '../core/di/AppInitializer';
import { LoadingView } from '../presentation/components/LoadingView';
import { Logger } from '../core/logging/Logger';
import { PhotoPicker } from '../core/utils/PhotoPicker';

const TAG = 'EditUserPage';

interface RouterParams {
  userId: number;
}

/**
 * Edit User Page - Form for editing an existing user with validation.
 */
@Entry
@Component
struct EditUserPage {
  @State private state: UserFormState = {
    isLoading: true,
    error: undefined,
    mode: 'edit',
    userId: undefined,
    firstName: '',
    lastName: '',
    email: '',
    avatar: '',
    firstNameError: undefined,
    lastNameError: undefined,
    emailError: undefined,
    isValid: false,
    isSaving: false,
    hasChanges: false,
    originalUser: undefined
  };

  @State private firstNameInput: string = '';
  @State private lastNameInput: string = '';
  @State private emailInput: string = '';

  private viewModel: UserFormViewModel | null = null;
  private stateUnsubscribe: StateUnsubscribe<UserFormState> | null = null;
  private effectUnsubscribe: EffectUnsubscribe<UserFormEffect> | null = null;

  aboutToAppear(): void {
    Logger.d(TAG, 'EditUserPage appearing');

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
      const repository = ServiceLocator.getUserRepository();
      const analytics = ServiceLocator.getAnalyticsService();

      this.viewModel = new UserFormViewModel(repository, analytics, 'edit', userId);

      // Subscribe to state changes
      this.stateUnsubscribe = this.viewModel.subscribeToState((newState) => {
        this.state = newState;

        // Update local input states when user is loaded
        if (!this.state.isLoading && this.state.originalUser) {
          if (this.firstNameInput.length === 0) {
            this.firstNameInput = newState.firstName;
            this.lastNameInput = newState.lastName;
            this.emailInput = newState.email;
          }
        }
      });

      // Subscribe to effects
      this.effectUnsubscribe = this.viewModel.subscribeToEffects((effect) => {
        this.handleEffect(effect);
      });

      // Track screen
      analytics.trackScreen('EditUserPage', 'EditUserPage');
    } catch (error) {
      Logger.e(TAG, `Failed to initialize: ${error}`);
    }
  }

  aboutToDisappear(): void {
    Logger.d(TAG, 'EditUserPage disappearing');

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

  private handleEffect(effect: UserFormEffect): void {
    Logger.d(TAG, `Handling effect: ${effect.type}`);

    switch (effect.type) {
      case 'NavigateBack':
        try {
          this.getUIContext().getRouter().back();
        } catch (err) {
          console.error(`back error: ${err}`);
        }
        break;

      case 'ShowSuccess':
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

      case 'ShowUnsavedChangesDialog':
        this.showUnsavedChangesDialog();
        break;
    }
  }

  private showUnsavedChangesDialog(): void {
    try {
      const resourceMgr = this.getUIContext().getHostContext()?.resourceManager;
      if (!resourceMgr) return;
      const title = resourceMgr.getStringSync($r('app.string.unsaved_changes').id);
      const message = resourceMgr.getStringSync($r('app.string.unsaved_changes_message').id);
      const stayText = resourceMgr.getStringSync($r('app.string.stay').id);
      const leaveText = resourceMgr.getStringSync($r('app.string.leave').id);

      this.getUIContext().getPromptAction().showDialog({
        title: title,
        message: message,
        buttons: [
          { text: stayText, color: '#7C3AED' },
          { text: leaveText, color: '#DC2626' }
        ]
      }).then((result) => {
        if (result.index === 1) {
          try {
            this.getUIContext().getRouter().back();
          } catch (err) {
            console.error(`back error: ${err}`);
          }
        }
      }).catch((err: Error) => {
        console.error(`showDialog error: ${err.message}`);
      });
    } catch (err) {
      console.error(`showDialog exception: ${err}`);
    }
  }

  private sendEvent(input: UserFormInput): void {
    this.viewModel?.onEvent(input);
  }

  private async pickAvatar(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      if (!context) {
        Logger.e(TAG, 'Failed to get context for photo picker');
        return;
      }

      const result = await PhotoPicker.pickPhoto(context);
      if (result.success && result.uri) {
        Logger.d(TAG, `Avatar selected: ${result.uri}`);
        this.sendEvent({ type: 'UpdateAvatar', value: result.uri });
      } else if (result.error) {
        Logger.w(TAG, `Photo picker error: ${result.error}`);
      }
    } catch (error) {
      Logger.e(TAG, `Failed to pick avatar: ${error}`);
    }
  }

  @Builder
  private BuildTextFieldWithResource(
    labelResource: Resource,
    value: string,
    placeholderResource: Resource,
    error: string | undefined,
    inputType: InputType,
    onValueChange: (value: string) => void,
    onBlur: () => void
  ) {
    Column() {
      Text(labelResource)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#374151')
        .margin({ bottom: 8 })

      TextInput({ text: value, placeholder: placeholderResource })
        .width('100%')
        .height(48)
        .backgroundColor(Color.White)
        .borderRadius(8)
        .border({
          width: 1,
          color: error ? '#DC2626' : '#E5E7EB'
        })
        .padding({ left: 16, right: 16 })
        .fontSize(16)
        .fontColor('#1F2937')
        .placeholderColor('#9CA3AF')
        .type(inputType)
        .onChange((newValue: string) => {
          onValueChange(newValue);
        })
        .onBlur(() => {
          onBlur();
        })

      if (error) {
        Text(error)
          .fontSize(12)
          .fontColor('#DC2626')
          .margin({ top: 4 })
          .width('100%')
      }
    }
    .width('100%')
    .margin({ bottom: 20 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      // Header
      Row() {
        Button() {
          Image($r('sys.media.ohos_ic_public_arrow_left'))
            .width(24)
            .height(24)
            .fillColor('#1F2937')
        }
        .type(ButtonType.Circle)
        .backgroundColor(Color.Transparent)
        .width(40)
        .height(40)
        .onClick(() => this.sendEvent({ type: 'Cancel' }))

        Text($r('app.string.edit_user'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2937')
          .margin({ left: 8 })

        Blank()
      }
      .width('100%')
      .padding({ top: 48, left: 8, right: 16, bottom: 16 })
      .backgroundColor(Color.White)

      if (this.state.isLoading) {
        LoadingView({ messageResource: $r('app.string.loading_user') })
      } else {
        // Form
        Scroll() {
          Column() {
            // Avatar picker
            Column() {
              Stack({ alignContent: Alignment.Center }) {
                // Avatar image or initials
                Stack({ alignContent: Alignment.Center }) {
                  if (this.state.avatar && this.state.avatar.length > 0) {
                    Image(this.state.avatar)
                      .width(100)
                      .height(100)
                      .borderRadius(50)
                      .objectFit(ImageFit.Cover)
                  } else {
                    Text(this.getInitials())
                      .fontSize(32)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Color.White)
                  }
                }
                .width(100)
                .height(100)
                .borderRadius(50)
                .backgroundColor('#7C3AED')

                // Camera icon overlay
                Stack({ alignContent: Alignment.Center }) {
                  Image($r('sys.media.ohos_ic_public_camera'))
                    .width(16)
                    .height(16)
                    .fillColor(Color.White)
                }
                .width(32)
                .height(32)
                .borderRadius(16)
                .backgroundColor('#7C3AED')
                .border({ width: 2, color: Color.White })
                .position({ x: 68, y: 68 })
              }
              .width(100)
              .height(100)
              .onClick(() => this.pickAvatar())

              Text($r('app.string.tap_to_change_avatar'))
                .fontSize(14)
                .fontColor('#6B7280')
                .margin({ top: 8 })
            }
            .width('100%')
            .padding({ top: 24, bottom: 32 })
            .alignItems(HorizontalAlign.Center)

            // Form fields
            Column() {
              this.BuildTextFieldWithResource(
                $r('app.string.first_name'),
                this.firstNameInput,
                $r('app.string.enter_first_name'),
                this.state.firstNameError,
                InputType.Normal,
                (value: string) => {
                  this.firstNameInput = value;
                  this.sendEvent({ type: 'UpdateFirstName', value: value });
                },
                () => {
                  this.sendEvent({ type: 'ValidateField', field: 'firstName' });
                }
              )

              this.BuildTextFieldWithResource(
                $r('app.string.last_name'),
                this.lastNameInput,
                $r('app.string.enter_last_name'),
                this.state.lastNameError,
                InputType.Normal,
                (value: string) => {
                  this.lastNameInput = value;
                  this.sendEvent({ type: 'UpdateLastName', value: value });
                },
                () => {
                  this.sendEvent({ type: 'ValidateField', field: 'lastName' });
                }
              )

              this.BuildTextFieldWithResource(
                $r('app.string.email'),
                this.emailInput,
                $r('app.string.enter_email'),
                this.state.emailError,
                InputType.Email,
                (value: string) => {
                  this.emailInput = value;
                  this.sendEvent({ type: 'UpdateEmail', value: value });
                },
                () => {
                  this.sendEvent({ type: 'ValidateField', field: 'email' });
                }
              )
            }
            .padding({ left: 16, right: 16 })
          }
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .backgroundColor('#F5F3FF')

        // Submit button
        Column() {
          Button(this.state.isSaving ? $r('app.string.saving') : $r('app.string.save_changes'))
            .width('100%')
            .height(52)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.canSave() ? '#7C3AED' : '#C4B5FD')
            .fontColor(Color.White)
            .borderRadius(26)
            .enabled(!this.state.isSaving && this.canSave())
            .onClick(() => this.sendEvent({ type: 'Submit' }))
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 32 })
        .backgroundColor(Color.White)
        .shadow({
          radius: 8,
          color: 'rgba(0, 0, 0, 0.05)',
          offsetX: 0,
          offsetY: -4
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F3FF')
  }

  private getInitials(): string {
    const first = this.firstNameInput.charAt(0).toUpperCase() || '?';
    const last = this.lastNameInput.charAt(0).toUpperCase() || '?';
    return `${first}${last}`;
  }

  private canSave(): boolean {
    return this.state.hasChanges && this.state.isValid;
  }
}
