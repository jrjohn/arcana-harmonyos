# AGENTS.md — arcana-harmonyos

Instructions for any AI coding agent (Claude Code, Codex, Cursor, Copilot, Gemini…) working
in this repository **or in any product created from it**. `CLAUDE.md`, `GEMINI.md` and
`.github/copilot-instructions.md` all point here; this file is the single source.

> **You MUST NOT report a task as done until `tools/arch-check.sh` exits 0, the ArkTS build
> compiles and `tools/run-jest.sh` exits 0 (§5).** Breaking the layering costs a red build:
> the pre-commit hook (`tools/githooks/pre-commit`) rejects new `.ets` files outside the layer
> directories, `*Impl` imports outside `core/di/`, and data-layer imports from pages/ViewModels;
> Jenkins stage "Architecture Qube" fails the merge below score 90 or on any critical violation.

## 0. First command in a fresh clone

Run `tools/install-hooks.sh` once. Git does not install hooks on clone; until you run it the
pre-commit check does not exist and only CI catches a flat layout — after the work is
written. `tools/new-app.sh` runs it for you.

## 1. Starting something new

| Situation | Do this | Never do this |
|---|---|---|
| New HarmonyOS product | `tools/new-app.sh <name> <dest-dir>` (optional `BUNDLE=com.acme.app`) — copies the whole repo, renames bundleName, vendor/app name strings, Jenkins `APP_NAME`, Sonar key, CI container + pushgateway names, Preferences/RDB/HUKS names and the deep-link scheme, resets the version to 0.1.0, installs the hook | Create an empty DevEco project and copy a few `ets/` folders into it |
| New business feature | `tools/new-feature.sh <Name>` (PascalCase) — one vertical slice: model, repository + service interfaces, service impl, local data source (+impl), repository impl, Input/State/Effect ViewModel, `@Entry` page, `TYPES` tokens, `AppContainer` binding + factory, route, two test files registered in both test runners | Call a repository or `http` from a page, or add `entry/src/main/ets/foo.ets` |
| Detail / form screens for a feature | Copy `pages/UserDetailPage.ets` + `presentation/viewmodel/UserDetailViewModel.ets` (or `UserForm*`) renamed; add a factory in `AppContainer`, a `Route` class in `Routes.ets` and the page in `main_pages.json` | Keep form state and service calls inside the page `struct` |

Copying parts instead of `new-app.sh` loses this file, the hook and the CI gate, so nothing
tells the next agent the rules exist.

## 2. Layers — where a file goes

All paths under `entry/src/main/ets/`. Tests mirror the layer under `entry/src/ohosTest/ets/test/`.

| Layer | Path | Contains | May depend on |
|---|---|---|---|
| Entry | `entryability/EntryAbility.ets`, `workers/` | ability lifecycle, `AppContainer.initialize(context)`, background sync worker | core |
| Core / DI | `core/di/` (`AppContainer.ets` composition root, `tokens.ets` `TYPES`, `interfaces.ets`, `Container.ets`), `core/navigation/Routes.ets`, `core/<logging\|network\|sync\|analytics\|security\|cache\|i18n\|scheduling\|…>/` (+ `impl/`) | the only place `*Impl` classes are constructed and bound; ViewModel factories `create<X>ViewModel()`; type-safe routes; cross-cutting services | domain, data (only `core/di/` touches implementations) |
| Presentation | `pages/` (`@Entry` structs), `presentation/viewmodel/` (`BaseViewModel` subclasses), `presentation/components/` | pages render ViewModel state and send `Input`s; ViewModels own state and emit `Effect`s | domain models + service interfaces, `core/di` (`getContainer()`), `core/navigation`, `core/logging` — **never** `data/` |
| Domain | `domain/models/`, `domain/repository/` (`I<X>Repository`), `domain/services/` (`I<X>Service`) + `domain/services/impl/`, `domain/validators/` | entities + `Result`/`AppError`, repository and service contracts, service impls (validation, orchestration), validators | domain; `core/logging`, `core/di/decorators` (as `UserServiceImpl` does) |
| Data | `data/repository/` (`<X>RepositoryImpl`), `data/local/` (+ `impl/`: Preferences, RelationalStore), `data/api/` (+ `impl/`, `dto/`), `data/cache/` | offline-first repositories, local stores, HTTP API + DTO mappers, LRU / observable caches | domain, core |

