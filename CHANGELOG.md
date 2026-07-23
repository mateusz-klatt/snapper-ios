# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.0.0] — 2026-07-23

Major release expanding the native iOS app with permission-gated,
read-only coverage of the core operator surfaces.

### Added

- Added a repeatable admin/viewer permission UAT screenshot mode for a freshly
  seeded backend. It records every native read surface, exercises real
  position/order rows, and proves positive admin versus negative viewer
  mutation controls.
- Added eight permission-gated, read-only screens: Signals, System
  Health, Backtests, Processes, AI Reviews, Strategies, Admin Users,
  and AI Integration delegates.
- Added Venue Accounts with live account-truth status, balances, open
  positions, observation timestamps, and clear stale-data warnings.
- Added complete 45-locale coverage for Venue Accounts and unknown-order
  alerts, plus the localized AI Researcher role.
- Added per-process resource summaries and coordinator details, and
  support for unknown-order safety alerts and user alert defaults.

### Changed

- Changed Positions to show unknown valuations honestly instead of as
  zero and to enable protective plans or reductions only when the
  position has the required entry and quantity data.
- Bumped `MARKETING_VERSION` from `2.0.2` to `3.0.0`.

### Fixed

- Synchronized the wallet picker with the backend session scope so
  wallet-scoped surfaces such as Backtests become available immediately.
- Serialized refresh-token rotations across wallet changes, made concurrent
  logout callers await one teardown, and prevented stale refresh work from
  recreating a logged-out session.
- Wired the opt-in screenshot workflow through the same backend-aware
  harness used for local release UAT.
- Kept Venue Account rows current with a recurring five-second refresh
  so live observations no longer age into stale state between loads.
- Regenerated API models to resolve scoped-strategy schema drift, a
  duplicate `Permission` enum, and P&L timeline union decoding.
- Replaced timing-dependent WebSocket envelope waits with frame-specific
  synchronization so coverage runs no longer fail intermittently.

## [2.0.2] — 2026-05-25

CandlestickChartView SwiftUI primitive rewrite for the App Store 2.0.2
build.

### Fixed

- Replaced the Swift Charts `RectangleMark` / `RuleMark` candle pipeline
  with SwiftUI `Canvas` + `Path` primitives so color resolution is
  deterministic for both Western and East-Asian financial color
  conventions. This fixes the CN / HK / JP / KR red-rising convention
  that was broken by iOS 26.2 Swift Charts ignoring explicit
  foreground styles on the previous marks.
- Verified the same backend BTC-USD candle renders with the expected
  convention in US and CN locales, and that AE keeps RTL chart axis
  labels on the leading edge.

### Changed

- Bumped `MARKETING_VERSION` from `2.0.1` to `2.0.2`.

## [2.0.1] — 2026-05-24

App Store release with i18n root-view propagation, the 15x3 picker, and
market-data banner fixes.

### Fixed

- Propagated locale and layout environment through `RootView` so runtime
  locale switches update the app root consistently.
- Updated the language picker to the 15x3 `AppLocale` grid with autonym
  labels.
- Fixed the cache-warming banner denominator to match the actual market
  data fetch.
- Refactored the market-data banner so it reflects chart-cache state for
  the selected timeframe.

### Changed

- Bumped `MARKETING_VERSION` from `2.0.0` to `2.0.1`.

## [2.0.0] — 2026-05-23

First App Store 2.x release line.

### Added

- 45-locale native catalog coverage, including Irish, Burmese, and
  Filipino, plus a native-fluent QA pass across all supported locales.
- RTL and Hebrew / Arabic bidirectional polish.
- Financial color convention support, including rising-red behavior for
  East-Asian market locales.
- Market Data parity pieces: instrument description banner, related
  instruments row, pair-stats row, and cache-warming banner.
- Backend locale persistence through `User.default_language`.
- XCUITest screenshot harness for all 45 `AppLocale` country codes.

### Changed

- Bumped `MARKETING_VERSION` from `1.0` to `2.0.0`.

## [0.7.1] — 2026-05-11

Market Data first-render polish — the screen now lands on real data
instead of an empty-state when reached from `HomeView`, mirroring the
frontend's `MarketData` route.

