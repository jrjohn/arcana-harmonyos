import { router } from '@kit.ArkUI';
import { UserFormViewModel, UserFormState, UserFormInput, UserFormEffect } from '../presentation/viewmodel/UserFormViewModel';
import { StateUnsubscribe, EffectUnsubscribe } from '../presentation/viewmodel/BaseViewModel';
import { ServiceLocator } from '../core/di/AppInitializer';
import { Logger } from '../core/logging/Logger';

const TAG = 'CreateUserPage';

/**
 * Create User Page - Form for creating a new user with validation.
 */
@Entry
@Component
struct CreateUserPage {
  @State private state: UserFormState = {
    isLoading: false,
    error: undefined,
    mode: 'create',
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
    Logger.d(TAG, 'CreateUserPage appearing');

    try {
      const repository = ServiceLocator.getUserRepository();
      const analytics = ServiceLocator.getAnalyticsService();

      this.viewModel = new UserFormViewModel(repository, analytics, 'create');

      // Subscribe to state changes
      this.stateUnsubscribe = this.viewModel.subscribeToState((newState) => {
        this.state = newState;
      });

      // Subscribe to effects
      this.effectUnsubscribe = this.viewModel.subscribeToEffects((effect) => {
        this.handleEffect(effect);
      });

      // Track screen
      analytics.trackScreen('CreateUserPage', 'CreateUserPage');
    } catch (error) {
      Logger.e(TAG, `Failed to initialize: ${error}`);
    }
  }

  aboutToDisappear(): void {
    Logger.d(TAG, 'CreateUserPage disappearing');

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
      this.getUIContext().getPromptAction().showDialog({
        title: 'Unsaved Changes',
        message: 'You have unsaved changes. Are you sure you want to leave?',
        buttons: [
          { text: 'Stay', color: '#7C3AED' },
          { text: 'Leave', color: '#DC2626' }
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

  @Builder
  private BuildTextField(
    label: string,
    value: string,
    placeholder: string,
    error: string | undefined,
    inputType: InputType,
    onValueChange: (value: string) => void,
    onBlur: () => void
  ) {
    Column() {
      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#374151')
        .margin({ bottom: 8 })

      TextInput({ text: value, placeholder: placeholder })
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

        Text('Create User')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2937')
          .margin({ left: 8 })

        Blank()
      }
      .width('100%')
      .padding({ top: 48, left: 8, right: 16, bottom: 16 })
      .backgroundColor(Color.White)

      // Form
      Scroll() {
        Column() {
          // Avatar placeholder
          Column() {
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

            Text('User Avatar')
              .fontSize(14)
              .fontColor('#6B7280')
              .margin({ top: 8 })
          }
          .width('100%')
          .padding({ top: 24, bottom: 32 })
          .alignItems(HorizontalAlign.Center)

          // Form fields
          Column() {
            this.BuildTextField(
              'First Name',
              this.firstNameInput,
              'Enter first name',
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

            this.BuildTextField(
              'Last Name',
              this.lastNameInput,
              'Enter last name',
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

            this.BuildTextField(
              'Email',
              this.emailInput,
              'Enter email address',
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
        Button(this.state.isSaving ? 'Creating...' : 'Create User')
          .width('100%')
          .height(52)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.state.isValid ? '#7C3AED' : '#C4B5FD')
          .fontColor(Color.White)
          .borderRadius(26)
          .enabled(!this.state.isSaving && this.state.isValid)
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
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F3FF')
  }

  private getInitials(): string {
    const first = this.firstNameInput.charAt(0).toUpperCase() || '?';
    const last = this.lastNameInput.charAt(0).toUpperCase() || '?';
    return `${first}${last}`;
  }
}
