# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/mateusz-klatt/snapper-ios/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/mateusz-klatt/snapper-ios/releases/tag/v0.1.2
[0.1.1]: https://github.com/mateusz-klatt/snapper-ios/releases/tag/v0.1.1
[0.1.0]: https://github.com/mateusz-klatt/snapper-ios/releases/tag/v0.1.0