### Changed

- **Default timeframe** is now `1m` (was `1h`). Matches the frontend
  default and the cadence a user opening the screen most commonly
  wants.
- **`loadInstruments(for:)`** auto-picks a default instrument after
  the picker list arrives. Preference order: `BTC-USD` → `BTC-USD-PERP`
  → first market-data-capable instrument from the backend. No-op when
  the user has already chosen an instrument or when the list is
  empty. Removes the "tap the picker first" friction reviewers hit on
  fresh launch.

## [0.7.0] — 2026-05-11

Market data viewing — the iOS app gains its first read-only chart
surface, mirroring the frontend's `MarketData` route. Reaches the
backend via the same REST + WebSocket layer that powers the existing
positions / orders / alerts screens, with no server-side changes.

### Added

- **`MarketDataView`** — single deep-view screen with exchange /
  instrument / timeframe selection, 2x2 metric grid (last price,
  24h change %, 24h high, 24h low), and a Swift Charts candlestick
  chart. Reached from `HomeView` via a `READ_MARKET_DATA`-gated
  `NavigationLink` (the gate is plumbed correctly for future role
  shaping even though all current production roles hold the
  permission).
- **`MarketDataViewModel`** — `@MainActor @Observable` VM with a
  generation-token discipline that drops stale REST/WS results
  after a fast selection switch. WS frames observed via the
  Combine `state.$lastCandle.values.dropFirst()` pattern matching
  `PositionsViewModel`. Leading-edge 200 ms throttle suppresses
  render storms during active markets without losing the trailing
  flush — buffered frames apply in `open_at` order when the next
  window opens.
- **`APIClient.fetchExchanges()`** + **`fetchCandles(...)`** on
  the existing `APIClientProtocol`. The `/candles` route declares
  `response_model=None` server-side, so the iOS decode wrapper
  (`CandleListResponseLocal`) ships in `APIClient.swift` rather
  than the generated `APITypes.swift`. The fetch helper uses a
  `.custom` `JSONDecoder` strategy that accepts ISO 8601 with OR
  without fractional seconds; the same strategy now backs the WS
  dispatcher so streaming candle/tick frames decode reliably.
- **WS prefix-aware allow-list.** `WebSocketManager.replayPendingSubscriptions`
  widens its filter to accept any topic whose root is in the
  server-shipped `available_topics`. This keeps the v0.6.0 root-only
  topics (`system.heartbeats.`, `orders.events.`) matching exactly
  while letting concrete `market.{exchange}.{instrument}.candles.{tf}`
  subscriptions survive a reauth.
- **`MarketCandle`** normalized type — `Decimal` storage for OHLCV
  to avoid the binary-float noise that `Decimal(_: Double)` carries.
  Conversion via `Decimal(string: String(describing:))` on the
  REST + WS boundary.
- **Screenshot** in `docs/screenshots/08-market-data.png` —
  BTC-USD on kraken at 1m, Swift Charts custom candlesticks with
  BrandGreen / BrandRed semantics and tight Y-axis auto-scale.

### Changed

- **`HomeView`** now injects `@EnvironmentObject var authService:
  AuthService` (previously only consumed by `PositionsView` /
  `OrdersView` / `SettingsView`).
- **`WSState`** gains `@Published lastCandle: CandleData?` and
  `lastTick: TickData?` slots, written by the WS dispatcher when
  `type == "candle"` / `type == "tick"` frames arrive.

### DEBUG-only

- Three `#if DEBUG`-gated UserDefaults hooks support the dev /
  screenshot pipeline when AppleScript / cliclick can't drive
  Simulator UI (macOS Accessibility permission missing):
  `snapper.devAutoLoginUser` + `snapper.devAutoLoginPass`,
  `snapper.devStartOnMarket`, and an auto-select of BTC-USD on
  the 1m timeframe. None of these read in release builds.

## [0.6.0] — 2026-05-07

Live data over WebSocket — closes the gap where the iOS client
authenticated but never subscribed to any topic, leaving the Home
tab stuck on "Connected · waiting for heartbeat" forever and
forcing pull-to-refresh on Orders / Positions tabs.

### Added