Direction: page → ViewModel → `I<X>Service` (domain) → `I<X>Repository` → data source / API.
A lower layer never imports a higher one. The User repository is bound through
`IUserRepositoryService` in `core/di/interfaces.ets`; new features use
`domain/repository/I<X>Repository` as `new-feature.sh` generates.

## 3. Rules

| # | Rule | Enforced by |
|---|---|---|
| R1 | Every service, repository and data source is an interface (`I<X>Service`, `I<X>Repository`, `I<X>LocalDataSource`) implemented by a class named `<X>…Impl` in the sibling `impl/` folder or in `data/repository/`. | arch-qube "Interface/Impl Colocation", "Implementation Naming Convention" |
| R2 | Only `core/di/` imports from an `impl/` path, imports a concrete `…ServiceImpl/RepositoryImpl/DataSourceImpl`, or calls `new` on one. Everyone else receives the interface by constructor or `getContainer()`. Tests may construct impls. | arch-qube "Only DI Container Imports Impl"; pre-commit hook |
| R3 | `pages/` and `presentation/` never import `data/`; a page never calls a service — it calls `viewModel.onEvent(input)` only. | arch-qube "View Cannot Call Service", "Layer Direction Enforcement"; pre-commit hook |
| R4 | A ViewModel extends `BaseViewModel<Input, State, Effect>`: `Input` is a union of interfaces discriminated by `type`, state changes go through `replaceState(copy)`, one-time actions (toast, navigation) through `emitEffect`; the page subscribes with `subscribeToState` / `subscribeToEffects` and unsubscribes in `aboutToDisappear`. | arch-qube "Unidirectional Data Flow"; review (arch-qube "MVVM I/O/E Structure" is AI-only, see §4) |
| R5 | A new screen gets a `Route` class + factory method + `fromPath` branch in `core/navigation/Routes.ets` and an entry in `entry/src/main/resources/base/profile/main_pages.json`. | arch-qube "Type-Safe NavGraph"; hvigor build (missing page = load failure) |
| R6 | A new service gets a token in **both** the `ServiceTokens` interface and `ServiceTokensImpl` (`core/di/tokens.ets`), a binding in `AppContainer.initialize`, and a `create<X>ViewModel()` factory. | hvigor `CompileArkTS`; `new-feature.sh` does it |
| R7 | Reads come from the local store first and refresh from the network; writes go local first and are queued for sync (see `UserRepositoryImpl`). | review (arch-qube "Offline-First Design", "4-Layer Progressive Cache" are AI-only) |
| R8 | No new `.ets`/`.ts` source outside the directories of §2 (tests under `entry/src/ohosTest/`). | pre-commit hook |
| R9 | Every new service impl and ViewModel has a test under `entry/src/ohosTest/ets/test/<layer>/`, registered in `List.test.ets` and — when it has no `@kit` import — in `jest-tests/run-all.test.ts`. | Jenkins "Jest Coverage" (`tools/run-jest.sh`); SonarQube quality gate |
| R10 | Code compiles under ArkTS strict (table below). | hvigor `CompileArkTS` — **not run by Jenkins**, run it yourself (§5) |

ArkTS strict pitfalls (API 22, compiled by `hvigorw`; jest/swc does **not** catch them):

| Not allowed | Write instead |
|---|---|
| Object literal as a type (`let p: { id: number }`) | a named `interface` or `class` |
| Untyped object literal (`const e = { type: 'X' }`) | declare the type: `const e: XEffect = { type: 'X' }` |
| `any`, `unknown`, `as unknown as T` in `main/` | concrete types; narrow with `instanceof` |
| Destructuring (`const { a } = obj`, `[a, b] = arr`) | `const a = obj.a` |
| Index access on objects (`obj['k']`), `Symbol`, `as const` | `Map`/`Record<string, T>`, string tokens (see `tokens.ets`) |
| Lambdas without parameter types in callbacks you write | `(item: Invoice) => …` |
| SDK 26-only APIs while `compatibleSdkVersion` is `6.0.2(22)` | guard with `apiAvailable` (the build prints a WARN) |

