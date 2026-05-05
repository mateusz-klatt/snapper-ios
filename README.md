# Snapper iOS

Native iOS client for the [Snapper](https://github.com/mateusz-klatt/snapper) trading platform — a SwiftUI app that lets the maintainer run trading actions from a phone against a self-hosted Snapper backend.

## Status

- **v0.1.x** — Slice 1: order entry, cancel, brackets, trailing stops, alerts, push notifications, wallet picker. See [`CHANGELOG.md`](CHANGELOG.md) for the per-release breakdown.
- Public source mirror; the maintainer owns the App Store / TestFlight pipeline. Forks build for the simulator out of the box.

## Requirements

- macOS with **Xcode 26.2** (matches the iOS 26.2 SDK the deployment target requires)
- **XcodeGen** (`brew install xcodegen`)
- A running Snapper backend (the app defaults to `http://localhost:8000` — pair with `make dev-backend` from the parent repo)

## Build & test

```bash
make setup     # generates Snapper.xcodeproj from project.yml
make build     # iPhone 17 Pro simulator
make test      # full XCTest + Swift Testing suites
```

The Makefile uses sensible simulator defaults that match the GitHub Actions `macos-26` runner image. Override at the command line if needed:

```bash
make test SIMULATOR='iPhone 17' SIMULATOR_OS='26.2'
```

## Configure the backend URL

Edit `Snapper/Config/Configuration.plist` and change `BaseURL`. The default is `http://localhost:8000` so a clean clone connects to a developer's local backend; production users override this in their own private build pipeline.

`Environment.swift` validates the plist at startup and crashes loud in DEBUG builds if `BaseURL` or `APIPrefix` are missing — better a fatal launch error than a vague invalid-URL deep in a request path.

## Architecture

- **Swift 6.0** with strict concurrency. Services use actors (`DeviceRegistrationService`) and `@MainActor` isolation (`AuthService`, `WebSocketManager`); cross-actor protocols are `Sendable`.
- **MVVM-with-pragmatic-View-fetching**: `LoginViewModel` is the textbook example; data-heavy tabs (`HomeView`, `OrdersView`, `PositionsView`) call `APIClient.shared` directly to keep the view-model layer minimal. v0.2.0 may tighten this.
- **Networking**:
  - `APIClient` — REST with one-shot 401-refresh-and-replay, generic `Decodable` body.
  - `WebSocketManager` — capped exponential backoff reconnect (300s ceiling), proactive `ws_token` refresh, terminal `.authFailed` state distinct from transient `.error`.
  - `EnvelopeMinter` — actor-isolated provenance stamper (per-app session id, separate control / telemetry counters, ms-precision ISO-8601). Mirrors the bridge's `integrations/snapper-mcp/src/envelope.ts` so backend gap detection sees a coherent session across iOS-originated commands.
- **Generated types** under `Snapper/Models/Generated/` are upstream-owned snapshots of the backend's OpenAPI + WebSocket schemas. External contributors cannot regenerate them without backend access — see [`docs/known-limitations.md`](docs/known-limitations.md).

## Continuous integration

GitHub Actions runs on `macos-26`:

- `ci.yml` — `make build && make test` on every push to `master` and every PR.
- `gitleaks.yml` — secret scan on push / PR / weekly cron.
- `sonarcloud.yml` — coverage scan via Xcode `xccov` → SonarCloud generic XML.

## Signing & release

A fork can build the unsigned simulator target without touching anything. To archive for a real device, set the team:

```bash
make archive DEVELOPMENT_TEAM=XXXXXXXXXX PRODUCT_BUNDLE_IDENTIFIER=com.example.snapper
```

The repo intentionally ships with `com.example.snapper` and no hardcoded team — the maintainer's TestFlight bundle id and team live outside the public source tree.

## Repository conventions

- All commits via fork-and-PR; see [`CONTRIBUTING.md`](CONTRIBUTING.md).
- License: [MIT](LICENSE).
- Security disclosures: [`SECURITY.md`](SECURITY.md).
- Architectural deep-dive: [`docs/architecture.md`](docs/architecture.md).
- Privacy policy (App Store): [`docs/privacy-policy.md`](docs/privacy-policy.md) — also published via GitHub Pages at https://mateusz-klatt.github.io/snapper-ios/privacy-policy/.