- **Auto-subscribe on auth_complete and reauth_ok.** The client now
  intersects an iOS-side preferred-defaults list
  (`system.heartbeats.`, `orders.events.`) with the server-shipped
  per-role `available_topics` and subscribes to the result. VIEWER
  role lands `system.heartbeats.` only (CREATE_ORDERS gate denies
  `orders.events.`); OPERATOR + ADMIN land both. No iOS-side
  hardcoded role-permission logic — the server's allow-list is the
  single source of truth.
- **`ExecutionData` frame handling.** `WSState.lastExecution` slot
  + dispatcher case decode `type: "execution"` frames so the
  fill-event payload is observable from ViewModels.
- **Debounced live-reload in `OrdersViewModel` + `PositionsViewModel`.**
  Each VM exposes `start/stopObservingLiveUpdates(from: WSState)`
  and observes the relevant `@Published` slots
  (`lastOrderEvent` + `lastExecution` for Orders; `lastExecution`
  for Positions) via `for await ... in state.$X.values.dropFirst()`.
  Frame arrival schedules a 250ms debounced REST reload; bursts
  coalesce into one network round-trip. SwiftUI `.task(id:)` cancel
  handler drives `stopObservingLiveUpdates()` on view dismount /
  wallet-selection change.

### Fixed

- **Home dot stuck on "Connected · waiting for heartbeat".** The
  TimelineView-driven freshness dot at
  `HomeView.swift:181-193` reads `WSState.lastHeartbeatAt`. Without
  a `system.heartbeats.` subscription the slot stayed `nil` and the
  dot never turned green. Auto-subscribe makes it green within 1-2
  seconds of WS connect.
- **Stale subscription replay across role downgrade.**
  `disconnect()` now clears `subscribedTopics` +
  `pendingSubscriptions` so a logout-and-login as a different role
  cannot replay topics the new role's `available_topics` denies.
  `replayPendingSubscriptions` filters its merged set through the
  current role's allow-list as defense-in-depth for reauth paths
  that don't go through `disconnect()`.

### Tests

- 5 new `WebSocketManagerTests`: preferred-defaults intersection
  (OPERATOR + VIEWER cases), reauth_ok re-fires, execution-frame
  dispatch, role-downgrade replay clear (RBAC leak guard).
- 5 new `OrdersViewModelTests`: `dropFirst` skip on observation
  start, post-start fire, burst coalesce, stop cancels pending,
  restart self-cleans prior observation.
- 3 new `PositionsViewModelTests`: equivalent dropFirst /
  post-start / stop-cancels for the `lastExecution`-only path.
- 2 new fixture files: `OrderEventDataFixture` + `ExecutionDataFixture`.

## [0.5.0] — 2026-05-07

Notification follow-up — TestFlight v0.4.0 build 17 had two
user-visible bugs in the iOS-push surface that this release closes
(device-registration 422 loop, Alerts tab 404), plus a missing
close-path for device overrides users had asked for.

### Fixed

- **Device registration was 422'ing every attempt.** A backend-side
  envelope-validation regression rejected the ISO 8601 datetime
  strings `JSONEncoder.iso8601` produces in the `timestamp` field,
  leaving every iOS device-registration retry stuck on
  `Failed (attempt N)` in Settings → Notifications. Same regression
  affected `PATCH /api/devices/{id}/prefs` and
  `PATCH /api/alert_defaults`. Fixed server-side; this iOS release
  exists to ship the build that pairs with the corrected backend.
- **Alerts tab silently 404'd.** `APIClient.fetchAlertHistory` was
  hitting `/api/alerts` (the single-row sub-route) instead of
  `/api/alerts/history`. UI surfaced as "Could not load alerts" with
  only a Retry button. The single-row `fetchAlert(publicId:)` was
  unaffected — only the list path was wrong.

### Added

- **Swipe-to-delete on device overrides.** User feedback flagged
  there was no way to remove a per-(device, alert_type, scope)
  override after creating one. `NotificationPrefsView` now has a
  trailing swipe action on every device-pref row that fires
  `NotificationPrefsViewModel.revokeDevicePref(prefPublicId:)`
  against the new `POST /api/devices/{id}/prefs/{pref_id}/revoke`
  backend endpoint. Backend convention is POST + envelope (not
  DELETE) so every write carries client-side provenance for the
  gap detector — same pattern as `cancelOrder` /
  `revokeScopeGrant`. UX is optimistic-remove with revert-on-
  failure (matches `mutateDefault`) and 404 is treated as success
  so a double-tap on swipe doesn't leave a stuck row.

