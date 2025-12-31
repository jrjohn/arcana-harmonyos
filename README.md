# Arcana HarmonyOS

A production-grade HarmonyOS 5 (NEXT) application demonstrating **Clean Architecture**, **Offline-First design**, and **ArkTS/ArkUI** best practices.

## Requirements

- **DevEco Studio**: 6.0.1.260 or later
- **HarmonyOS SDK**: API 12 (5.0.0)
- **HarmonyOS Device**: NEXT compatible device or emulator

## Overview

Arcana HarmonyOS is a user management application that showcases modern HarmonyOS development patterns. It's a port of the [Arcana Android](https://github.com/jrjohn/arcana-android) application, maintaining the same architectural principles and feature set.

### Key Features

- **Complete User Management** - CRUD operations for users
- **Offline-First Architecture** - Local database as single source of truth with background sync
- **Multi-Level Caching** - In-memory LRU cache with TTL and persistent storage
- **Real-time Validation** - Form validation with immediate user feedback
- **MVVM with Input/Output Pattern** - Clean separation of concerns
- **Analytics Integration** - Screen tracking and event analytics
- **Beautiful Purple Gradient UI** - Modern, polished design

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Pages     │  │ Components  │  │    ViewModels       │  │
│  │  (ArkUI)    │  │  (Reusable) │  │ (Input/Output/State)│  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                      Domain Layer                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Models    │  │ Validators  │  │   Interfaces        │  │
│  │ (User, etc.)│  │(Email, Name)│  │ (IUserRepository)   │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                       Data Layer                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ API Service │  │Local Storage│  │    Repository       │  │
│  │  (HTTP)     │  │(Preferences)│  │   (Offline-First)   │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                       Core Layer                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Network   │  │    Sync     │  │     Analytics       │  │
│  │  Monitor    │  │   Manager   │  │     Service         │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
entry/src/main/ets/
├── core/                       # Core infrastructure
│   ├── analytics/             # Analytics service
│   │   ├── AnalyticsService.ets
│   │   └── AnalyticsServiceImpl.ets  # Injectable implementation
│   ├── di/                    # Dependency Injection (InversifyJS-style)
│   │   ├── index.ets          # Module exports
│   │   ├── types.ets          # DI type definitions
│   │   ├── decorators.ets     # @injectable, @inject, etc.
│   │   ├── Container.ets      # IoC container
│   │   ├── tokens.ets         # Service identifiers (TYPES)
│   │   ├── interfaces.ets     # Service interfaces
│   │   ├── ContainerInitializer.ets  # Lifecycle management
│   │   └── testing.ets        # Mock implementations
│   ├── logging/               # Logger utility
│   │   ├── Logger.ets         # Static logger (legacy)
│   │   └── LoggerService.ets  # Injectable implementation
│   ├── network/               # Network monitoring
│   │   ├── NetworkMonitor.ets
│   │   └── NetworkMonitorService.ets  # Injectable implementation
│   ├── sync/                  # Background sync manager
│   │   ├── SyncManager.ets
│   │   └── SyncManagerService.ets  # Injectable implementation
│   └── navigation/            # Type-safe navigation
│       ├── index.ets          # Module exports
│       ├── Routes.ets         # Route definitions & factory
│       └── Navigator.ets      # Navigator service
├── data/                       # Data layer
│   ├── api/                   # REST API client
│   │   ├── ApiConfig.ets
│   │   ├── UserApiService.ets
│   │   ├── UserApiServiceImpl.ets  # Injectable implementation
│   │   └── dto/               # Data transfer objects
│   ├── cache/                 # LRU caching
│   ├── local/                 # Local data source
│   │   ├── UserLocalDataSource.ets
│   │   └── UserLocalDataSourceImpl.ets  # Injectable implementation
│   └── repository/            # Repository implementation
│       ├── UserRepositoryImpl.ets
│       └── UserRepositoryService.ets  # Injectable implementation
├── domain/                     # Domain layer (pure business logic)
│   ├── models/                # Domain models
│   ├── repository/            # Repository interfaces
│   ├── services/              # Service interfaces
│   └── validators/            # Input validators
├── pages/                      # UI pages
│   ├── UserListPage.ets       # Main user list
│   ├── UserDetailPage.ets     # User details
│   ├── CreateUserPage.ets     # Create user form
│   └── EditUserPage.ets       # Edit user form
└── presentation/               # Presentation layer
    ├── components/            # Reusable UI components
    └── viewmodel/             # ViewModels with I/O pattern
