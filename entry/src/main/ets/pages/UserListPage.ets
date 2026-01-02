import { router } from '@kit.ArkUI';
import { User } from '../domain/models/User';
import { UserListViewModel, UserListState, UserListInput, UserListEffect } from '../presentation/viewmodel/UserListViewModel';
import { StateUnsubscribe, EffectUnsubscribe } from '../presentation/viewmodel/BaseViewModel';
import { getContainer } from '../core/di/AppContainer';
import { UserCard } from '../presentation/components/UserCard';
import { LoadingView, InlineLoading } from '../presentation/components/LoadingView';
import { ErrorView } from '../presentation/components/ErrorView';
import { EmptyView } from '../presentation/components/EmptyView';
import { OfflineBanner, SyncingBanner } from '../presentation/components/OfflineBanner';
import { SearchBar } from '../presentation/components/SearchBar';
import { Logger } from '../core/logging/Logger';

const TAG = 'UserListPage';

/**
 * User List Page - Main screen showing all users with search, pagination, and offline support.
 */
@Entry
@Component
struct UserListPage {
  @State private state: UserListState = {
    isLoading: true,
    error: undefined,
    users: [],
    currentPage: 1,
    totalPages: 1,
    hasNextPage: false,
    isLoadingMore: false,
    searchQuery: '',
    filteredUsers: [],
    isOffline: false,
    syncState: { isSyncing: false, pendingCount: 0, lastSyncTime: undefined, lastSyncError: undefined },
    isEmpty: true
  };

  @State private searchText: string = '';
  @State private refreshing: boolean = false;

  private viewModel: UserListViewModel | null = null;
  private stateUnsubscribe: StateUnsubscribe<UserListState> | null = null;
  private effectUnsubscribe: EffectUnsubscribe<UserListEffect> | null = null;

  aboutToAppear(): void {
    Logger.d(TAG, 'UserListPage appearing');

    try {
      const container = getContainer();

      // Use DI factory instead of manual instantiation
      this.viewModel = container.createUserListViewModel();

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
      analytics.trackScreen('UserListPage', 'UserListPage');

      // Load users
      this.viewModel.onEvent({ type: 'LoadUsers', forceRefresh: false });
    } catch (error) {
      Logger.e(TAG, `Failed to initialize: ${error}`);
    }
  }