### Tests

- 4 new VM tests on `NotificationPrefsViewModel.revokeDevicePref`:
  happy path optimistic remove, revert on non-404 failure, 404
  treated as success, no-op when no device registered.
- Generated `APITypes.swift` refresh picks up
  `RevokeDevicePref{Body,Command,Response}` plus several types
  that were re-added to the OpenAPI spec via `openapi_extra`
  restoration on the backend side.
- `APIClientSurfaceTests` updated to assert the corrected
  `/api/alerts/history` wire path (both fixture-mapped happy-path
  and the empty-cursor edge case).

### Documentation

- The v0.3.1-era MVVM extraction work that lived in [Unreleased]
  below this entry shipped to users as part of the v0.4.0
  TestFlight build (build 17 / Xcode Cloud) but was never moved
  into the v0.4.0 changelog block. Left in place as a historical
  marker; do not interpret as still-pending work.

## [Pre-0.4.0 MVVM rollup — already shipped in build 17]

### Tooling

- **Swift comment scanner** at `scripts/check_no_comments.py` —
  mirrors the parent monorepo's Python scanner for Swift sources.
  Rejects `//` and `/* ... */` non-doc comments while allowing
  `///` and `/** ... */` documentation comments. Wired to
  `make check-all` in report-only mode (default); `make check-no-
  comments-strict` flips to fail-on-finding for clean files. Legacy
  iOS sources retain ~366 non-doc comments (43 files) carried over
  from v0.1.x → v0.3.1; cleanup tracked for a follow-up release.

### Sonar

- Ignored `swift:S1186` on `BackendURLEditor.swift` (SwiftUI Preview
  empty-closure stubs) and `swift:S1075` on the same file plus
  `BackendURLStore.swift` (intentional design constants —
  `inputPlaceholder` is UX placeholder text, `compiledInFallbackURLString`
  is the dev-only fallback when `Configuration.plist` fails to
  load). Sonar's accept-via-comment workaround conflicts with the
  no-comments rule; suppressing at config level keeps both rules
  green.
- Ignored `swift:S2068` on `LoginViewModel.swift` (the SwiftUI
  ``@State`` `password` binding is form input, not a stored secret —
  historically marked False-Positive in the SonarCloud UI; the
  ignore lifts that mark into version control so it survives
  line-number drift across releases) and `swift:S7435` on
  `DeviceRegistrationService.swift` (`identifierForVendor` is the
  Apple-recommended privacy-friendly device id, declared in
  `PrivacyInfo.xcprivacy` under the DeviceID Required-Reason API).

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

- **Sonar coverage export now reports xccov line coverage only.**
  `xccov` archive subrange tuples are execution-count metadata, not
  branch counters, so the converter no longer maps them to Sonar
  `branchesToCover` / `coveredBranches` fields. This removes false
  uncovered-condition findings for Swift switches, guards, and
  closures while preserving executable-line coverage.
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
- **`NotificationPrefsView` MVVM extraction — `NotificationPrefsViewModel`**
  at `Snapper/ViewModels/NotificationPrefsViewModel.swift`. The
  View shrinks from a 464-line state-and-async holder to a thin
  Form binder (~270 lines including the inline AlertDefaultRow,
  DevicePrefRow, and SheetIdentifier helpers). The VM owns the
  alert-defaults dictionary, device-prefs array, devicePublicId
  resolution, isLoading, loadError, the per-row inflightAlertTypes
  set, the `load()` async, the `mutateDefault()` optimistic-
  update flow, and `applySavedPref(_:)`. Static helpers
  (`alertTypes`, `priorityValues`, `displayName`,
  `priorityDisplayName`, `scopeLabel`, `summaryLabel`,
  `formatMinutes`, `applySavedPref`, `makeDefaultCommand`)
  preserved verbatim. Sheet presentation flag (`sheetMode`) stays
  `@State` in the View. Cross-file callsites in `EditDevicePrefView`,
  `NotificationPrefsViewTests`, `EditDevicePrefViewTests`
  retargeted to `NotificationPrefsViewModel.X` via mechanical sed.
  13 new VM tests cover load happy / device-skipped / defaults-
  failure / device-pref-failure-not-clobbering-defaults branches,
  mutateDefault success / clear-prior-error / failure paths,
  applySavedPref replace-by-id / append-new-scope, and static
  helper sanity (displayName, formatMinutes, scopeLabel).
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
- **`NotificationPrefsView` load is now actually parallel.** The
  pre-MVVM body's docstring claimed "fetched in parallel via
  `async let`" but the implementation was sequential (Q9b in the
  v0.3.1 architect consensus). The VM now genuinely fans out the
  alert-defaults + device-prefs fetches concurrently via
  `async let`, with the device-prefs branch short-circuited if
  the device isn't yet registered.

