#!/bin/bash
#
# Xcode Cloud post-clone hook.
#
# Apple runs this script after `git clone` and before package resolution
# (https://developer.apple.com/documentation/xcode/writing-custom-build-scripts).
# Public source ships with neutral defaults so a fork builds for the simulator
# without a developer account; Xcode Cloud overlays the maintainer's signing
# identity, bundle id, backend URL, and a monotonic build number from
# environment variables set on the Workflow in App Store Connect.
#
# Required environment variables (configured as Secrets on the Workflow):
#   SNAPPER_DEVELOPMENT_TEAM   — Apple Developer team id (10-character)
#   SNAPPER_BUNDLE_IDENTIFIER  — production bundle id (e.g. com.example.app)
#   SNAPPER_BACKEND_URL        — production backend (https://...)
#
# Apple-injected variables this script uses:
#   CI_BUILD_NUMBER  — Xcode Cloud's per-product build number. Apple lets
#                       you set the starting value at App Store Connect ->
#                       Xcode Cloud -> Settings -> Build Number, so this
#                       script just substitutes whatever Apple supplies.
#
# Notably NOT used: CI_TAG. MARKETING_VERSION (CFBundleShortVersionString)
# stays at the value committed in project.yml so all TestFlight builds land
# in the same tester group; bumping marketing version is an explicit
# maintainer decision in source, not a side effect of release tagging.
#
# Local development is unaffected: this script never runs locally, and the
# committed project.yml / Configuration.plist values are the defaults a
# contributor sees on a fresh clone.

set -euo pipefail

echo "ci_post_clone: starting…"

# Apple invokes this script with cwd=ci_scripts/. All path-relative work
# (project.yml, Snapper/Config/Configuration.plist, xcodegen output) needs
# repo root, so jump there explicitly. CI_PRIMARY_REPOSITORY_PATH is set
# by Apple to the cloned repo's root.
cd "$CI_PRIMARY_REPOSITORY_PATH"

brew install xcodegen

# --- Required secret env vars must exist ---
: "${SNAPPER_DEVELOPMENT_TEAM:?env var required}"
: "${SNAPPER_BUNDLE_IDENTIFIER:?env var required}"
: "${SNAPPER_BACKEND_URL:?env var required}"

# --- Build number ---
# Apple controls the starting value via App Store Connect -> Xcode Cloud ->
# Settings -> Build Number. Substitute whatever CI_BUILD_NUMBER Apple
# injects; nothing for this script to compute.
sed -i '' "s/CURRENT_PROJECT_VERSION: \"1\"/CURRENT_PROJECT_VERSION: \"$CI_BUILD_NUMBER\"/" project.yml

# MARKETING_VERSION is intentionally NOT patched from CI_TAG. Apple groups
# TestFlight builds per CFBundleShortVersionString, so tagging v0.1.1 ->
# v0.1.2 -> v0.2.0 would create a new tester group on every release and the
# maintainer would have to re-add testers each time. The repository's git
# tags drive the release / CHANGELOG narrative; MARKETING_VERSION stays at
# the value committed in project.yml until the maintainer intentionally
# bumps it (e.g. moving to a new App Store-visible major).

# --- Bundle id ---
# Substitution propagates to both targets (Snapper + SnapperTests) — the test
# target's bundle id becomes ${SNAPPER_BUNDLE_IDENTIFIER}.tests automatically.
sed -i '' "s|PRODUCT_BUNDLE_IDENTIFIER: com\\.example\\.snapper|PRODUCT_BUNDLE_IDENTIFIER: $SNAPPER_BUNDLE_IDENTIFIER|g" project.yml

# --- Signing team ---
# Insert DEVELOPMENT_TEAM at the top-level settings block (after the last
# project-wide setting). All targets inherit it — no duplicate-line risk
# from substituting under target-specific settings.base.
sed -i '' "/^  STRING_CATALOG_GENERATE_SYMBOLS: YES$/a\\
  DEVELOPMENT_TEAM: $SNAPPER_DEVELOPMENT_TEAM
" project.yml

# --- Production backend URL ---
plutil -replace BaseURL -string "$SNAPPER_BACKEND_URL" Snapper/Config/Configuration.plist

# --- Regenerate Xcode project from the patched project.yml ---
xcodegen generate

# Avoid echoing secret-classified inputs (bundle id / team) — they appear
# verbatim in Apple's build logs even though the env vars are flagged Secret.
echo "ci_post_clone: ready — build=$CI_BUILD_NUMBER tag=${CI_TAG:-none}"
