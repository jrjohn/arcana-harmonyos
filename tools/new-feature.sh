#!/usr/bin/env bash
# Scaffold one vertical feature slice in the template's four layers (AGENTS.md §1).
#
#   tools/new-feature.sh Invoice
#   tools/new-feature.sh PurchaseOrder
#
# Creates (Name=Invoice), all under entry/src/main/ets/:
#   domain/models/Invoice.ets                          entity + InvoiceFactory (pure, no @kit)
#   domain/repository/InvoiceRepository.ets            IInvoiceRepository (data-layer contract)
#   domain/services/InvoiceService.ets                 IInvoiceService (the only thing a ViewModel sees)
#   domain/services/impl/InvoiceServiceImpl.ets        validation + delegation to the repository
#   data/local/InvoiceLocalDataSource.ets              IInvoiceLocalDataSource
#   data/local/impl/InvoiceLocalDataSourceImpl.ets     in-memory store (swap for RDB like UserLocalDataSourceRdbImpl)
#   data/repository/InvoiceRepositoryImpl.ets          implements IInvoiceRepository over the data source
#   presentation/viewmodel/InvoiceListViewModel.ets    Input / State / Effect ViewModel (BaseViewModel)
#   pages/InvoiceListPage.ets                          @Entry page: renders state, sends inputs, handles effects
# Tests under entry/src/ohosTest/ets/test/: domain/InvoiceService.test.ets and
# presentation/InvoiceListViewModel.test.ets, registered in List.test.ets (hypium, on device)
# and jest-tests/run-all.test.ts (the Jenkins "Jest Coverage" lane).
# Anchors edited: core/di/tokens.ets (2 tokens), core/di/AppContainer.ets (the ONLY place the
# *Impl classes are constructed: imports, bindings, get<Name>Service(), create<Name>ListViewModel()),
# core/navigation/Routes.ets (<Name>List route everywhere the other routes are listed),
# resources/base/profile/main_pages.json.
# Every anchor must match exactly once, or the script stops before writing anything.
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <PascalCaseName>   e.g. $0 Invoice" >&2; exit 1; }
NAME="$1"
[[ "$NAME" =~ ^[A-Z][a-z0-9]+([A-Z][a-z0-9]+)*$ ]] || { echo "name must be PascalCase (Invoice, PurchaseOrder)" >&2; exit 1; }
case "$NAME" in User|Home|Main|Base) echo "$NAME already exists in the template" >&2; exit 1 ;; esac
command -v perl >/dev/null || { echo "perl is required" >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
CAMEL="$(printf '%s' "$NAME" | perl -pe 's/^([A-Z])/lc($1)/e')"
WORDS="$(printf '%s' "$NAME" | perl -pe 's/(?<!^)([A-Z])/ $1/g')"     # PurchaseOrder → Purchase Order

E=entry/src/main/ets
T=entry/src/ohosTest/ets/test
TOKENS=$E/core/di/tokens.ets
CONTAINER=$E/core/di/AppContainer.ets
ROUTES=$E/core/navigation/Routes.ets
PAGES=entry/src/main/resources/base/profile/main_pages.json
LIST=$T/List.test.ets
JEST=jest-tests/run-all.test.ts

NEW_FILES=(
    "$E/domain/models/${NAME}.ets"
    "$E/domain/repository/${NAME}Repository.ets"
    "$E/domain/services/${NAME}Service.ets"
    "$E/domain/services/impl/${NAME}ServiceImpl.ets"
    "$E/data/local/${NAME}LocalDataSource.ets"
    "$E/data/local/impl/${NAME}LocalDataSourceImpl.ets"
    "$E/data/repository/${NAME}RepositoryImpl.ets"
    "$E/presentation/viewmodel/${NAME}ListViewModel.ets"
    "$E/pages/${NAME}ListPage.ets"
    "$T/domain/${NAME}Service.test.ets"
    "$T/presentation/${NAME}ListViewModel.test.ets"
)
for f in "${NEW_FILES[@]}"; do
    [ ! -e "$f" ] || { echo "new-feature: $f already exists — refusing to overwrite" >&2; exit 1; }
done

# ---- Anchors: "file<TAB>exact text". Each must occur exactly once (checked before any write).
ANCHORS=(
    "$TOKENS	  UserService: string;"
    "$TOKENS	  readonly UserService: string = 'UserService';"
    "$CONTAINER	import { UserFormViewModel } from '../../presentation/viewmodel/UserFormViewModel';"
    "$CONTAINER	      // Bind sync manager (depends on repository)"
    "$CONTAINER	  // ===== ViewModel Factories ====="
    "$CONTAINER	  // Factory methods create ViewModels with proper DI (not registered as singletons)"
    "$ROUTES	  | 'EditUser';"
    "$ROUTES	  | EditUserRoute;"
    "$ROUTES	  editUser(userId: number): EditUserRoute;"
    "$ROUTES	  /** Parse route from URL path */"
    "$ROUTES	    return undefined;"
    "$ROUTES	 * Union of all routes for type-safe navigation"
    "$ROUTES	// ===== Screen Names for Analytics ====="
    "$ROUTES	    ['EditUser', 'Edit User']"
    "$PAGES	    \"pages/EditUserPage\""
    "$LIST	import UserDetailViewModelTest from './presentation/UserDetailViewModel.test';"
    "$LIST	  UserDetailViewModelTest();"
    "$JEST	import UserDtoTest from '../entry/src/ohosTest/ets/test/data/UserDto.test.ts';"
    "$JEST	UserDtoTest();"
)
for a in "${ANCHORS[@]}"; do
    file="${a%%	*}"; text="${a#*	}"
    [ -f "$file" ] || { echo "new-feature: anchor file $file missing — the template changed; update tools/new-feature.sh" >&2; exit 1; }
    n="$(ANCHOR="$text" perl -0ne '$n = () = /\Q$ENV{ANCHOR}\E/g; print $n' "$file")"
    [ "$n" = "1" ] || { echo "new-feature: anchor found $n times (need exactly 1) in $file: $text" >&2; exit 1; }
done

# insert FILE ANCHOR before|after TEXT — TEXT goes on its own line(s) next to the anchor's line.
insert() {
    local file="$1" anchor="$2" where="$3" text="$4"
    ANCHOR="$anchor" TEXT="$text" WHERE="$where" perl -0pi -e '
        my ($a, $t) = ($ENV{ANCHOR}, $ENV{TEXT});
        if ($ENV{WHERE} eq "before") { s/^(.*?\Q$a\E)/$t\n$1/m or die "anchor lost: $a\n" }
        else                         { s/(\Q$a\E[^\n]*\n)/$1$t\n/  or die "anchor lost: $a\n" }
    ' "$file"
}
# render TEMPLATE-ON-STDIN DEST — replaces __Name__, __name__, __Words__.
render() {
    mkdir -p "$(dirname "$1")"
    perl -pe "s/__Name__/${NAME}/g; s/__name__/${CAMEL}/g; s/__Words__/${WORDS}/g" > "$1"
}

# ================================================================ domain
render "$E/domain/models/${NAME}.ets" <<'EOT'
/**
 * Domain model for __Words__ (generated by tools/new-feature.sh).
 * Pure domain type: no framework (@kit) imports.
 */
export interface __Name__ {
  readonly id: number;
  readonly title: string;
  readonly amount: number;
  readonly createdAt: number;
}

/**
 * Creates __Name__ values (ArkTS: no object literal without a declared type).
 */
export class __Name__Factory {
  static create(id: number, title: string, amount: number, createdAt: number): __Name__ {
    const item: __Name__ = { id: id, title: title, amount: amount, createdAt: createdAt };
    return item;
  }
}
EOT

render "$E/domain/repository/${NAME}Repository.ets" <<'EOT'
import { __Name__ } from '../models/__Name__';
import { Result } from '../models/Result';
import { AppError } from '../models/AppError';

/**
 * Repository contract for __Words__ data. Implemented in data/repository/__Name__RepositoryImpl.ets;
 * only core/di/AppContainer.ets constructs the implementation.
 */
export interface I__Name__Repository {
  getAll(forceRefresh: boolean): Promise<Result<__Name__[], AppError>>;
  getById(id: number): Promise<Result<__Name__, AppError>>;
  create(title: string, amount: number): Promise<Result<__Name__, AppError>>;
}
EOT

render "$E/domain/services/${NAME}Service.ets" <<'EOT'
import { __Name__ } from '../models/__Name__';
import { Result } from '../models/Result';
import { AppError } from '../models/AppError';

/**
 * Domain service interface for __Words__ operations.
 * ViewModels depend on this interface only (resolved through AppContainer).
 */
export interface I__Name__Service {
  get__Name__s(forceRefresh: boolean): Promise<Result<__Name__[], AppError>>;
  get__Name__ById(id: number): Promise<Result<__Name__, AppError>>;
  create__Name__(title: string, amount: number): Promise<Result<__Name__, AppError>>;
}
EOT

render "$E/domain/services/impl/${NAME}ServiceImpl.ets" <<'EOT'
/**
 * __Name__ServiceImpl - domain service implementation for __Words__.
 * Validates input, then delegates data access to I__Name__Repository.
 */

import { injectable } from '../../../core/di/decorators';
import { I__Name__Service } from '../__Name__Service';
import { I__Name__Repository } from '../../repository/__Name__Repository';
import { __Name__ } from '../../models/__Name__';
import { Result, ResultFactory } from '../../models/Result';
import { AppError, AppErrorFactory } from '../../models/AppError';
import { Logger } from '../../../core/logging/Logger';

const TAG = '__Name__ServiceImpl';

@injectable()
export class __Name__ServiceImpl implements I__Name__Service {
  private repository: I__Name__Repository;

  constructor(repository: I__Name__Repository) {
    this.repository = repository;
    Logger.d(TAG, '__Name__ServiceImpl initialized');
  }

  async get__Name__s(forceRefresh: boolean): Promise<Result<__Name__[], AppError>> {
    Logger.d(TAG, `get__Name__s forceRefresh=${forceRefresh}`);
    return this.repository.getAll(forceRefresh);
  }

  async get__Name__ById(id: number): Promise<Result<__Name__, AppError>> {
    if (id <= 0) {
      return ResultFactory.failure(AppErrorFactory.validationError('id', 'Id must be positive'));
    }
    return this.repository.getById(id);
  }

  async create__Name__(title: string, amount: number): Promise<Result<__Name__, AppError>> {
    const trimmed = title.trim();
    if (trimmed.length === 0) {
      return ResultFactory.failure(AppErrorFactory.validationError('title', 'Title is required'));
    }
    if (Number.isNaN(amount) || amount <= 0) {
      return ResultFactory.failure(AppErrorFactory.validationError('amount', 'Amount must be greater than 0'));
    }
    return this.repository.create(trimmed, amount);
  }
}
EOT

# ================================================================ data
render "$E/data/local/${NAME}LocalDataSource.ets" <<'EOT'
import { __Name__ } from '../../domain/models/__Name__';

/**
 * Local (offline) store for __Words__. Implementation: data/local/impl/__Name__LocalDataSourceImpl.ets.
 */
export interface I__Name__LocalDataSource {
  getAll(): Promise<__Name__[]>;
  getById(id: number): Promise<__Name__ | undefined>;
  save(item: __Name__): Promise<void>;
  nextId(): Promise<number>;
}
EOT

render "$E/data/local/impl/${NAME}LocalDataSourceImpl.ets" <<'EOT'
import { __Name__ } from '../../../domain/models/__Name__';
import { I__Name__LocalDataSource } from '../__Name__LocalDataSource';

/**
 * In-memory __Words__ store. Replace the Map with RelationalStore (see
 * UserLocalDataSourceRdbImpl.ets) when the data must survive a restart; keep the interface.
 */
export class __Name__LocalDataSourceImpl implements I__Name__LocalDataSource {
  private items: Map<number, __Name__> = new Map<number, __Name__>();
  private lastId: number = 0;

  async getAll(): Promise<__Name__[]> {
    const list: __Name__[] = Array.from(this.items.values());
    list.sort((a: __Name__, b: __Name__): number => b.createdAt - a.createdAt);
    return list;
  }

  async getById(id: number): Promise<__Name__ | undefined> {
    return this.items.get(id);
  }

  async save(item: __Name__): Promise<void> {
    this.items.set(item.id, item);
    if (item.id > this.lastId) {
      this.lastId = item.id;
    }
  }

  async nextId(): Promise<number> {
    this.lastId = this.lastId + 1;
    return this.lastId;
  }
}
EOT

render "$E/data/repository/${NAME}RepositoryImpl.ets" <<'EOT'
import { __Name__, __Name__Factory } from '../../domain/models/__Name__';
import { I__Name__Repository } from '../../domain/repository/__Name__Repository';
import { Result, ResultFactory } from '../../domain/models/Result';
import { AppError, AppErrorFactory } from '../../domain/models/AppError';
import { I__Name__LocalDataSource } from '../local/__Name__LocalDataSource';
import { Logger } from '../../core/logging/Logger';

const TAG = '__Name__RepositoryImpl';

/**
 * Offline-first __Words__ repository: reads and writes go to the local data source.
 * Add a remote source the way UserRepositoryImpl does (data/api + sync queue) — never call
 * the network from the ViewModel or the page.
 */
export class __Name__RepositoryImpl implements I__Name__Repository {
  private local: I__Name__LocalDataSource;

  constructor(local: I__Name__LocalDataSource) {
    this.local = local;
  }

  async getAll(forceRefresh: boolean): Promise<Result<__Name__[], AppError>> {
    try {
      Logger.d(TAG, `getAll forceRefresh=${forceRefresh}`);
      const items = await this.local.getAll();
      return ResultFactory.success(items);
    } catch (error) {
      return ResultFactory.failure(AppErrorFactory.databaseError('getAll', error instanceof Error ? error : undefined));
    }
  }

  async getById(id: number): Promise<Result<__Name__, AppError>> {
    try {
      const item = await this.local.getById(id);
      if (item === undefined) {
        return ResultFactory.failure(AppErrorFactory.apiNotFound('__Name__'));
      }
      return ResultFactory.success(item);
    } catch (error) {
      return ResultFactory.failure(AppErrorFactory.databaseError('getById', error instanceof Error ? error : undefined));
    }
  }

  async create(title: string, amount: number): Promise<Result<__Name__, AppError>> {
    try {
      const id = await this.local.nextId();
      const item = __Name__Factory.create(id, title, amount, Date.now());
      await this.local.save(item);
      return ResultFactory.success(item);
    } catch (error) {
      return ResultFactory.failure(AppErrorFactory.databaseError('create', error instanceof Error ? error : undefined));
    }
  }
}
EOT

# ================================================================ presentation
render "$E/presentation/viewmodel/${NAME}ListViewModel.ets" <<'EOT'
import { BaseViewModel, BaseState, BaseEffect } from './BaseViewModel';
import { __Name__ } from '../../domain/models/__Name__';
import { I__Name__Service } from '../../domain/services/__Name__Service';
import { IAnalyticsService } from '../../core/di/interfaces';
import { Success, Failure } from '../../domain/models/Result';
import { AppError } from '../../domain/models/AppError';
import { Logger } from '../../core/logging/Logger';

const TAG = '__Name__ListViewModel';

// ===== Input Events =====

export interface Load__Name__sInput {
  type: 'Load__Name__s';
}

export interface Refresh__Name__sInput {
  type: 'Refresh__Name__s';
}

export interface Create__Name__Input {
  type: 'Create__Name__';
  title: string;
  amount: number;
}

export interface Select__Name__Input {
  type: 'Select__Name__';
  id: number;
}

export type __Name__ListInput =
  | Load__Name__sInput
  | Refresh__Name__sInput
  | Create__Name__Input
  | Select__Name__Input;

// ===== State =====

export interface __Name__ListState extends BaseState {
  items: __Name__[];
  isSaving: boolean;
}

// ===== Effects =====

export interface __Name__ShowMessageEffect extends BaseEffect {
  type: 'ShowMessage';
  message: string;
}

export interface __Name__ShowErrorEffect extends BaseEffect {
  type: 'ShowError';
  message: string;
}

export interface __Name__SelectedEffect extends BaseEffect {
  type: '__Name__Selected';
  id: number;
}

export type __Name__ListEffect =
  | __Name__ShowMessageEffect
  | __Name__ShowErrorEffect
  | __Name__SelectedEffect;

/**
 * ViewModel for the __Words__ list screen (Input -> State / Effect).
 * Created by AppContainer.create__Name__ListViewModel(); never constructs services itself.
 */
export class __Name__ListViewModel extends BaseViewModel<__Name__ListInput, __Name__ListState, __Name__ListEffect> {
  private service: I__Name__Service;
  private analytics: IAnalyticsService;

  constructor(service: I__Name__Service, analytics: IAnalyticsService) {
    super({
      isLoading: false,
      error: undefined,
      items: [],
      isSaving: false
    });
    this.service = service;
    this.analytics = analytics;

    const loadInput: Load__Name__sInput = { type: 'Load__Name__s' };
    this.onEvent(loadInput);
  }

  protected updateState(state: __Name__ListState): void {
    this.setStateDirectly(state);
  }

  protected setLoading(isLoading: boolean): void {
    this._state.isLoading = isLoading;
    this.notifyStateChangeInternal();
  }

  protected setError(error: string | undefined): void {
    this._state.error = error;
    this._state.isLoading = false;
    this.notifyStateChangeInternal();
  }

  protected clearError(): void {
    this._state.error = undefined;
    this.notifyStateChangeInternal();
  }

  private notifyStateChangeInternal(): void {
    this.replaceState(this.copyCurrentState());
  }

  private copyCurrentState(): __Name__ListState {
    const copy: __Name__ListState = {
      isLoading: this._state.isLoading,
      error: this._state.error,
      items: this._state.items,
      isSaving: this._state.isSaving
    };
    return copy;
  }

  onEvent(input: __Name__ListInput): void {
    Logger.d(TAG, `Received event: ${input.type}`);

    switch (input.type) {
      case 'Load__Name__s':
        this.load(false);
        break;

      case 'Refresh__Name__s':
        this.load(true);
        break;

      case 'Create__Name__':
        this.create(input.title, input.amount);
        break;

      case 'Select__Name__':
        this.select(input.id);
        break;
    }
  }

  private async load(forceRefresh: boolean): Promise<void> {
    this.setLoading(true);
    this.clearError();

    const result = await this.service.get__Name__s(forceRefresh);

    if (result.isSuccess) {
      const successResult = result as Success<__Name__[]>;
      this._state.isLoading = false;
      this._state.items = successResult.value;
      this.notifyStateChangeInternal();
    } else {
      const failureResult = result as Failure<AppError>;
      this.setError(failureResult.error.userMessage);
      this.analytics.trackError(failureResult.error.code, failureResult.error.message);
    }
  }

  private async create(title: string, amount: number): Promise<void> {
    this._state.isSaving = true;
    this.notifyStateChangeInternal();

    const result = await this.service.create__Name__(title, amount);

    this._state.isSaving = false;
    if (result.isSuccess) {
      const successResult = result as Success<__Name__>;
      const items: __Name__[] = [successResult.value];
      this._state.items = items.concat(this._state.items);
      this.notifyStateChangeInternal();
      this.analytics.trackEvent('__name___created');
      const effect: __Name__ShowMessageEffect = { type: 'ShowMessage', message: '__Words__ created' };
      this.emitEffect(effect);
    } else {
      const failureResult = result as Failure<AppError>;
      this.notifyStateChangeInternal();
      const effect: __Name__ShowErrorEffect = { type: 'ShowError', message: failureResult.error.userMessage };
      this.emitEffect(effect);
    }
  }

  private select(id: number): void {
    this.analytics.trackAction('__name___selected', `__name___${id}`);
    const effect: __Name__SelectedEffect = { type: '__Name__Selected', id: id };
    this.emitEffect(effect);
  }
}
EOT

render "$E/pages/${NAME}ListPage.ets" <<'EOT'
import { __Name__ } from '../domain/models/__Name__';
import {
  __Name__ListViewModel,
  __Name__ListState,
  __Name__ListInput,
  __Name__ListEffect,
  Create__Name__Input,
  Refresh__Name__sInput,
  Select__Name__Input
} from '../presentation/viewmodel/__Name__ListViewModel';
import { StateUnsubscribe, EffectUnsubscribe } from '../presentation/viewmodel/BaseViewModel';
import { getContainer } from '../core/di/AppContainer';
import { LoadingView } from '../presentation/components/LoadingView';
import { ErrorView } from '../presentation/components/ErrorView';
import { Logger } from '../core/logging/Logger';

const TAG = '__Name__ListPage';

/**
 * __Words__ list page. Renders ViewModel state and forwards user actions as inputs;
 * no service or repository access here.
 */
@Entry
@Component
struct __Name__ListPage {
  @State private state: __Name__ListState = {
    isLoading: true,
    error: undefined,
    items: [],
    isSaving: false
  };
  @State private titleText: string = '';
  @State private amountText: string = '';

  private viewModel: __Name__ListViewModel | null = null;
  private stateUnsubscribe: StateUnsubscribe<__Name__ListState> | null = null;
  private effectUnsubscribe: EffectUnsubscribe<__Name__ListEffect> | null = null;

  aboutToAppear(): void {
    try {
      const container = getContainer();
      this.viewModel = container.create__Name__ListViewModel();
      this.stateUnsubscribe = this.viewModel.subscribeToState((newState: __Name__ListState) => {
        this.state = newState;
      });
      this.effectUnsubscribe = this.viewModel.subscribeToEffects((effect: __Name__ListEffect) => {
        this.handleEffect(effect);
      });
      container.getAnalyticsService().trackScreen('__Name__ListPage', '__Name__ListPage');
    } catch (error) {
      Logger.e(TAG, `Failed to initialize: ${error}`);
    }
  }

  aboutToDisappear(): void {
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

  private handleEffect(effect: __Name__ListEffect): void {
    switch (effect.type) {
      case 'ShowMessage':
      case 'ShowError':
        try {
          this.getUIContext().getPromptAction().showToast({ message: effect.message, duration: 2000 });
        } catch (err) {
          Logger.e(TAG, `showToast error: ${err}`);
        }
        break;

      case '__Name__Selected':
        Logger.d(TAG, `selected ${effect.id}`);
        break;
    }
  }

  private sendEvent(input: __Name__ListInput): void {
    this.viewModel?.onEvent(input);
  }

  private submit(): void {
    const input: Create__Name__Input = {
      type: 'Create__Name__',
      title: this.titleText,
      amount: Number.parseFloat(this.amountText)
    };
    this.sendEvent(input);
    this.titleText = '';
    this.amountText = '';
  }

  build() {
    Column() {
      Text('__Words__')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 48, bottom: 12 })

      Row() {
        TextInput({ placeholder: 'Title', text: this.titleText })
          .layoutWeight(1)
          .onChange((value: string) => {
            this.titleText = value;
          })
        TextInput({ placeholder: 'Amount', text: this.amountText })
          .width(100)
          .margin({ left: 8 })
          .type(InputType.Number)
          .onChange((value: string) => {
            this.amountText = value;
          })
        Button('Add')
          .margin({ left: 8 })
          .enabled(!this.state.isSaving)
          .onClick(() => this.submit())
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      if (this.state.isLoading) {
        LoadingView()
      } else if (this.state.error !== undefined) {
        ErrorView({
          message: this.state.error,
          onRetry: () => {
            const input: Refresh__Name__sInput = { type: 'Refresh__Name__s' };
            this.sendEvent(input);
          }
        })
      } else {
        List() {
          ForEach(this.state.items, (item: __Name__) => {
            ListItem() {
              Row() {
                Text(item.title).layoutWeight(1)
                Text(item.amount.toFixed(2))
              }
              .width('100%')
              .padding(16)
              .onClick(() => {
                const input: Select__Name__Input = { type: 'Select__Name__', id: item.id };
                this.sendEvent(input);
              })
            }
          }, (item: __Name__) => item.id.toString())
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
  }
}
EOT

# ================================================================ tests
render "$T/domain/${NAME}Service.test.ets" <<'EOT'
/**
 * Unit Tests for __Name__ServiceImpl over the real repository + in-memory data source.
 */

import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { __Name__ServiceImpl } from '../../../../main/ets/domain/services/impl/__Name__ServiceImpl';
import { __Name__RepositoryImpl } from '../../../../main/ets/data/repository/__Name__RepositoryImpl';
import { __Name__LocalDataSourceImpl } from '../../../../main/ets/data/local/impl/__Name__LocalDataSourceImpl';
import { __Name__ } from '../../../../main/ets/domain/models/__Name__';
import { Success, Failure } from '../../../../main/ets/domain/models/Result';
import { AppError } from '../../../../main/ets/domain/models/AppError';

export default function __Name__ServiceTest() {
  describe('__Name__ServiceImpl', () => {
    let service: __Name__ServiceImpl;

    beforeEach(() => {
      service = new __Name__ServiceImpl(new __Name__RepositoryImpl(new __Name__LocalDataSourceImpl()));
    });

    it('creates and lists an item', async () => {
      const created = await service.create__Name__('  First  ', 12.5);
      expect(created.isSuccess).assertTrue();
      const item = (created as Success<__Name__>).value;
      expect(item.title).assertEqual('First');
      expect(item.amount).assertEqual(12.5);

      const listed = await service.get__Name__s(false);
      expect((listed as Success<__Name__[]>).value.length).assertEqual(1);
    });

    it('rejects an empty title', async () => {
      const result = await service.create__Name__('   ', 1);
      expect(result.isSuccess).assertFalse();
      expect((result as Failure<AppError>).error.message.length > 0).assertTrue();
    });

    it('rejects a non-positive amount', async () => {
      const result = await service.create__Name__('Title', 0);
      expect(result.isSuccess).assertFalse();
    });

    it('returns not-found for an unknown id', async () => {
      const result = await service.get__Name__ById(42);
      expect(result.isSuccess).assertFalse();
    });

    it('finds a created item by id', async () => {
      const created = await service.create__Name__('Second', 3);
      const id = (created as Success<__Name__>).value.id;
      const found = await service.get__Name__ById(id);
      expect((found as Success<__Name__>).value.title).assertEqual('Second');
    });
  });
}
EOT

render "$T/presentation/${NAME}ListViewModel.test.ets" <<'EOT'
/**
 * Unit Tests for __Name__ListViewModel (Input -> State / Effect) with a mocked service.
 */

import { describe, it, expect, beforeEach } from '@ohos/hypium';
import {
  __Name__ListViewModel,
  __Name__ListEffect,
  Create__Name__Input,
  Select__Name__Input
} from '../../../../main/ets/presentation/viewmodel/__Name__ListViewModel';
import { I__Name__Service } from '../../../../main/ets/domain/services/__Name__Service';
import { __Name__, __Name__Factory } from '../../../../main/ets/domain/models/__Name__';
import { Result, ResultFactory } from '../../../../main/ets/domain/models/Result';
import { AppError, AppErrorFactory } from '../../../../main/ets/domain/models/AppError';
import { IAnalyticsService, AnalyticsProps } from '../../../../main/ets/core/di/interfaces';
import { AnalyticsTimer } from '../../../../main/ets/core/analytics/AnalyticsService';

class Mock__Name__Service implements I__Name__Service {
  items: __Name__[] = [];
  shouldFail: boolean = false;

  async get__Name__s(forceRefresh: boolean): Promise<Result<__Name__[], AppError>> {
    if (this.shouldFail) {
      return ResultFactory.failure(AppErrorFactory.networkError('Mock error'));
    }
    return ResultFactory.success(this.items);
  }

  async get__Name__ById(id: number): Promise<Result<__Name__, AppError>> {
    return ResultFactory.failure(AppErrorFactory.apiNotFound('__Name__'));
  }

  async create__Name__(title: string, amount: number): Promise<Result<__Name__, AppError>> {
    if (title.length === 0) {
      return ResultFactory.failure(AppErrorFactory.validationError('title', 'Title is required'));
    }
    return ResultFactory.success(__Name__Factory.create(this.items.length + 1, title, amount, 1));
  }
}

class NoopTimer implements AnalyticsTimer {
  end(): void {}
}

class MockAnalyticsService implements IAnalyticsService {
  async initialize(): Promise<void> {}
  trackScreen(screenName: string, screenClass?: string): void {}
  trackEvent(name: string, properties?: AnalyticsProps): void {}
  trackAction(action: string, target: string, properties?: AnalyticsProps): void {}
  trackError(errorCode: string, errorMessage: string, properties?: AnalyticsProps): void {}
  trackPerformance(metric: string, value: number, unit?: string): void {}
  startTiming(operationName: string): AnalyticsTimer {
    return new NoopTimer();
  }
  async flush(): Promise<void> {}
  getSessionDuration(): number {
    return 0;
  }
  getCurrentScreen(): string | undefined {
    return undefined;
  }
  destroy(): void {}
}

function settle(): Promise<void> {
  return new Promise<void>((resolve: () => void) => setTimeout(resolve, 20));
}

export default function __Name__ListViewModelTest() {
  describe('__Name__ListViewModel', () => {
    let service: Mock__Name__Service;
    let analytics: MockAnalyticsService;

    beforeEach(() => {
      service = new Mock__Name__Service();
      analytics = new MockAnalyticsService();
    });

    it('loads items on init', async () => {
      service.items = [__Name__Factory.create(1, 'A', 1, 1)];
      const vm = new __Name__ListViewModel(service, analytics);
      await settle();
      expect(vm.state.isLoading).assertFalse();
      expect(vm.state.items.length).assertEqual(1);
    });

    it('exposes the error when loading fails', async () => {
      service.shouldFail = true;
      const vm = new __Name__ListViewModel(service, analytics);
      await settle();
      expect(vm.state.error !== undefined).assertTrue();
    });

    it('prepends a created item and emits ShowMessage', async () => {
      const vm = new __Name__ListViewModel(service, analytics);
      await settle();
      const effects: __Name__ListEffect[] = [];
      vm.subscribeToEffects((effect: __Name__ListEffect) => {
        effects.push(effect);
      });
      const input: Create__Name__Input = { type: 'Create__Name__', title: 'New', amount: 5 };
      vm.onEvent(input);
      await settle();
      expect(vm.state.items.length).assertEqual(1);
      expect(effects[0].type).assertEqual('ShowMessage');
    });

    it('emits ShowError when create fails', async () => {
      const vm = new __Name__ListViewModel(service, analytics);
      await settle();
      const effects: __Name__ListEffect[] = [];
      vm.subscribeToEffects((effect: __Name__ListEffect) => {
        effects.push(effect);
      });
      const input: Create__Name__Input = { type: 'Create__Name__', title: '', amount: 5 };
      vm.onEvent(input);
      await settle();
      expect(effects[0].type).assertEqual('ShowError');
    });

    it('emits __Name__Selected on select', async () => {
      const vm = new __Name__ListViewModel(service, analytics);
      await settle();
      const effects: __Name__ListEffect[] = [];
      vm.subscribeToEffects((effect: __Name__ListEffect) => {
        effects.push(effect);
      });
      const input: Select__Name__Input = { type: 'Select__Name__', id: 7 };
      vm.onEvent(input);
      expect(effects[0].type).assertEqual('__Name__Selected');
    });
  });
}
EOT

# ================================================================ anchors
insert "$TOKENS" "  UserService: string;" after "  ${NAME}Service: string;
  ${NAME}Repository: string;"
insert "$TOKENS" "  readonly UserService: string = 'UserService';" after "  readonly ${NAME}Service: string = '${NAME}Service';
  readonly ${NAME}Repository: string = '${NAME}Repository';"

insert "$CONTAINER" "import { UserFormViewModel } from '../../presentation/viewmodel/UserFormViewModel';" after \
"import { I${NAME}Service } from '../../domain/services/${NAME}Service';
import { ${NAME}ServiceImpl } from '../../domain/services/impl/${NAME}ServiceImpl';
import { I${NAME}Repository } from '../../domain/repository/${NAME}Repository';
import { ${NAME}RepositoryImpl } from '../../data/repository/${NAME}RepositoryImpl';
import { ${NAME}LocalDataSourceImpl } from '../../data/local/impl/${NAME}LocalDataSourceImpl';
import { ${NAME}ListViewModel } from '../../presentation/viewmodel/${NAME}ListViewModel';"
insert "$CONTAINER" "      // Bind sync manager (depends on repository)" before \
"      // ${WORDS}: data source -> repository -> domain service (generated by tools/new-feature.sh)
      const ${CAMEL}Repository = new ${NAME}RepositoryImpl(new ${NAME}LocalDataSourceImpl());
      this.container.bind<I${NAME}Repository>(TYPES.${NAME}Repository)
        .toConstantValue(${CAMEL}Repository);
      this.container.bind<I${NAME}Service>(TYPES.${NAME}Service)
        .toConstantValue(new ${NAME}ServiceImpl(${CAMEL}Repository));
"
insert "$CONTAINER" "  // ===== ViewModel Factories =====" before \
"  /**
   * Gets the ${WORDS} service (domain layer)
   */
  get${NAME}Service(): I${NAME}Service {
    return this.resolve<I${NAME}Service>(TYPES.${NAME}Service);
  }
"
insert "$CONTAINER" "  // Factory methods create ViewModels with proper DI (not registered as singletons)" after "
  /**
   * Creates a ${NAME}ListViewModel with injected dependencies
   */
  create${NAME}ListViewModel(): ${NAME}ListViewModel {
    const service = this.resolve<I${NAME}Service>(TYPES.${NAME}Service);
    const analytics = this.resolve<IAnalyticsService>(TYPES.AnalyticsService);
    return new ${NAME}ListViewModel(service, analytics);
  }"

insert "$ROUTES" "  | 'EditUser';" after "  | '${NAME}List';"
perl -0pi -e "s/  \\| 'EditUser';\\n  \\| '${NAME}List';/  | 'EditUser'\\n  | '${NAME}List';/" "$ROUTES"
insert "$ROUTES" "  | EditUserRoute;" after "  | ${NAME}ListRoute;"
perl -0pi -e "s/  \\| EditUserRoute;\\n  \\| ${NAME}ListRoute;/  | EditUserRoute\\n  | ${NAME}ListRoute;/" "$ROUTES"
insert "$ROUTES" "  editUser(userId: number): EditUserRoute;" after "  ${CAMEL}List(): ${NAME}ListRoute;"
insert "$ROUTES" "  /** Parse route from URL path */" before "  /** Navigate to ${WORDS} list */
  ${CAMEL}List(): ${NAME}ListRoute {
    return new ${NAME}ListRoute();
  }
"
insert "$ROUTES" "    return undefined;" before "    if (path.includes('${NAME}ListPage')) {
      return new ${NAME}ListRoute();
    }"
insert "$ROUTES" " * Union of all routes for type-safe navigation" before \
" * ${WORDS} List Route
 */
export class ${NAME}ListRoute implements Route<EmptyParams> {
  readonly type: RouteType = '${NAME}List';
  readonly path: string = 'pages/${NAME}ListPage';
  readonly params: EmptyParams = new EmptyParams();

  get url(): string {
    return this.path;
  }
}

/**"
insert "$ROUTES" "// ===== Screen Names for Analytics =====" before \
"/**
 * Type guard for ${NAME}ListRoute
 */
export function is${NAME}ListRoute(route: AppRoute): boolean {
  return route.type === '${NAME}List';
}
"
insert "$ROUTES" "    ['EditUser', 'Edit User']" after "    ['${NAME}List', '${WORDS} List']"
perl -0pi -e "s/    \\['EditUser', 'Edit User'\\]\\n/    ['EditUser', 'Edit User'],\\n/" "$ROUTES"

insert "$PAGES" "    \"pages/EditUserPage\"" after "    \"pages/${NAME}ListPage\""
perl -0pi -e "s|    \"pages/EditUserPage\"\\n|    \"pages/EditUserPage\",\\n|" "$PAGES"

insert "$LIST" "import UserDetailViewModelTest from './presentation/UserDetailViewModel.test';" after \
"import ${NAME}ServiceTest from './domain/${NAME}Service.test';
import ${NAME}ListViewModelTest from './presentation/${NAME}ListViewModel.test';"
insert "$LIST" "  UserDetailViewModelTest();" after "  ${NAME}ServiceTest();
  ${NAME}ListViewModelTest();"

insert "$JEST" "import UserDtoTest from '../entry/src/ohosTest/ets/test/data/UserDto.test.ts';" after \
"import ${NAME}ServiceTest from '../entry/src/ohosTest/ets/test/domain/${NAME}Service.test.ts';
import ${NAME}ListViewModelTest from '../entry/src/ohosTest/ets/test/presentation/${NAME}ListViewModel.test.ts';"
insert "$JEST" "UserDtoTest();" after "${NAME}ServiceTest();
${NAME}ListViewModelTest();"

echo "new-feature: ${NAME} slice created (${#NEW_FILES[@]} files) and wired into tokens, AppContainer, Routes, main_pages.json, List.test.ets, jest-tests/run-all.test.ts"
echo "next: tools/arch-check.sh && the build/test commands in AGENTS.md §5"