```

## Key Technologies

| Category | Technology |
|----------|------------|
| Language | ArkTS (TypeScript-based) |
| UI Framework | ArkUI (Declarative) |
| Architecture | Clean Architecture + MVVM |
| Network | @kit.NetworkKit (HTTP) |
| Storage | @kit.ArkData (Preferences) |
| Navigation | @kit.ArkUI (router) |
| DI | InversifyJS-style IoC Container |

## Dependency Injection

The project uses an **InversifyJS-style IoC container** custom-built for ArkTS, providing proper dependency injection with decorators and interface-based bindings.

### Core Concepts

```typescript
// 1. Define service interface
interface ILogger {
  d(tag: string, message: string): void;
  e(tag: string, message: string): void;
}

// 2. Create injectable implementation
@injectable()
class LoggerService implements ILogger {
  @postConstruct()
  initialize(): void { /* called after construction */ }

  d(tag: string, message: string): void { /* ... */ }
  e(tag: string, message: string): void { /* ... */ }
}

// 3. Inject dependencies via constructor
@injectable()
class UserRepository {
  constructor(
    @inject(TYPES.Logger) private logger: ILogger,
    @inject(TYPES.ApiService) private api: IUserApiService
  ) {}
}
```

### Service Tokens

All services are identified by symbols defined in `core/di/tokens.ets`:

```typescript
export const TYPES = {
  // Core
  Logger: Symbol.for('Logger'),
  NetworkMonitor: Symbol.for('NetworkMonitor'),
  SyncManager: Symbol.for('SyncManager'),
  AnalyticsService: Symbol.for('AnalyticsService'),

  // Data Layer
  UserRepository: Symbol.for('UserRepository'),
  UserApiService: Symbol.for('UserApiService'),
  UserLocalDataSource: Symbol.for('UserLocalDataSource'),
};
```

### Container Setup

```typescript
// In EntryAbility.ets
import { ContainerInitializer } from './core/di';

async onCreate() {
  const initializer = ContainerInitializer.getInstance(this.context);
  await initializer.initialize();
}
```

### Resolving Services

```typescript
// Option 1: From container directly
const logger = container.get<ILogger>(TYPES.Logger);

// Option 2: Global accessors
import { getLogger, getUserRepository } from './core/di';
const logger = getLogger();
const repo = getUserRepository();

// Option 3: Generic resolve
import { resolve } from './core/di';
const service = resolve<IMyService>(TYPES.MyService);
```

### Binding Scopes

| Scope | Description |
|-------|-------------|
| `inSingletonScope()` | One instance shared across all resolutions |
| `inTransientScope()` | New instance created for each resolution |
| `inRequestScope()` | One instance per request context |

```typescript
// Singleton (default for services)
container.bind<ILogger>(TYPES.Logger)
  .to(LoggerService)
  .inSingletonScope();

// Transient (new instance each time)
container.bind<IValidator>(TYPES.Validator)
  .to(UserValidator)
  .inTransientScope();

// Constant value
container.bind<IConfig>(TYPES.Config)
  .toConstantValue({ apiUrl: 'https://...' });
```

### Available Decorators

| Decorator | Purpose |
|-----------|---------|
| `@injectable()` | Marks class as injectable |
| `@inject(token)` | Constructor parameter injection |
| `@injectProperty(token)` | Property injection |
| `@postConstruct()` | Method called after injection complete |
| `@preDestroy()` | Method called before disposal |
| `@optional()` | Marks dependency as optional |
| `@multiInject(token)` | Injects array of all bindings |

### Testing with Mocks

```typescript
import { createTestContainer, MockLogger, MockNetworkMonitor } from './core/di/testing';

// Create container with all mocks
const container = createTestContainer();

// Get mock implementations
const logger = container.get<ILogger>(TYPES.Logger) as MockLogger;
const network = container.get<INetworkMonitor>(TYPES.NetworkMonitor) as MockNetworkMonitor;

// Control mock behavior
network.setOnline(false);  // Simulate offline

// Verify interactions
expect(logger.hasLog('ERROR', 'Network failed')).toBe(true);
```

### DI File Structure

```
core/di/
├── index.ets              # Module exports
├── types.ets              # Type definitions
├── decorators.ets         # @injectable, @inject, etc.
├── Container.ets          # IoC container implementation
├── tokens.ets             # Service identifiers (TYPES)
├── interfaces.ets         # Service interfaces
├── ContainerInitializer.ets  # App lifecycle + global access
└── testing.ets            # Mock implementations
```

## Type-Safe Navigation

The project implements a **type-safe navigation pattern** inspired by Jetpack Compose Navigation Safe Args, providing compile-time route validation.

### Route Definitions

```typescript
// Routes are defined as classes with typed parameters
class UserDetailRoute implements Route<UserDetailParams> {
  readonly type: RouteType = 'UserDetail';
  readonly path = 'pages/UserDetailPage';

  constructor(public readonly params: UserDetailParams) {}
}

// Parameters are strongly typed
class UserDetailParams implements RouteParams {
  constructor(public readonly userId: number) {}

