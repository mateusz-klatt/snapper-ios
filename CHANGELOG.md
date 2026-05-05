# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

MVVM extraction trajectory toward global ≥80% unit-test coverage —
the architecture rules + concurrency / mocking conventions live in
`docs/architecture-mvvm.md`. Baseline at v0.3.0: **66.5% global**
(5758/8660 lines). The release-
critical Views are the bulk of the gap (PositionsView 15.6%,
OrdersView 10.6%, NewOrderSheet 26.4%, NotificationPrefsView 21.1%,
WalletPicker 23.8%, attach sheets ~25%); v0.3.1 closes them by
moving load / submit / error / business state into
`@MainActor @Observable` ViewModels and leaving the Views as thin
binders.

### Added

- **`APIClientProtocol` seam** at `Services/APIClientProtocol.swift`.
  Mirrors every public `APIClient` method so ViewModels can be
  init-injected with a deterministic `MockAPIClient` test double
  without going through the URL stack. Concrete `APIClient` now
  conforms; existing `APIClientNetworkTests` keep using the
  `URLProtocol` interception path against the concrete class to
  verify JSON encode / decode end-to-end.
- **`MockAPIClient` test double** at
  `SnapperTests/Helpers/MockAPIClient.swift`. Closure-overridable
  slot per method; default behavior throws `APIError.invalidResponse`
  so unconfigured calls fail loudly. Pattern: `mock.fetchPositionsHandler = { [.fixture] }`.
- **MVVM architecture doc** at `docs/architecture-mvvm.md`. Documents
  the View / ViewModel split, mocking strategy, concurrency rules,
  coverage philosophy (hybrid: slim bodies first, xccov filter as
  fallback), and the extract-vs-skip decision for each kind of View.

### Changed

- **`LoginViewModel` migrated from `ObservableObject` to
  `@Observable`** (iOS 17+ Observation framework). Eliminates the
  Combine `@Published` / `assign(to:)` plumbing; `errorMessage` and
  `isAuthenticated` are now passthrough computed properties so the
  test contract stays identical. `LoginView` switches from
  `@StateObject` to `@State` accordingly. `AuthService` itself
  stays `ObservableObject` for now — out of scope for this PR.
- **`NewOrderSheet` MVVM pilot — extracted `NewOrderSheetViewModel`**
  at `Snapper/ViewModels/NewOrderSheetViewModel.swift`. The View
  shrinks from a 395-line state-and-async holder to a thin form
  binder (~150 lines). The VM owns: form fields (exchange /
  instrument / side / order type / quantity / price / stop price /
  leverage / reduce-only), the `availableInstruments` cache,
  `isLoadingInstruments` / `isSubmitting` / `loadError` flags, the
  per-presentation `idempotencyKey`, the race-safe
  `loadInstruments()` async, the form-validation `canSubmit`
  computed, the `buildBody()` builder, and the `submit(via:)`
  re-entry-guarded submit that wraps the parent-injected
  `onSubmit` closure. Tests extracted into
  `SnapperTests/ViewModels/NewOrderSheetViewModelTests.swift` (21
  new instance / async / race / idempotency tests) plus the
  existing static-helper coverage in `Views/NewOrderSheetTests.swift`
  ported from `NewOrderSheet.X` to `NewOrderSheetViewModel.X`.
- **`WalletPicker` MVVM extraction — `WalletPickerViewModel`** at
  `Snapper/ViewModels/WalletPickerViewModel.swift`. Extracted from
  the toolbar wallet selector. The VM owns `loadError`, the
  `loadWallets()` async (with logger diagnostics on failure paths),
  and the `selectWallet(_:)` mutation; the View shrinks to a
  ~60-line Menu binder. `AppState` is init-injected so tests run
  against an ephemeral `UserDefaults` instance instead of mutating
  `AppState.shared`. Establishes the AppState init-injection
  pattern that subsequent VMs (`OrdersViewModel`,
  `PositionsViewModel`) reuse.