### Tests

- Test count: 205 (post-foundations) → 309 (+21 NewOrderSheet
  pilot, +14 WalletPicker, +11 AttachBracket, +12 AttachTrailing,
  +17 OrdersView, +16 PositionsView, +13 NotificationPrefs).

### Coverage

- **Sonar-reportable coverage: 83.8%** at v0.3.1 ship (target was
  ≥80% global). Layered breakdown:
  - ViewModels (`Snapper/ViewModels/`): 97.0%
  - Services (`Snapper/Services/`): 75.8%
  - Config (`Snapper/Config/`): 68.0%
  - Models (`Snapper/Models/`, non-generated): 54.5%
- **Strategy A (Q4 fallback) enacted** in
  `sonar-project.properties`: SwiftUI chrome excluded from
  coverage measurement (`Snapper/Views/**`,
  `Snapper/SnapperApp.swift`, `Snapper/Models/Generated/**`,
  `SnapperTests/**`). Documented in `docs/architecture-mvvm.md`.
  The exclusion is principled: post-MVVM, View files are
  declarative SwiftUI layout (chrome) — every piece of testable
  business logic lives in `@Observable` ViewModels. View body
  unit tests would require ViewInspector, which the architect
  consensus rejected for v0.3.1 (fragile to SwiftUI internals).
  New tests live under `SnapperTests/ViewModels/` and cover
  load / failure / race / submit / re-entry / idempotency /
  AppState mutation branches against the lock-protected
  `MockAPIClient` + per-test ephemeral `AppState(userDefaults:)`.

## [0.4.0] — 2026-05-06

