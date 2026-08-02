# Known limitations

Open items in the current public source. Each has a tracked path forward; nothing here is permanent.

## Generated types are upstream-owned snapshots

`Snapper/Models/Generated/{APITypes,WSMessages,Permissions}.swift` are produced by the Snapper backend's regeneration script (`scripts/generate_types.py --ios` in the upstream repo). External contributors cannot regenerate them from this iOS subtree alone, and no public iOS generator script exists under `ios/scripts/` today.

**Plan**: add a public `scripts/gen-from-backend.sh` flow that can curl a running backend's `/openapi.json` plus the published WebSocket schema document. Until then, hand-edits to generated files will be lost on the next upstream regen; open an issue describing the schema-side fix instead of patching generated Swift.

## Bundle ID and signing team are placeholders

`project.yml` ships with `PRODUCT_BUNDLE_IDENTIFIER=com.example.snapper` and no `DEVELOPMENT_TEAM`. A fork can build for the simulator immediately; archiving for a device requires the contributor's own team:

```bash
make archive DEVELOPMENT_TEAM=XXXXXXXXXX PRODUCT_BUNDLE_IDENTIFIER=com.example.snapper
```

The maintainer's TestFlight bundle id and team live outside the public source tree and get injected by Xcode Cloud through `ci_scripts/ci_post_clone.sh`.

## SonarCloud workflow on fork pull requests

`sonarcloud.yml` runs on `pull_request` to `master`, but GitHub does not pass repository secrets (including `SONAR_TOKEN`) to workflows triggered by fork PRs. Fork PRs will see a red Sonar check that means "couldn't run scan" rather than "scan found problems"; same-repo PRs are unaffected. The maintainer reviews the Sonar result on the post-merge `push` run.

**Plan**: if external contributor activity grows, gate the Sonar workflow with `if: github.event.pull_request.head.repo.full_name == github.repository` so fork PRs see a neutral skip instead of a red check.

## iOS deployment target tracks the CI runner image

The deployment target is **iOS 26.2** to match the SDK shipped with Xcode 26.2 on GitHub Actions' `macos-26` runner image. Features that require a newer SDK are unavailable until either the runner image upgrades or the project moves those call sites behind `@available` conditionals.

## SwiftUI chrome lowers full-source Sonar coverage

SonarCloud analyzes every file under `Snapper/` and applies the generic Xcode coverage report without source or coverage exclusions. This includes SwiftUI views, `SnapperApp.swift`, and generated models even when Xcode reports no executable coverage for their declarative or generated lines.

This is not a missing CI step: `make coverage` runs the complete Xcode coverage job and exports `build/sonarqube-generic-coverage.xml`. Post-MVVM, business logic lives in `Snapper/ViewModels/`, services, config, and model helpers, so the layered figures in `docs/architecture-mvvm.md` remain more actionable than the aggregate percentage.

**Plan**: keep moving reusable decisions into ViewModels or pure helpers as screens evolve. ViewInspector and snapshot-testing dependencies remain out of scope so the project stays zero-SPM-dependency.