## 4. Architecture check (arch-qube)

arch-qube (https://github.com/jrjohn/arcana-arch-qube) scans the source for MVVM,
layer-direction, DI and naming violations and scores it; usage guide:
https://github.com/jrjohn/arcana-skills/tree/main/arch-qube-skill. The version is pinned in
`tools/arch-qube.version`, read by both `tools/arch-check.sh` and the Jenkinsfile.

- Run: `tools/arch-check.sh` — image `ghcr.io/jrjohn/arch-qube:<version>` (public,
  multi-arch), else `arcana.boo/arcana/arch-qube:<version>`; never `:latest`. Same
  `--framework harmonyos`, `--threshold 90` and exclusions as Jenkins stage "Architecture Qube".
  Exit 0 = pass, 1 = fail, 2 = could not run (no Docker / no image) — 2 is **not** a pass.
- Without Docker, on a tree without `node_modules/`, `oh_modules/`, `build/`, `coverage/`:
  `pipx run --spec git+https://github.com/jrjohn/arcana-arch-qube.git@v0.5.7 arch-qube scan . --framework harmonyos --no-ai --format json,markdown -o arch-qube-reports --threshold 90`.
- Report: `arch-qube-reports/arch-qube.md` (summary) and `arch-qube.json` (per rule:
  `files_checked`, violations). PASS needs score ≥ threshold **and** zero violations in
  every critical rule — a 99.4 can FAIL. A rule under "Not evaluated" (here: MVVM I/O/E
  Structure + Models, 4-Layer Cache, Offline-First, Security, Module Boundary — AI-only) is not
  a pass; R4/R7 are on you. A rule with `files_checked: 0` checked nothing. "Only DI Container
  Imports Impl" (arch-qube 0.5.7, `harmonyos` profile) treats all of `data/` and `core/` as
  container scope: an `*Impl` import there is not reported (measured: `core/sync/` and
  `data/repository/` importing an impl scored 100 on that rule; `domain/` and `pages/` were
  caught). R2 still applies there — the pre-commit hook enforces it. `--ci` prints nothing on failure: rerun without `--ci`.
- False positive: open an issue on arcana-arch-qube with the report attached. Never lower
  `--threshold`, add exclusions, or move code to dodge a rule.

## 5. Before you say "done"

Run these, in this order, and paste the last line of each into your summary:

```bash
tools/arch-check.sh                 # must print "arch-check: PASS"
npm install --no-fund --no-audit    # Jenkins "Jest Coverage", step 1
tools/run-jest.sh                   # Jenkins "Jest Coverage", step 2 — exits non-zero on a failing test
ohpm install --all && hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
                                    # ArkTS strict compile ("BUILD SUCCESSFUL"); not a Jenkins stage
```

`hvigorw`/`ohpm` come with DevEco Studio: on macOS
`T=/Applications/DevEco-Studio.app/Contents; export DEVECO_SDK_HOME=$T/sdk PATH=$T/tools/node/bin:$T/tools/ohpm/bin:$T/tools/hvigor/bin:$PATH`.
Without DevEco, `docker compose -f docker-compose.ci.yml run --rm harmonyos-build` runs the same
command in `arcana.boo/arcana/harmonyos-build:6.0.0` (linux/amd64). Device tests
(`List.test.ets`, hypium) need an emulator or device. CI also runs SonarQube, which you cannot
run locally. `tools/arch-check.sh` excludes build outputs (`entry/build`, `.hvigor`,
`oh_modules`, `node_modules`, `coverage`) exactly as Jenkins does.

## 6. Reference

- Optional detail: `arcana-harmonyos-developer-skill`
  (https://github.com/jrjohn/arcana-skills/tree/main/arcana-harmonyos-developer-skill).
  This file is the source of truth: if the skill and this file disagree, this file wins.