App Store self-hoster slice — the listing copy ("Self-hosted
trading copilot — you provide the URL during sign-in") is now true
of the binary. Two surfaces ship together:

### Added

- **`X-CSRF-Token` header plumbing in `APIClient`** for every
  non-safe HTTP method (POST / PATCH / DELETE / PUT). Echoes the
  `csrf_token` cookie value into the header, scoped to the request
  URL via `HTTPCookieStorage.cookies(for:)` so cross-host cookies
  don't leak after a backend switch. Empty cookie values skip
  attachment so the backend can return its native missing-CSRF
  error rather than receiving a synthetic empty header. Closes a
  latent production bug where every iOS-driven `/api/devices`
  mutation silently 403'd because the header was missing.
- **`BackendURLStore` runtime override** at
  `Snapper/Config/BackendURLStore.swift`. Final class with
  `OSAllocatedUnfairLock`-protected mutable state so synchronous
  reads from `APIClient`'s `@Sendable` URL providers stay actor-
  free. Static `canonicalize()` validates origin-only URLs (no
  path / query / fragment / userinfo / userpass / `ws://` /
  `wss://`); release builds reject `http://` to satisfy ATS.
  Persisted overrides are revalidated against current policy on
  every load.
- **`AppConfig.baseURL`** now resolves through the store; the
  bundled `Configuration.plist` value patched at Xcode Cloud build
  time by `ci_post_clone.sh` remains the fallback. Existing
  string-concatenation call sites in `APIClient` /
  `WebSocketManager` / `AuthService` keep working unchanged.
- **`BackendURLEditor`** shared SwiftUI view at
  `Snapper/Views/Components/BackendURLEditor.swift`. Inline
  canonicalize preview + Save / Reset / Cancel actions with
  build-policy-sensitive validation copy.
- **LoginView Advanced disclosure** — collapsed by default at the
  bottom of the form. Self-hosters expand, enter their backend
  URL, Save → store override is persisted directly (no logout —
  user is unauthenticated). Casual users never see this.
- **SettingsView Change backend… button** — confirm alert ("you
  will be signed out") followed by an editor sheet. On Save /
  Reset the sheet runs a sequenced sign-out:
  1. `WebSocketManager.disconnect()` — first, so the old socket
     does not block on server-side logout.
  2. `await AuthService.logout()` — non-throwing; flips
     `isAuthenticated = false` at the end.
  3. Cookie cleanup scoped by old host (including `.domain.`
     variants) so path-scoped session cookies are dropped.
  4. `URLCache.shared.removeAllCachedResponses()` + AppState
     wallet / operator / selectedWallet caches reset.
  5. `saveOverride()` / `clearOverride()` LAST — any in-flight
     401 refresh-retry that races still resolves against the OLD
     URL via the dynamic provider.
  After step 2 the SnapperApp root conditional swaps to
  LoginView automatically; the user re-authenticates against the
  new backend.

### Changed

- ATS posture for the App Store binary stays HTTPS-only with
  publicly trusted certificates. Self-hosters running plain HTTP
  or self-signed backends must front their backend with an HTTPS
  reverse proxy or build from source — the editor's inline
  validation copy explains this in release builds.

### Tests

- 13 `APIClientCSRFTests` covering the safe / non-safe × cookie
  present / absent / empty / foreign-host matrix plus an
  end-to-end `RegisterDeviceCommand` round trip that captures the
  on-the-wire request to assert the header lands.
- 28 `BackendURLStoreTests` covering every `canonicalize()`
  branch (including the loopback-only DEBUG-`http://` rule) +
  override roundtrip + invalid-on-launch recovery + a cross-
  `Sendable` read from a detached Task.
- 7 `BackendURLEditorTests` covering preview reactivity + button
  enable matrix + build-policy-sensitive validation copy.

### Deferred to v0.5.0+

The full mid-session smooth-switch coordinator (no sign-out
required, with progress overlay, in-flight REST race guards,
`DeviceRegistrationService` switch-prep + barrier, old-backend
device DELETE) is tracked internally and only ships if real users
complain about the sign-out-required UX.

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

[Unreleased]: https://github.com/mateusz-klatt/snapper-ios/compare/v3.0.0.28...HEAD
[3.0.0]: https://github.com/mateusz-klatt/snapper-ios/releases/tag/v3.0.0.28
[2.0.2]: https://github.com/mateusz-klatt/snapper-ios/releases/tag/v2.0.2-build25
[2.0.1]: https://github.com/mateusz-klatt/snapper-ios/releases/tag/v2.0.1
[2.0.0]: https://github.com/mateusz-klatt/snapper-ios/releases/tag/v2.0.0
[0.7.1]: https://github.com/mateusz-klatt/snapper-ios/releases/tag/v0.7.1
[0.7.0]: https://github.com/mateusz-klatt/snapper-ios/releases/tag/v0.7.0
[0.6.0]: https://github.com/mateusz-klatt/snapper-ios/releases/tag/v0.6.0
[0.5.0]: https://github.com/mateusz-klatt/snapper-ios/releases/tag/v0.5.0
[0.4.0]: https://github.com/mateusz-klatt/snapper-ios/releases/tag/v0.4.0
[0.3.0]: https://github.com/mateusz-klatt/snapper-ios/releases/tag/v0.3.0
[0.2.0]: https://github.com/mateusz-klatt/snapper-ios/releases/tag/v0.2.0
[0.1.3]: https://github.com/mateusz-klatt/snapper-ios/releases/tag/v0.1.3
[0.1.2]: https://github.com/mateusz-klatt/snapper-ios/releases/tag/v0.1.2
[0.1.1]: https://github.com/mateusz-klatt/snapper-ios/releases/tag/v0.1.1
[0.1.0]: https://github.com/mateusz-klatt/snapper-ios/releases/tag/v0.1.0
