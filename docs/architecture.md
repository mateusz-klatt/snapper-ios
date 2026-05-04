# Snapper iOS — architecture

This document captures the design decisions a reader would otherwise need to reverse-engineer from the code. It complements the source-level doc comments rather than replacing them.

## Concurrency posture

- **Swift 6.0 strict concurrency** throughout. No `@unchecked Sendable` outside test fakes that hand-prove their own synchronization.
- Auth and WebSocket state live on `@MainActor`. UI binds to them directly via `@EnvironmentObject` without crossing actor boundaries.
- `DeviceRegistrationService` is a Swift `actor`. APNs token + login state arrive on different async paths; the actor serializes the handshake so a registration POST only fires when both inputs are present.
- `EnvelopeMinter` is `@MainActor` (single mint sequence per app session). Tests inject a deterministic `Provenance` so the per-attempt `publicId` / `sequenceId` are reproducible.

## Networking layer

### REST (`APIClient`)

- Generic `request<T: Decodable>` core that all endpoint methods delegate to.
- One-shot 401 handling: on `401`, call `AuthService.fetchFreshWsToken()` to refresh, then replay the original request once. A second 401 forces logout and routes the UI to `LoginView` via `SnapperApp`'s `isAuthenticated` observer.
- Path segments interpolated through `encodePathSegment` (percent-encoded with `.urlPathAllowed`); query strings built with `URLComponents` + `URLQueryItem` so opaque server-emitted cursors with reserved characters round-trip correctly.
- ISO-8601 date encoding/decoding on both sides — backend Pydantic models expect ISO strings, not Unix timestamps.

### WebSocket (`WebSocketManager`)

- Connection state machine: `disconnected → connecting → authenticating → connected → (error | authFailed | disconnected)`. `.authFailed` is terminal — only logout can leave it.
- Reconnect: exponential backoff `[base * 2^n, base * 2^n * 1.3]` with a 300s ceiling. No hard attempt cap so a phone returning online after a long offline period recovers without user intervention.
- Stale-task guard around every async suspension in the receive loop — when a reconnect wins the race, the older task's late `receive()` does not corrupt the newer connection's state.
- Proactive `ws_token` refresh fires at 80% of the token's TTL so a refresh round-trip is in flight before the server-issued token actually expires.

### Envelope provenance (`EnvelopeMinter`)

- Mirrors the cross-platform contract the bridge enforces (`integrations/snapper-mcp/src/envelope.ts`):
  - Per-app **session_id** (stable for the app's lifetime; backend gap detection uses it to scope sequence-number expectations).
  - Two **independent counters** — control (commands) and telemetry (heartbeats / metrics) — so a flood of telemetry frames never fragments the control sequence.
  - Per-frame **publicId** (UUID v4) + millisecond-precision ISO-8601 **timestamp**.
- All iOS-originated commands stamp provenance before send. The backend handler strips and re-mints provenance on its side, but the iOS-side stamping keeps the gap detector happy and gives the client traceable correlation ids.

## Auth flow

- Session-cookie based (`URLSession.shared` cookie jar). Login `POST /api/auth/login` with `username`/`password`; backend sets `session_id` and `csrf_token` cookies.
- Refresh: `POST /api/auth/refresh?return_tokens=true` returns a new `ws_token` (used by `WebSocketManager`) plus rotated session cookies.
- Logout: `POST /api/auth/logout` invalidates the session server-side; client-side state is cleared regardless.
- `WebSocketManager.wsToken` is a separate token from auth — used only for the WS handshake (`?token=<ws_token>` URL param). It rotates independently of the session cookie.

See [`known-limitations.md`](known-limitations.md) for the CSRF header gap on iOS mutating REST requests (frontend sends `X-CSRF-Token`; iOS does not yet — scheduled for v0.2.0).

## App lifecycle

- `SnapperApp` owns the WS lifecycle: `scenePhase` → `.active` connects, `.background` disconnects. The socket must not hold the radio while the app is suspended.
- `MainTabView` is purely a tab switcher; it does not manage the WS connection so a presented modal does not kill the socket.
- `AppDelegate` handles APNs token receipt + notification taps; everything hops to `@MainActor` immediately because `UIApplicationDelegate` itself is not main-isolated in Swift 6.

## State management

- `AppState` (`@MainActor` singleton) holds wallet selection + cached operator/wallet catalogues. Persisted to `UserDefaults` so a relaunch lands on the same wallet.
- Trading screens fetch fresh data on appear via `.task(id:)` modifiers keyed on the selected wallet — switching wallets re-runs the fetch automatically.

## Testing strategy

- `XCTest` for the bulk of the suite + `Swift Testing` for newer additions.
- `MockURLProtocol` hosts simulated REST responses; tests assert on the actual `URLRequest` shape (path, method, headers, body) rather than calling stubs that bypass the network layer.
- `FakeWebSocketTask` + `FakeWebSocketTaskFactory` stand in for `URLSessionWebSocketTask` so reconnect-race tests are deterministic.
- `FakeSleeper` (actor) replaces `Task.sleep` in tests that exercise backoff timing — verifies the manager really waits, without waiting in real time.
- `EnvelopeMinter.Provenance` is value-injectable so tests stamp predictable session/sequence ids onto outbound commands.

## Build system

- **XcodeGen** (`project.yml`) is the source of truth. The generated `Snapper.xcodeproj` is `.gitignore`'d — every contributor regenerates it locally, so signing identities and per-developer Xcode settings stay out of the tree.
- `Makefile` is the public surface (`make build`, `make test`, `make coverage`, `make archive`). CI uses the same Make targets the maintainer uses locally.
- Zero Swift Package Manager dependencies — everything runs on `Foundation` / `SwiftUI` / `Combine`. Keeps the supply chain trivial to audit.