- **`PositionsView` MVVM extraction — `PositionsViewModel`** at
  `Snapper/ViewModels/PositionsViewModel.swift`. The View shrinks
  from a 581-line state-and-async holder to a thin List binder
  (~310 lines, including the inline `ReducePositionView` +
  `PositionCard` definitions). The VM owns `positions`,
  `isLoading`, `loadError`, `submitError`, `load()`, the four
  submit flows (`submitMarketReduce`, `submitBracket`,
  `submitTrailingStop`), the `filteredPositions` derived
  collection, and the static helpers (`filter`, `walletMatches`,
  `canSubmitReduce`, `shouldShowLoadError`, `makeReduceCommand`).
  Sheet/alert presentation flags (`actionSheetPosition`,
  `reduceModalPosition`, `bracketModalPosition`,
  `trailingStopModalPosition`, `pendingClosePosition`) stay as
  `@State` in the View per Q3. 16 new VM tests cover load happy /
  failure / sticky-error recovery, submitMarketReduce success /
  missing-id refusal / API failure, submitBracket success /
  no-cycle refusal / API failure, submitTrailingStop success /
  no-cycle refusal / API failure, filteredPositions
  wallet-scoping. Cross-file callsites in `HomeView`,
  `PositionsViewTests`, `HomeViewTests` retargeted from
  `PositionsView.X` to `PositionsViewModel.X` via mechanical sed.
- **`OrdersView` MVVM extraction — `OrdersViewModel`** at
  `Snapper/ViewModels/OrdersViewModel.swift`. The View shrinks
  from a 465-line state-and-async holder to a thin Picker / List
  binder (~210 lines). The VM owns `orders`, `executions`,
  `isLoading`, `errorMessage`, `submitError`, the parallel
  `async let` `load()` (with `os.Logger` diagnostics on each
  partial-failure path), `submitNewOrder(body:)` /
  `submitCancel(order:)`, derived `filteredOpen` / `filteredRecent`
  / `filteredFills`, `derivedExchanges`, and `resolvedWallet`.
  Sheet/alert booleans (`presentingNewOrder`, `pendingCancelOrder`)
  stay as `@State` in the View per Q3 of the architect consensus.
  17 new VM tests cover the parallel-load happy + partial-failure
  paths, submit success/failure, cancel success / no-plan-id /
  failure, derived collection scoping + sorting + capping, and
  resolvedWallet branches. Static helpers preserved verbatim
  (`OrdersViewModel.openStatuses` / `isOpen` / `walletMatches`
  / `filterOpen` / `filterRecent` / `filterFills`
  / `shouldShowLoadError` / `shouldShowLoadingPlaceholder`); all
  callsites in `HomeView`, `PositionsView`, `OrdersViewTests`,
  `HomeViewTests` retargeted from `OrdersView.X` to
  `OrdersViewModel.X` via mechanical sed.
- **Attach-sheet MVVM extraction — `AttachBracketSheetViewModel`
  + `AttachTrailingStopSheetViewModel`** at
  `Snapper/ViewModels/`. Both small sheets converted to the
  pilot pattern (despite the v0.3.1 architect consensus
  initially proposing they stay closure-driven only) so the
  form-state mutations, parsing, idempotency-key lifecycle, and
  submit re-entry guard get coverage. Each VM owns the form
  fields (`slPriceText`/`tpPriceText` and
  `trailingPctText`/`minLockPctText`), `isSubmitting`, and the
  per-presentation `idempotencyKey`. The parent-injected
  `onSubmit` closure stays on the View → parent VM contract
  unchanged (parent VMs still own the `APIClient.createBracket`
  / `createTrailingStop` round trip). Static helpers
  (`parsePrice` / `parsePercent`, `canSubmit`, `makeCommand`)
  preserved on the new VMs so the existing
  `AttachBracketSheetTests` / `AttachTrailingStopSheetTests`
  coverage stays green.

### Fixed

- **`NewOrderSheet.loadError` no longer sticky after a successful
  retry.** The pre-MVVM body never reset `loadError` on the
  recovery path, so a successful retry left the error banner
  visible until the user dismissed the sheet. The new VM clears
  the slot whenever a fresh `fetchInstruments` succeeds.
  Regression covered by
  `testLoadInstrumentsClearsLoadErrorOnRecovery`.

### Tests