  static fromRecord(record: Record<string, string>): UserDetailParams {
    const userId = parseInt(record['userId'] || '0', 10);
    if (isNaN(userId)) throw new Error('Invalid userId');
    return new UserDetailParams(userId);
  }
}
```

### Route Factory

```typescript
import { Routes } from './core/navigation';

// Type-safe route creation - compiler validates parameters
Routes.userList()           // UserListRoute
Routes.userDetail(123)      // UserDetailRoute with userId
Routes.createUser()         // CreateUserRoute
Routes.editUser(456)        // EditUserRoute with userId
```

### Navigator Usage

```typescript
import { Navigator, Routes } from './core/navigation';

// Inject navigator
const navigator = container.get<INavigator>(TYPES.Navigator);

// Navigate with full type safety
await navigator.navigate(Routes.userDetail(userId));
await navigator.navigate(Routes.createUser());

// Convenience methods
await navigator.toUserDetail(userId);
await navigator.toCreateUser();
await navigator.back();
```

### Extracting Parameters in Pages

```typescript
import { NavParams } from './core/navigation';

@Entry
@Component
struct UserDetailPage {
  @State userId: number = 0;

  aboutToAppear() {
    // Type-safe parameter extraction
    const userId = NavParams.getUserId();
    if (userId) {
      this.userId = userId;
      this.loadUser(userId);
    }
  }
}
```

### Navigation File Structure

```
core/navigation/
├── index.ets          # Module exports
├── Routes.ets         # Route definitions & factory
└── Navigator.ets      # Navigator service
```

### Benefits

| Feature | Description |
|---------|-------------|
| Compile-time safety | Invalid routes/params caught at build time |
| Type guards | `isUserDetailRoute(route)` for pattern matching |
| Parameter validation | `fromRecord()` validates URL params |
| Analytics integration | Automatic screen tracking on navigation |
| Testable | Navigator can be mocked for unit tests |

## Input/Output ViewModel Pattern

ViewModels follow a strict Input/Output pattern:

```typescript
// Input - User actions
type UserListInput =
  | { type: 'LoadUsers'; forceRefresh: boolean }
  | { type: 'SelectUser'; userId: number }
  | { type: 'CreateUser' };

// State - Observable UI state
interface UserListState extends BaseState {
  users: User[];
  isLoading: boolean;
  error: string | undefined;
}

// Effect - One-time side effects
type UserListEffect =
  | { type: 'NavigateToDetail'; userId: number }
  | { type: 'ShowMessage'; message: string };
```

## Offline-First Strategy

1. **Local First**: All reads prioritize local cache
2. **Optimistic Updates**: Changes applied locally immediately
3. **Background Sync**: Network sync happens in background
4. **Conflict Resolution**: Server wins with local fallback
5. **Sync Queue**: Failed operations queued for retry

## API

Uses [reqres.in](https://reqres.in) as the test API backend.

```
Base URL: https://reqres.in/api
API Key: reqres_30bb4b25423642c18ddde61de8cadc40

Endpoints:
- GET /users?page={page}     - List users
- GET /users/{id}            - Get user
- POST /users                - Create user
- PUT /users/{id}            - Update user
- DELETE /users/{id}         - Delete user
```

## Getting Started

### Prerequisites

- DevEco Studio 6.0.1.260 or later
- HarmonyOS SDK API 12 (5.0.0)
- HarmonyOS NEXT device or emulator

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/jrjohn/arcana-harmonyos.git
   ```

2. Open in DevEco Studio

3. Wait for project sync to complete

4. Replace placeholder icons in:
   - `entry/src/main/resources/base/media/startIcon.png`
   - `entry/src/main/resources/base/media/background.png`
   - `entry/src/main/resources/base/media/foreground.png`
   - `AppScope/resources/base/media/app_icon.png`

5. Run on device or emulator

## Feature Comparison with Android

| Feature | Android | HarmonyOS |
|---------|---------|-----------|
| Architecture | Clean Architecture | Clean Architecture |
| UI Framework | Jetpack Compose | ArkUI |
| ViewModel Pattern | Input/Output | Input/Output |
| DI Framework | Hilt | InversifyJS-style IoC |
| Database | Room | Preferences |
| Network | Ktorfit | @kit.NetworkKit |
| Background Sync | WorkManager | SyncManager |
| Caching | StateFlow + LRU | LruCache |
| Validation | Domain validators | Domain validators |
| Analytics | AOP-based | Event-based |

## Screens

### User List
- Search functionality
- Pull-to-refresh
- Infinite scroll pagination
- Offline mode indicator
- Sync status display

### User Detail
- Full user information
- Edit and delete options
- Loading and error states

### Create/Edit User
- Real-time validation
- Unsaved changes warning
- Optimistic UI updates

## License

Apache License 2.0

## Credits

Based on [Arcana Android](https://github.com/jrjohn/arcana-android) architecture.
