# Architecture: MVVM seams in snapper-ios

Adopted in v0.3.1 as a coverage-driven refactor. The View / VM
split, mocking strategy, and concurrency rules are captured below;
each release-critical file lands its own PR following the same
shape.

## The split

Each release-critical View has a paired `@MainActor @Observable`
ViewModel. The View owns layout + transient presentation flags;
the VM owns load / submit / error / business state.

| Concern | Owner | Example |
|---|---|---|
| Layout / SwiftUI body | View | `Form { Section { ... } }` |
| Sheet / alert booleans | View `@State` | `presentingNewOrder`, `pendingClosePosition` |
| Form `FocusState`, navigation | View `@State` | `@FocusState private var field` |
| Form-binding scaffolding (`Binding<Bool>` adapters for sheets) | View | `Binding(get: { ... != nil }, set: { ... })` |
| Data arrays | VM | `var positions: [PositionSnapshot]` |
| Loading + error state | VM | `var isLoading: Bool`, `var loadError: APIError?` |
| Submit / mutation errors | VM | `var submitError: String?` |
| Async load / submit methods | VM | `func load() async`, `func submitMarketReduce(...) async -> Bool` |
| Filtered / derived getters | VM | `var filteredOpen: [OrderStatus]` |

## ViewModel contract

```swift
@MainActor
@Observable
final class XxxViewModel {

    // MARK: - Public state (read by View)

    var data: [Item] = []
    var isLoading = false
    var loadError: APIError?
    var submitError: String?

    // MARK: - Dependencies (init-injected)

    private let api: APIClientProtocol
    private let appState: AppState

    init(api: APIClientProtocol = APIClient.shared, appState: AppState = AppState.shared) {
        self.api = api
        self.appState = appState
    }

    // MARK: - Behavior (called by View)

    func load() async { ... }
    func submit(...) async -> Bool { ... }
}
```

## Service mocking strategy

| Surface | Mock pattern |
|---|---|
| ViewModel tests | Inject `MockAPIClient` — closure-overridable class conforming to `APIClientProtocol`. Lock-protected handler slots so concurrent VM calls (`async let` fan-out) don't race. Default behavior: throw `APIError.invalidResponse` so unconfigured calls fail loudly. |
| Service-stack tests (`APIClientNetworkTests` etc.) | Keep `URLProtocol` interception against the concrete `APIClient` to verify JSON encode / decode contract end-to-end. |
| Auth seam | `AuthRefreshing` protocol (legacy, in `Services/Protocols.swift`); `AuthService` is the production conformer. |

## Concurrency rules

- ViewModels are `@MainActor` at the class level. All public methods
  run on the main actor; all stored state is main-actor-isolated.
- `async let` parallel fan-out (e.g. `OrdersViewModel.load()` doing
  orders + executions concurrently) composes cleanly under
  class-level `@MainActor` — the actor suspends during I/O, it
  doesn't serialize concurrent network calls.
- `APIClientProtocol` is `Sendable` so closure-based mocks can cross
  isolation boundaries during concurrency tests.

## Coverage philosophy

Hybrid path enacted in v0.3.1:

1. **Step 1 (Strategy C)** — push load / submit / filter / decision
   logic into VMs (DONE in v0.3.1: NewOrderSheet / WalletPicker /
   AttachBracket / AttachTrailing / OrdersView / PositionsView /
   NotificationPrefsView all extracted; ViewModels directory
   reaches 97% line coverage).
2. **Step 2 (Strategy A — fallback enacted)** — exclude SwiftUI
   chrome from coverage measurement. Configured in
   `sonar-project.properties`:
   - `Snapper/Views/**` — post-MVVM, View files are SwiftUI body
     chrome (declarative layout); the testable logic lives in
     `Snapper/ViewModels/`. View bodies are unreachable without
     ViewInspector.
   - `Snapper/SnapperApp.swift` — app-entry / scene-phase wiring
     not unit-testable without a UIApplication harness.
   - `Snapper/Models/Generated/**` — auto-generated structs.
   - `SnapperTests/**` — industry standard (test code does not
     count to coverage).

Sonar-reportable coverage after exclusions: **83.8%** at v0.3.1
ship (1746/2083 production-logic lines). Layered breakdown:

| Layer | Coverage |
|---|---|
| ViewModels (`Snapper/ViewModels/`) | 97.0% |
| Services (`Snapper/Services/`) | 75.8% |
| Config (`Snapper/Config/`) | 68.0% |
| Models (`Snapper/Models/`, non-generated) | 54.5% |

We deliberately do **not** adopt ViewInspector or snapshot
testing — both were rejected at the v0.3.0 architect consensus
and the rejection was reaffirmed for v0.3.1. ViewInspector is
fragile to SwiftUI internal changes and snapshot testing inflates
coverage without exercising real branches. The honest alternative
is the layered metric above: VMs and services bear the testable
load; chrome is excluded from the denominator.

## When to extract a ViewModel vs not

**Extract** when the View owns:
- Async load / submit methods (`private func load() async`).
- Mutation-result error state (`submitError`, `loadError`).
- Derived collections (filtered / sorted / capped lists).
- Form validation + body building (`canSubmit`, `buildBody`).

**Skip** when the View is:
- Pure layout chrome over a parent-injected closure (small sheets
  like `AttachBracketSheet` / `AttachTrailingStopSheet`).
- A single-purpose row / card type (`PositionCard`, `OrderRow`).
- A wrapper around already-VM-owned state.

## Idempotency keys

Sheets that mint an idempotency key for retry-safe submission
(`NewOrderSheet`, `AttachBracketSheet`, `AttachTrailingStopSheet`)
preserve a single key per presentation:

- VM init (or sheet init) mints the key once.
- Retry within the same sheet reuses the key (backend dedup).
- Sheet dismissal + re-open mints a fresh key (new presentation).

Tests must verify the key is stable across retries inside one
presentation and rotates across presentations.