- Test count: 205 (post-foundations) → 296 (+21 NewOrderSheet
  pilot, +14 WalletPicker, +11 AttachBracket, +12 AttachTrailing,
  +17 OrdersView, +16 PositionsView).
  New tests live under `SnapperTests/ViewModels/` and cover
  load / failure / race / submit / re-entry / idempotency /
  AppState mutation branches against the lock-protected
  `MockAPIClient` + per-test ephemeral `AppState(userDefaults:)`.

## [0.3.0] — 2026-05-05

Release-gate slice — targeted reliability uplift on the notification
path + privacy policy + a real navigation bug fix. Synthesized from
multi-model architect consensus (Codex 5.4 / 5.5 / Copilot 5.4) on
the question "what's the minimum slice between v0.2.0 TestFlight and
App Store submission?".

### Added

- **NotificationService durable-registration wiring tests.**
  Covers the gate that re-fires `registerForRemoteNotifications()`
  after relaunch / login flip when the user previously granted
  permission, paired with a `#if DEBUG`-gated test seam
  (`_refreshWithStatusForTests`) that pins the `UNAuthorizationStatus`
  the simulator always reports as `.notDetermined`. 6 wiring tests:
  authorized + logged-in / provisional + logged-in / ephemeral +
  logged-in (fire) and authorized + logged-out / denied + logged-in
  / notDetermined + logged-in (suppress), plus an idempotency
  regression for cold-relaunch + scenePhase double-trigger.
- **`docs/privacy-policy.md`** — markdown source-of-truth for the
  iOS app's privacy disclosure. Canonical published HTML is on the
  maintainer's frontend deploy
  (`snapper-frontend:public/privacy-policy.html`). README links
  both. The policy describes the actual on-device behaviour: no
  third-party SDKs, no analytics, no telemetry; data flows only
  between the device, the user's self-hosted backend, and Apple's
  APNs (opt-in).

### Fixed

- **Logged-out notification tap silently dropped the deep-link.**
  When a notification arrived while the user was on `LoginView`,
  `NavigationCoordinator.handleNotificationTap` set
  `pendingDeepLink` correctly, but `MainTabView` was not yet
  mounted (auth gate in `SnapperApp` only mounts it after
  `authService.isAuthenticated`). Once the user logged in,
  `MainTabView` mounted but the existing `.onChange(of:
  pendingDeepLink)` observer did not fire — SwiftUI does not
  fire `.onChange` for values already set at first render. The
  deep-link was lost and the user landed on the default tab
  instead of the alert / order / position the notification
  pointed at. `MainTabView` now consumes `pendingDeepLink` on
  `.onAppear` AND `.onChange` via a shared
  `consumePendingDeepLink()` helper.

### Security

- **`LoginViewModel.password` cleared after login.** Previously
  the `@Published var password: String = ""` field stayed live
  for the view's lifetime, so the plaintext password was
  reachable in memory long after `authService.login()` resolved.
  `LoginViewModel.login()` now overwrites `password = ""` once
  the auth call returns (success or failure). Two regression
  tests pin the contract on both the success + failure paths so
  a future refactor can't silently drop the clear.

### Tests

- iOS test count: 195 (post-v0.2.0) → 203.
- `NotificationService` line coverage: ~25% → 60.8%.
- Whole-app line coverage: 22.7% → ~24%. The remaining
  unconcovered lines are SwiftUI body chrome that pure-helper
  extraction cannot reach without a ViewInspector / MVVM rewrite
  — explicitly out of scope per architect consensus.

## [0.2.0] — 2026-05-05

Trading-correctness pack: six PRs landed in one session against
`mateusz-klatt/snapper-ios` master, each accompanied by a Copilot
code review and a fix-up commit addressing the surfaced findings.
163 baseline tests grew to 184 across the pack; every PR ran the
full quality gate locally + on CI before merge.

### Added

