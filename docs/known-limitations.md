# Known limitations — v0.1.0

Items deferred from the public release. Each has a tracked path forward; nothing here is permanent.

## CSRF header on mutating REST requests

The backend accepts cookie-based session auth + a `X-CSRF-Token` header on mutating endpoints. The frontend (`snapper-frontend`) sends the header. The iOS client does not — refresh responses include a `csrfToken` field but `AuthService` only stores the `ws_token`. Mutations work today because the backend's CSRF check is wired only on the routes the browser flow uses; iOS endpoints fall through. This is a known portfolio-quality gap.

**Plan**: v0.2.0 minor release will read the `csrfToken` from the refresh payload, persist it alongside `ws_token`, and set `X-CSRF-Token` on every mutating request that `APIClient` issues.

## Generated types are upstream-owned snapshots

`Snapper/Models/Generated/{APITypes,WSMessages,Permissions}.swift` are produced by the Snapper backend's regeneration script (`scripts/generate_types.py --ios` in the upstream repo). External contributors cannot regenerate them without backend source access.

**Plan**: v0.2.0 will add a `scripts/gen-from-backend.sh` analog of the frontend's `gen-from-backend.sh`, which curls a running backend's `/openapi.json` and a published WebSocket schema document. Until then, hand-edits to generated files will be lost on the next upstream regen — open an issue describing the schema-side fix instead of patching the generated file.

## Bundle ID and signing team are placeholders

`project.yml` ships with `PRODUCT_BUNDLE_IDENTIFIER=com.example.snapper` and no `DEVELOPMENT_TEAM`. A fork can build for the simulator immediately; archiving for a device requires the contributor's own team:

```bash
make archive DEVELOPMENT_TEAM=XXXXXXXXXX PRODUCT_BUNDLE_IDENTIFIER=com.example.snapper
```

The maintainer's TestFlight bundle id and team live outside the public source tree and get injected by a private build pipeline.

## SonarCloud workflow on fork pull requests

`sonarcloud.yml` runs on `pull_request` to `master`, but GitHub does not pass repository secrets (including `SONAR_TOKEN`) to workflows triggered by fork PRs. Fork PRs will see a red Sonar check that means "couldn't run scan" rather than "scan found problems"; same-repo PRs are unaffected. The maintainer reviews the Sonar result on the post-merge `push` run.

**Plan**: if external contributor activity grows, gate the Sonar workflow with `if: github.event.pull_request.head.repo.full_name == github.repository` so fork PRs see a neutral skip instead of a red check.

## iOS deployment target lags Apple's latest

The deployment target is **iOS 26.2** to match the SDK shipped with Xcode 26.2 on GitHub Actions' `macos-26` runner image. Newer iOS-26.x features are unavailable until either the runner image upgrades or the project moves to `@available` conditionals.
