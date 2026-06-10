# ci_scripts

Xcode Cloud post-clone hook. Runs in the cloud build environment only; never on a local `make build`.

## Why

The public source tree intentionally ships with neutral defaults so a fork builds for the simulator without an Apple Developer account:

- `project.yml`: `PRODUCT_BUNDLE_IDENTIFIER: com.example.snapper`, no `DEVELOPMENT_TEAM`, `CURRENT_PROJECT_VERSION: 1`, `MARKETING_VERSION: 2.0.2`
- `Snapper/Config/Configuration.plist`: `BaseURL: http://localhost:8000`

For the maintainer's TestFlight / App Store builds those values must be replaced with production values. Keeping the secrets out of the public repo means: configure them as **secret environment variables on the Xcode Cloud Workflow** in App Store Connect; this script reads them and patches the cloned tree before `xcodegen generate` runs.

## Required Workflow Environment Variables (Secrets)

Configure under App Store Connect → Apps → Snapper → Xcode Cloud → Workflow → Edit → Environment.

| Name | Purpose | Example shape |
|---|---|---|
| `SNAPPER_DEVELOPMENT_TEAM` | Apple Developer team id | 10-character alphanumeric |
| `SNAPPER_BUNDLE_IDENTIFIER` | Production bundle id registered in App Store Connect | reverse-DNS string |
| `SNAPPER_BACKEND_URL` | Production backend the released app talks to | full URL with scheme |

Mark each as **Secret** so Apple does not echo the value into build logs.

## Apple-injected variables this script reads

- `CI_BUILD_NUMBER` — Xcode Cloud's per-product build number. The starting value lives at App Store Connect → Apps → Snapper → Xcode Cloud → Settings → Build Number; Xcode Cloud increments from there. The script substitutes whatever Apple supplies into `CURRENT_PROJECT_VERSION`.

`MARKETING_VERSION` (CFBundleShortVersionString) is **not** derived from the git tag. Apple groups TestFlight builds per marketing version, so deriving it from `CI_TAG` would create a fresh tester group on every release and force the maintainer to re-add testers each time. Bumping marketing version is an explicit edit in `project.yml`, made when the maintainer intends a user-visible release. Git tags still drive the release flow + CHANGELOG narrative; the two version concepts simply do not collapse.

## Forks running their own Xcode Cloud

A fork that wants to use this same hook with their own signing identity sets its own values for the three `SNAPPER_*` env vars on its Workflow. The script does not assume any particular team / bundle / URL — it just substitutes whatever the env vars say.
