import { router } from '@kit.ArkUI';
import { User } from '../domain/models/User';
import { HomeViewModel, HomeState, HomeInput, HomeEffect } from '../presentation/viewmodel/HomeViewModel';
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

const TAG = 'MainPage';

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
 * Main Page with Bottom Navigation Tabs
 */
@Entry
@Component
struct MainPage {
  @State private currentIndex: number = 0;
  private tabsController: TabsController = new TabsController();

  // Home state
  @State private homeState: HomeState = {
    isLoading: true,
    error: undefined,
    totalUserCount: 0,
    loadedUserCount: 0,
    users: []
  };
  private homeViewModel: HomeViewModel | null = null;
  private homeStateUnsubscribe: StateUnsubscribe<HomeState> | null = null;
  private homeEffectUnsubscribe: EffectUnsubscribe<HomeEffect> | null = null;

  // User list state
  @State private userListState: UserListState = {
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
  private userListViewModel: UserListViewModel | null = null;
  private userListStateUnsubscribe: StateUnsubscribe<UserListState> | null = null;
  private userListEffectUnsubscribe: EffectUnsubscribe<UserListEffect> | null = null;

  aboutToAppear(): void {
    Logger.d(TAG, 'MainPage appearing');
    this.initializeHomeViewModel();
    this.initializeUserListViewModel();
  }

  aboutToDisappear(): void {
    Logger.d(TAG, 'MainPage disappearing');
    this.cleanupHomeViewModel();
    this.cleanupUserListViewModel();
  }

  private initializeHomeViewModel(): void {
    try {
      const container = getContainer();
      const repository = container.getUserRepository();
      const analytics = container.getAnalyticsService();

      this.homeViewModel = new HomeViewModel(repository, analytics);

      this.homeStateUnsubscribe = this.homeViewModel.subscribeToState((newState) => {
        this.homeState = newState;
      });

      this.homeEffectUnsubscribe = this.homeViewModel.subscribeToEffects((effect) => {
        this.handleHomeEffect(effect);
      });

      analytics.trackScreen('MainPage', 'HomePage');
      this.homeViewModel.onEvent({ type: 'LoadData' });
    } catch (error) {
      Logger.e(TAG, `Failed to initialize home: ${error}`);
    }
  }

  private initializeUserListViewModel(): void {
    try {
      const container = getContainer();
      const repository = container.getUserRepository();
      const syncManager = container.getSyncManager();
      const analytics = container.getAnalyticsService();

      this.userListViewModel = new UserListViewModel(repository, syncManager, analytics);

      this.userListStateUnsubscribe = this.userListViewModel.subscribeToState((newState) => {
        this.userListState = newState;
      });

      this.userListEffectUnsubscribe = this.userListViewModel.subscribeToEffects((effect) => {
        this.handleUserListEffect(effect);
      });

      this.userListViewModel.onEvent({ type: 'LoadUsers', forceRefresh: false });
    } catch (error) {
      Logger.e(TAG, `Failed to initialize user list: ${error}`);
    }
  }

  private cleanupHomeViewModel(): void {
    if (this.homeStateUnsubscribe !== null) {
      this.homeStateUnsubscribe.unsubscribe();
    }
    if (this.homeEffectUnsubscribe !== null) {
      this.homeEffectUnsubscribe.unsubscribe();
    }
    if (this.homeViewModel !== null) {
      this.homeViewModel.destroy();
    }
  }

  private cleanupUserListViewModel(): void {
    if (this.userListStateUnsubscribe !== null) {
      this.userListStateUnsubscribe.unsubscribe();
    }
    if (this.userListEffectUnsubscribe !== null) {
      this.userListEffectUnsubscribe.unsubscribe();
    }
    if (this.userListViewModel !== null) {
      this.userListViewModel.destroy();
    }
  }

  private handleHomeEffect(effect: HomeEffect): void {
    switch (effect.type) {
      case 'NavigateToUsers':
        this.currentIndex = 1;
        this.tabsController.changeIndex(1);
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

  private handleUserListEffect(effect: UserListEffect): void {
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
          this.userListViewModel?.onEvent({ type: 'ConfirmDeleteUser', userId: userId });
        }
      }).catch((err: Error) => {
        console.error(`showDialog error: ${err.message}`);
      });
    } catch (err) {
      console.error(`showDialog exception: ${err}`);
    }
  }

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End, controller: this.tabsController, index: this.currentIndex }) {
        // Home Tab
        TabContent() {
          this.BuildHomeContent()
        }
        .tabBar(this.BuildTabItem($r('app.string.nav_home'), $r('sys.media.ohos_ic_public_clock'), 0))

        // Users Tab
        TabContent() {
          this.BuildUsersContent()
        }
        .tabBar(this.BuildTabItem($r('app.string.nav_users'), $r('sys.media.ohos_ic_public_email'), 1))

        // Settings Tab
        TabContent() {
          this.BuildSettingsContent()
        }
        .tabBar(this.BuildTabItem($r('app.string.nav_settings'), $r('sys.media.ohos_ic_public_more'), 2))
      }
      .scrollable(false)
      .barMode(BarMode.Fixed)
      .barHeight(56)
      .animationDuration(200)
      .onChange((index: number) => {
        this.currentIndex = index;
        if (index === 1 && this.userListState.users.length === 0) {
          this.userListViewModel?.onEvent({ type: 'LoadUsers', forceRefresh: false });
        }
      })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private BuildTabItem(textResource: Resource, iconResource: Resource, index: number) {
    Column() {
      Image(iconResource)
        .width(24)
        .height(24)
        .fillColor(this.currentIndex === index ? ArcanaViolet : '#9CA3AF')

      Text(textResource)
        .fontSize(12)
        .fontColor(this.currentIndex === index ? ArcanaViolet : '#9CA3AF')
        .margin({ top: 4 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Color.White)
  }

  // ==================== HOME CONTENT ====================

  @Builder
  private BuildHomeContent() {
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

      // Decorative circles
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
        .position({ x: 30, y: '60%' })

      // Main content
      Column() {
        if (this.homeState.isLoading) {
          LoadingProgress()
            .width(48)
            .height(48)
            .color(ArcanaGold)

          Text($r('app.string.loading'))
            .fontSize(16)
            .fontColor(ArcanaGlow)
            .margin({ top: 16 })
        } else {
          // App title
          Text($r('app.string.home_title'))
            .fontSize(36)
            .fontWeight(FontWeight.Bold)
            .fontColor(ArcanaGold)
            .textAlign(TextAlign.Center)

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

            Text(`${this.homeState.totalUserCount}`)
              .fontSize(56)
              .fontWeight(FontWeight.Bold)
              .fontColor(ArcanaGold)
              .margin({ top: 8 })

            Text() {
              Span($r('app.string.loaded_users'))
              Span(`: ${this.homeState.loadedUserCount}`)
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
              Image($r('sys.media.ohos_ic_public_arrow_right'))
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
          .onClick(() => {
            this.currentIndex = 1;
            this.tabsController.changeIndex(1);
          })

          Text($r('app.string.app_version'))
            .fontSize(12)
            .fontColor('rgba(232, 228, 240, 0.5)')
            .margin({ top: 48 })
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

  // ==================== USERS CONTENT ====================

  @Builder
  private BuildUsersContent() {
    Column() {
      // Header
      Column() {
        Row() {
          Text($r('app.string.users'))
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)

          Blank()

          if (this.userListState.syncState.pendingCount > 0) {
            Button() {
              Row() {
                Text('↻')
                  .fontSize(18)
                  .fontColor(Color.White)
                Text(`${this.userListState.syncState.pendingCount}`)
                  .fontSize(12)
                  .fontColor(Color.White)
                  .margin({ left: 4 })
              }
            }
            .type(ButtonType.Circle)
            .backgroundColor('rgba(255, 255, 255, 0.2)')
            .width(44)
            .height(44)
            .onClick(() => this.userListViewModel?.onEvent({ type: 'TriggerSync' }))
          }
        }
        .width('100%')
        .padding({ top: 16, bottom: 16 })

        SearchBar({
          searchText: $searchText,
          placeholderResource: $r('app.string.search_users'),
          onTextChange: (text: string) => {
            this.userListViewModel?.onEvent({ type: 'SearchUsers', query: text });
          },
          onClear: () => {
            this.userListViewModel?.onEvent({ type: 'ClearSearch' });
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
      if (this.userListState.isOffline) {
        OfflineBanner({ pendingSyncCount: this.userListState.syncState.pendingCount })
      } else if (this.userListState.syncState.isSyncing) {
        SyncingBanner()
      }

      // Content
      Stack() {
        if (this.userListState.isLoading && this.userListState.users.length === 0) {
          LoadingView({ messageResource: $r('app.string.loading') })
        } else if (this.userListState.error && this.userListState.users.length === 0) {
          ErrorView({
            message: this.userListState.error,
            showRetry: true,
            onRetry: () => this.userListViewModel?.onEvent({ type: 'RetryLoad' })
          })
        } else if (this.userListState.isEmpty) {
          EmptyView({
            titleResource: $r('app.string.no_users'),
            messageResource: $r('app.string.no_users_message'),
            showAction: true,
            actionTextResource: $r('app.string.create_user'),
            onAction: () => this.userListViewModel?.onEvent({ type: 'CreateUser' })
          })
        } else {
          Refresh({ refreshing: $$this.refreshing }) {
            List({ space: 12 }) {
              ForEach(this.userListState.filteredUsers, (user: User) => {
                ListItem() {
                  UserCard({
                    user: user,
                    showSyncStatus: true,
                    isPendingSync: false,
                    onTap: () => this.userListViewModel?.onEvent({ type: 'SelectUser', userId: user.id }),
                    onLongPress: () => this.userListViewModel?.onEvent({ type: 'DeleteUser', userId: user.id })
                  })
                }
              }, (user: User) => user.id.toString())

              if (this.userListState.isLoadingMore) {
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
              if (this.userListState.hasNextPage && !this.userListState.isLoadingMore) {
                this.userListViewModel?.onEvent({ type: 'LoadNextPage' });
              }
            })
          }
          .onRefreshing(() => {
            this.userListViewModel?.onEvent({ type: 'RefreshUsers' });
            setTimeout(() => {
              this.refreshing = false;
            }, 1500);
          })
        }

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
        .onClick(() => this.userListViewModel?.onEvent({ type: 'CreateUser' }))
      }
      .layoutWeight(1)
      .backgroundColor('#F5F3FF')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F3FF')
  }

  // ==================== SETTINGS CONTENT ====================

  @Builder
  private BuildSettingsContent() {
    Column() {
      // Header
      Column() {
        Text($r('app.string.settings'))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 64, bottom: 24 })
      .linearGradient({
        direction: GradientDirection.Right,
        colors: [['#7C3AED', 0], ['#A78BFA', 1]]
      })

      // Settings content
      Scroll() {
        Column() {
          // Theme section
          this.BuildSettingsSection($r('app.string.theme'))

          this.BuildSettingsItem($r('app.string.dark_mode'), $r('sys.media.ohos_ic_public_camera'), () => {
            this.getUIContext().getPromptAction().showToast({ message: 'Coming soon', duration: 2000 });
          })

          // About section
          this.BuildSettingsSection($r('app.string.about'))

          this.BuildSettingsItem($r('app.string.version'), $r('sys.media.ohos_ic_public_edit'), () => {
            this.getUIContext().getPromptAction().showToast({ message: 'Version 1.0.0', duration: 2000 });
          })

          this.BuildSettingsItem($r('app.string.privacy_policy'), $r('sys.media.ohos_ic_public_fail'), () => {
            this.getUIContext().getPromptAction().showToast({ message: 'Coming soon', duration: 2000 });
          })
        }
        .width('100%')
        .padding({ top: 16, bottom: 32 })
      }
      .layoutWeight(1)
      .backgroundColor('#F5F3FF')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private BuildSettingsSection(titleResource: Resource) {
    Text(titleResource)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor('#6B7280')
      .padding({ left: 16, right: 16, top: 24, bottom: 8 })
      .width('100%')
  }

  @Builder
  private BuildSettingsItem(titleResource: Resource, iconResource: Resource, onTap: () => void) {
    Row() {
      Image(iconResource)
        .width(24)
        .height(24)
        .fillColor('#7C3AED')

      Text(titleResource)
        .fontSize(16)
        .fontColor('#1F2937')
        .margin({ left: 16 })
        .layoutWeight(1)

      Image($r('sys.media.ohos_ic_public_arrow_right'))
        .width(20)
        .height(20)
        .fillColor('#9CA3AF')
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)
    .onClick(onTap)
  }
}
