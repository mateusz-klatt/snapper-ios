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
#   CI_BUILD_NUMBER  — per-workflow, monotonic from 1 (offset to clear the
#                       last private-monorepo TestFlight build number)
#   CI_TAG           — git tag if the workflow was triggered by a tag push;
#                       used as MARKETING_VERSION (CFBundleShortVersionString)
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
# Keep monotonic across the public-extraction boundary. The private monorepo
# era ended at TestFlight build 9, so offset by 9.
PRIVATE_BUILD_OFFSET=9
NEXT_BUILD=$((CI_BUILD_NUMBER + PRIVATE_BUILD_OFFSET))
sed -i '' "s/CURRENT_PROJECT_VERSION: \"1\"/CURRENT_PROJECT_VERSION: \"$NEXT_BUILD\"/" project.yml

# --- Marketing version from tag (vX.Y.Z → X.Y.Z) ---
if [ -n "${CI_TAG:-}" ]; then
  MV="${CI_TAG#v}"
  sed -i '' "s/MARKETING_VERSION: \"1.0\"/MARKETING_VERSION: \"$MV\"/" project.yml
fi

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

echo "ci_post_clone: ready — bundle=$SNAPPER_BUNDLE_IDENTIFIER team=$SNAPPER_DEVELOPMENT_TEAM build=$NEXT_BUILD ver=${CI_TAG:-source-default}"