- Mutation sheets (`NewOrderSheet`, `AttachBracketSheet`,
  `AttachTrailingStopSheet`, `ReducePositionView`) keep open on
  failure so users can retry without losing the form state or
  the in-sheet idempotency key (#1).
- Surface load errors in `PositionsView`, `OrdersView`, and
  `WalletPicker` — a network or 5xx failure now renders a
  `ContentUnavailableView` (or inline Section / menu prompt)
  with a Retry button instead of an empty list. `OrdersView`
  also covers the `fetchExecutions` failure path and shows a
  "Loading…" placeholder when Retry fires on an empty list (#2).
- `HomeView` "Open Positions" / "Active Orders" stat counters
  and Recent Orders card now wallet-scope via the canonical
  `PositionsView` / `OrdersView` helpers; the Active Orders
  count uses the full `new|submitted|open|partially_filled`
  lifecycle set instead of the prior ad-hoc `"open"|"pending"`
  pair, and Recent Orders inherits `OrdersView.filterRecent`
  newest-first sorting (#6).

### Fixed

- `AuthService.fetchFreshWsToken` now coalesces concurrent
  callers into a single in-flight request via a
  `Task<String?, Never>?` slot. `logout()` cancels the in-flight
  refresh so a freshly-minted token cannot re-stamp `wsToken`
  on a session the user just signed out of (#3).
- `NotificationPrefsView.AlertDefaultRow` reverts its local
  toggle / picker state when the `updateAlertDefault` PATCH
  fails. A synchronous `localInflight` `@State` flag closes
  the re-entry race the parent's `inflightAlertTypes` set
  could not catch — the row disables the moment a Task is
  dispatched, eliminating the stale-snapshot rollback window.
  The success path now also clears the prior `loadError` so the
  banner does not linger after recovery (#4).
- `NotificationService.refreshAuthorizationStatus` re-fires
  `registerForRemoteNotifications()` when an authorized + logged-
  in user returns to `.active` or logs in — the system only
  delivers a fresh APNs token in response to an explicit
  registration call, so cold-relaunch + login-during-active
  paths previously stayed stuck in `.awaitingToken` forever.
  `.ephemeral` is now treated as granted alongside `.authorized`
  / `.provisional` for parity with `isAuthorized` /
  `SettingsView`. `DeviceRegistrationService.onLogout` clears
  `lastRegisteredDevicePublicId` to close the cross-user-leak
  window between logout and the next register cycle, and
  `register()` re-checks `isLoggedIn` after the await to drop
  responses that land post-logout (actor re-entrancy guard) (#5).

## [0.1.3] — 2026-05-05

Quick-wins pass after multi-model code review of v0.1.2. Hardening + observability fixes; no behaviour changes for end users.

### Security

- All GitHub Actions in `.github/workflows/` now reference immutable
  commit SHAs instead of mutable tags (`@v6`, `@v2`, `@v8.0.0`). Closes
  the supply-chain finding flagged by 6/6 reviewers.
  Pinned: `actions/checkout@de0fac2e` (v6.0.2),
  `gitleaks/gitleaks-action@ff98106e` (v2.3.9),
  `SonarSource/sonarqube-scan-action@59db25f3` (v8.0.0).
- `Makefile`'s `coverage` target now verifies the SHA-256 of the
  vendored `xccov-to-sonarqube-generic.sh` before executing it, so a
  tampered script can't run against TestFlight artefacts.
- `ci_scripts/ci_post_clone.sh` no longer echoes secret-classified
  values (`SNAPPER_BUNDLE_IDENTIFIER`, `SNAPPER_DEVELOPMENT_TEAM`) at
  the end of its run. The success message now reports only the build
  number and tag.

### Fixed

- `DeviceRegistrationService` retry loop off-by-one: the `60s` final
  delay in `retryDelaysSeconds = [1, 4, 16, 60]` was unreachable
  because the guard used `<` instead of `<=`. Total retry budget now
  matches the documented "~80s upper bound" (1 + 4 + 16 + 60 = 81s).
- `AuthService.logoutFromServer` no longer swallows network errors
  with `try?`. Failures are logged at `.warning` so an oncall can
  correlate "stale session on next login" reports; local state is
  still cleared regardless.
- `WebSocketManager` typed-frame decode failures (trade, order_event,
  order_cancel, heartbeat, user_deactivated) escalated from `.debug`
  to `.warning` with the offending frame size attached. Protocol
  drift between iOS and the backend now produces visible telemetry.

### Changed

- `README.md` Status section now references the v0.1.x line and
  points readers at `CHANGELOG.md` for the per-release breakdown.

## [0.1.2] — 2026-05-05

Re-release to redirect future TestFlight builds back to the canonical
`1.0` version group. v0.1.1's MARKETING_VERSION-from-tag patcher created
a separate "0.1.1" tester group that required manual tester management;
v0.1.1 already removed the patcher, but the v0.1.1 build itself had
already shipped to the orphan group. v0.1.2 is the first build cut from
the cleaned-up release pipeline — no code changes since v0.1.1 beyond
the patcher removal that v0.1.1 actually included in source.

### Fixed

- `ci_post_clone.sh` no longer derives `MARKETING_VERSION` from `CI_TAG`
  (that change shipped in v0.1.1 source but didn't land in TestFlight
  until this release). All Xcode Cloud builds now land in the same
  marketing-version group, so testers carry over release-to-release.

## [0.1.1] — 2026-05-05

First Xcode Cloud release pipeline. Tooling-only changes; no app behaviour
shifts since v0.1.0.

### Added

- `ci_scripts/ci_post_clone.sh` — Apple-standard hook that overlays
  signing identity, bundle id, backend URL, and the build number onto
  the cloned tree from secret Workflow environment variables in App
  Store Connect. Lets the public source keep neutral defaults
  (`com.example.snapper`, no `DEVELOPMENT_TEAM`, `localhost:8000`)
  while Xcode Cloud builds Release / TestFlight with production values
  that never enter the repo.
- `docs/architecture.md` — "Release pipeline" section documenting the
  GitHub Actions + Xcode Cloud split (GHA gates push / PR, Xcode Cloud
  handles tag-driven Release + TestFlight upload).
- `docs/known-limitations.md` — explanation of the ~38% SonarCloud
  line coverage (SwiftUI body code dominates LoC; XCTest cannot enter
  it without a snapshot-testing SPM dependency, deliberately off the
  roadmap). Service / view-model layer is at 47-100%.
- `CHANGELOG.md` (this file) following Keep a Changelog 1.1.0.

### Fixed

- `ci_post_clone.sh` jumps to `$CI_PRIMARY_REPOSITORY_PATH` before
  patching, so subsequent `sed` / `plutil` / `xcodegen` calls find
  files at the repo root instead of `ci_scripts/`.
- Build number substitution dropped its hand-rolled "+9" offset in
  favour of using `CI_BUILD_NUMBER` directly. The starting value
  lives at App Store Connect → Xcode Cloud → Settings → Build Number,
  set once to clear the last private-monorepo TestFlight build.
- Marketing version is no longer derived from `CI_TAG`. TestFlight
  groups builds per `CFBundleShortVersionString`, so binding the
  marketing version to release tags created a new tester group every
  release. The patcher now leaves `MARKETING_VERSION` at whatever
  `project.yml` ships; bumping it is an explicit maintainer edit
  intended for user-visible releases.

## [0.1.0] — 2026-05-04

First public release. iOS client for the Snapper trading platform,
extracted from the private monorepo as a public OSS submodule.

### Slice 1 surface

- **Login + session** — cookie-based auth via `URLSession.shared`;
  `AuthService` handles login / logout / refresh.
- **Order entry** (`NewOrderSheet`) — limit / market / stop with
  per-sheet idempotency keys, paper / live mode propagation,
  cross-exchange race guard, instrument picker keyed on
  `instrumentPublicId` (not symbol).
- **Cancel order** — swipe-action on `OrdersView`, fires the
  `cancel_order_command` envelope to `POST /api/orders/{plan_public_id}/cancel`.
- **Brackets** (`AttachBracketSheet`) — stop-loss / take-profit
  attachment via `POST /api/execution-plans` with at-least-one-leg
  validation mirroring the backend's `BracketCreateBody` rule.
- **Trailing stops** (`AttachTrailingStopSheet`) — trailing-percent +
  optional min-lock-in floor via `POST /api/trailing-stops`.
- **Positions tab** — wallet-scoped position list with reduce / close
  actions guarded behind `canSubmitReduce` (refuses to fire when the
  source position arrives without `walletPublicId` / `instrumentPublicId`).
- **Alerts tab** — paginated alert history (`URLComponents`-built
  cursor pagination) with deep-linking by `publicId`.
- **Push notifications** — APNs token registration via
  `DeviceRegistrationService` actor (handshake gates on both APNs
  token + login state), per-(alert_type, scope) device preferences,
  user-level alert default fallbacks, retry-with-exponential-backoff
  on registration failure surfaced in Settings.
- **Settings** — wallet picker, notification authorization control,
  device registration status (idle / inFlight / succeeded / failed),
  manual retry action.

### Architecture

- Swift 6.0 strict concurrency: `@MainActor` services, actors for
  registration, `Sendable` protocols across actor boundaries.
- `WebSocketManager` — capped exponential backoff reconnect (300s
  ceiling, no hard attempt cap), proactive `ws_token` refresh at 80%
  of TTL, terminal `.authFailed` state distinct from transient `.error`,
  stale-task identity guards around every receive-loop async suspension.
- `EnvelopeMinter` (`@MainActor`) — per-app session id, separate
  control / telemetry sequence counters, ms-precision ISO-8601
  timestamps. Mirrors the cross-platform contract enforced by the
  bridge (`integrations/snapper-mcp/src/envelope.ts` upstream) so
  backend gap detection sees a coherent session across iOS-originated
  commands.
- `APIClient` — generic `request<T: Decodable>` core, one-shot 401
  refresh-and-replay, `URLComponents` + `URLQueryItem` for query
  building, `urlPathAllowed` percent-encoding for path segments.
- Generated types under `Snapper/Models/Generated/` are upstream-owned
  snapshots of the backend's OpenAPI + WebSocket schemas.
- Zero Swift Package Manager dependencies — runs on Foundation +
  SwiftUI + Combine alone.

### Testing

- 33 test files across XCTest + Swift Testing.
- `MockURLProtocol` for REST round-trips, `FakeWebSocketTask` +
  `FakeWebSocketTaskFactory` for reconnect-race tests, `FakeSleeper`
  actor for deterministic backoff timing.
- Service / view-model layer at 47-100% line coverage; SwiftUI body
  code largely uncovered (XCTest does not enter the render path).

### Build + CI

- XcodeGen-driven (`project.yml` is source of truth, generated
  `.xcodeproj` ignored).
- Makefile targets: `setup`, `build`, `test`, `coverage`, `archive`,
  `clean`. CI uses the same Make targets the maintainer uses locally.
- GitHub Actions on `macos-26`:
  - `ci.yml` — build + test on every push to `master` and PR
  - `gitleaks.yml` — secret scan on push / PR / weekly cron
  - `sonarcloud.yml` — coverage scan via Xcode `xccov` →
    SonarCloud generic XML
- Vendored `scripts/xccov-to-sonarqube-generic.sh` from
  `SonarSource/sonar-scanning-examples` master at SHA `bcf43b3b`,
  SHA256 `eccc3e2f3b7a67dab74fdc4b2de9a888a9f86e0ede2856d7d55de095ba488d63`.

### Configuration

- Default backend URL is `http://localhost:8000` — pair with
  `make dev-backend` from the parent repo for local development.
- `PRODUCT_BUNDLE_IDENTIFIER=com.example.snapper`, no
  `DEVELOPMENT_TEAM` — fork builds for the simulator immediately;
  archive requires `make archive DEVELOPMENT_TEAM=...`.
- iOS 26.2 deployment target matches the SDK in the GitHub Actions
  `macos-26` runner image.

### Known limitations

See [`docs/known-limitations.md`](docs/known-limitations.md) for the
v0.2.0 backlog: CSRF header on iOS mutating REST requests,
public-side type regeneration script, fork-PR Sonar handling, and
the SwiftUI coverage story.

[Unreleased]: https://github.com/mateusz-klatt/snapper-ios/compare/v0.1.3...HEAD
[0.1.3]: https://github.com/mateusz-klatt/snapper-ios/releases/tag/v0.1.3
[0.1.2]: https://github.com/mateusz-klatt/snapper-ios/releases/tag/v0.1.2
[0.1.1]: https://github.com/mateusz-klatt/snapper-ios/releases/tag/v0.1.1
[0.1.0]: https://github.com/mateusz-klatt/snapper-ios/releases/tag/v0.1.0