  aboutToDisappear(): void {
    Logger.d(TAG, 'UserListPage disappearing');

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

  private handleEffect(effect: UserListEffect): void {
    Logger.d(TAG, `Handling effect: ${effect.type}`);

    switch (effect.type) {
      case 'NavigateToDetail':
        try {
          this.getUIContext().getRouter().pushUrl({
            url: 'pages/UserDetailPage',
            params: { userId: effect.userId }
          });
        } catch (err) {
          console.error(`pushUrl error: ${err}`);
        }
        break;

      case 'NavigateToCreate':
        try {
          this.getUIContext().getRouter().pushUrl({
            url: 'pages/CreateUserPage'
          });
        } catch (err) {
          console.error(`pushUrl error: ${err}`);
        }
        break;

      case 'ShowDeleteConfirmation':
        this.showDeleteConfirmation(effect.userId);
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
    }
  }

  private showDeleteConfirmation(userId: number): void {
    try {
      // Get localized strings from resource manager
      const resourceMgr = this.getUIContext().getHostContext()?.resourceManager;
      if (!resourceMgr) return;
      const deleteTitle = resourceMgr.getStringSync($r('app.string.delete').id);
      const confirmMsg = resourceMgr.getStringSync($r('app.string.confirm_delete').id);
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
          // User confirmed delete - send through Input/Output pattern
          this.sendEvent({ type: 'ConfirmDeleteUser', userId: userId });
        }
      }).catch((err: Error) => {
        console.error(`showDialog error: ${err.message}`);
      });
    } catch (err) {
      console.error(`showDialog exception: ${err}`);
    }
  }

  private sendEvent(input: UserListInput): void {
    this.viewModel?.onEvent(input);
  }

  build() {
    Column() {
      // Header with gradient
      Column() {
        // Title and sync button
        Row() {
          // Back button
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
          .onClick(() => {
            try {
              this.getUIContext().getRouter().back();
            } catch (err) {
              console.error(`back error: ${err}`);
            }
          })

          Text($r('app.string.users'))
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .margin({ left: 12 })

          Blank()

          // Sync button
          if (this.state.syncState.pendingCount > 0) {
            Button() {
              Row() {
                Text('↻')
                  .fontSize(18)
                  .fontColor(Color.White)

                Text(`${this.state.syncState.pendingCount}`)
                  .fontSize(12)
                  .fontColor(Color.White)
                  .margin({ left: 4 })
              }
            }
            .type(ButtonType.Circle)
            .backgroundColor('rgba(255, 255, 255, 0.2)')
            .width(44)
            .height(44)
            .onClick(() => this.sendEvent({ type: 'TriggerSync' }))
          }
        }
        .width('100%')
        .padding({ top: 16, bottom: 16 })

        // Search bar
        SearchBar({
          searchText: $searchText,
          placeholderResource: $r('app.string.search_users'),
          onTextChange: (text: string) => {
            this.sendEvent({ type: 'SearchUsers', query: text });
          },
          onClear: () => {
            this.sendEvent({ type: 'ClearSearch' });
          }
        })
        .margin({ bottom: 16 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 48, bottom: 16 })
      .linearGradient({
        direction: GradientDirection.Right,
        colors: [['#7C3AED', 0], ['#A78BFA', 1]]
      })

      // Status banners
      if (this.state.isOffline) {
        OfflineBanner({ pendingSyncCount: this.state.syncState.pendingCount })
      } else if (this.state.syncState.isSyncing) {
        SyncingBanner()
      }

      // Content
      Stack() {
        if (this.state.isLoading && this.state.users.length === 0) {
          LoadingView({ messageResource: $r('app.string.loading') })
        } else if (this.state.error && this.state.users.length === 0) {
          ErrorView({
            message: this.state.error,
            showRetry: true,
            onRetry: () => this.sendEvent({ type: 'RetryLoad' })
          })
        } else if (this.state.isEmpty) {
          EmptyView({
            titleResource: $r('app.string.no_users'),
            messageResource: $r('app.string.no_users_message'),
            showAction: true,
            actionTextResource: $r('app.string.create_user'),
            onAction: () => this.sendEvent({ type: 'CreateUser' })
          })
        } else {
          // User list
          Refresh({ refreshing: $$this.refreshing }) {
            List({ space: 12 }) {
              ForEach(this.state.filteredUsers, (user: User) => {
                ListItem() {
                  UserCard({
                    user: user,
                    showSyncStatus: true,
                    isPendingSync: false,
                    onTap: () => this.sendEvent({ type: 'SelectUser', userId: user.id }),
                    onLongPress: () => this.sendEvent({ type: 'DeleteUser', userId: user.id })
                  })
                }
              }, (user: User) => user.id.toString())

              // Load more indicator
              if (this.state.isLoadingMore) {
                ListItem() {
                  InlineLoading()
                }
              }
            }
            .width('100%')
            .height('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 80 })
            .edgeEffect(EdgeEffect.Spring)
            .onReachEnd(() => {
              if (this.state.hasNextPage && !this.state.isLoadingMore) {
                this.sendEvent({ type: 'LoadNextPage' });
              }
            })
          }
          .onRefreshing(() => {
            this.sendEvent({ type: 'RefreshUsers' });
            setTimeout(() => {
              this.refreshing = false;
            }, 1500);
          })
        }
      }
      .layoutWeight(1)
      .backgroundColor('#F5F3FF')

      // FAB
      Button() {
        Image($r('sys.media.ohos_ic_public_add'))
          .width(24)
          .height(24)
          .fillColor(Color.White)
      }
      .type(ButtonType.Circle)
      .width(56)
      .height(56)
      .backgroundColor('#7C3AED')
      .shadow({
        radius: 8,
        color: 'rgba(124, 58, 237, 0.4)',
        offsetX: 0,
        offsetY: 4
      })
      .position({ x: '100%', y: '100%' })
      .translate({ x: -72, y: -72 })
      .onClick(() => this.sendEvent({ type: 'CreateUser' }))
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F3FF')
  }
}
