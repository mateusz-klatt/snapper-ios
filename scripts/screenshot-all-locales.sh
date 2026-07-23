#!/usr/bin/env bash
# Run the XCUITest i18n screenshot harness against a live backend tunnel
# and dump per-country PNGs into the proprietary/screenshots/ios/ tree.
#
# Usage:
#   ios/scripts/screenshot-all-locales.sh [smoke|all|retry|showcase|chart-verify|viewer-uat]
#
# Backend URL discovery (in order):
#   1. SNAPPER_UITEST_BACKEND_URL env var
#   2. ios/.local-backend-url file (git-ignored)
#
# viewer-uat also requires a fresh development fixture with seeded admin and
# viewer accounts, a paper wallet, static instruments, and a scope grant.
#
# Output: <repo-root>/proprietary/screenshots/ios/<country>/<screen>.png

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT/.." && pwd)"
SCREENSHOTS_OUT="$REPO_ROOT/proprietary/screenshots/ios"
XCRESULT="$ROOT/build/screenshots.xcresult"

MODE="${1:-all}"
case "$MODE" in
  smoke)        METHOD="testCaptureSmoke" ;;
  retry)        METHOD="testCaptureRetryFailures" ;;
  all)          METHOD="testCaptureAllLocales" ;;
  showcase)     METHOD="testCaptureMarketingShowcase" ;;
  chart-verify) METHOD="testCaptureChartColorVerification" ;;
  viewer-uat)   METHOD="testCaptureViewerPermissionsUAT" ;;
  *) echo "usage: $0 [smoke|all|retry|showcase|chart-verify|viewer-uat]" >&2 ; exit 2 ;;
esac

URL="${SNAPPER_UITEST_BACKEND_URL:-}"
if [ -z "$URL" ] && [ -r "$ROOT/.local-backend-url" ]; then
  URL="$(tr -d '[:space:]' < "$ROOT/.local-backend-url")"
fi
if [ -z "$URL" ]; then
  cat >&2 <<EOF
error: no backend URL configured.
  Set SNAPPER_UITEST_BACKEND_URL, e.g.
    export SNAPPER_UITEST_BACKEND_URL=https://your-tunnel.trycloudflare.com
  or write the URL to ios/.local-backend-url (git-ignored).
EOF
  exit 1
fi

echo "==> Mode:    $MODE ($METHOD)"
echo "==> Backend: $URL"
echo "==> Output:  $SCREENSHOTS_OUT"
echo

cd "$ROOT"

# Regenerate Xcode project so the SnapperUITests target is wired.
if ! [ -d "Snapper.xcodeproj" ]; then
  command -v xcodegen >/dev/null 2>&1 || { echo "xcodegen not installed; run: brew install xcodegen" >&2; exit 1; }
  xcodegen generate
fi

rm -rf "$XCRESULT"
mkdir -p "$(dirname "$XCRESULT")"

# The simulator strips host env vars from the XCUITest runner process, so
# we patch the sentinel URL directly into the test source and restore it
# on exit. This is the most reliable way to thread a live backend URL
# through xcodebuild test in macOS 13+.
TEST_FILE="SnapperUITests/I18nScreenshotUITests.swift"
SENTINEL="https://snapper-uitest-no-backend.invalid"

if ! grep -q "$SENTINEL" "$TEST_FILE"; then
  echo "error: sentinel \"$SENTINEL\" not found in $TEST_FILE — has the harness moved?" >&2
  exit 1
fi

restore_test_file() {
  # Use Python for a single literal string replacement: avoids sed escape
  # quirks with URL characters (slashes, dots, hyphens) across BSD/GNU sed.
  python3 - "$TEST_FILE" "$URL" "$SENTINEL" <<'PY'
import sys
path, current, sentinel = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
open(path, 'w').write(text.replace(current, sentinel))
PY
}
trap restore_test_file EXIT

python3 - "$TEST_FILE" "$SENTINEL" "$URL" <<'PY'
import sys
path, sentinel, url = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
if sentinel not in text:
    raise SystemExit(f"sentinel not found in {path}")
open(path, 'w').write(text.replace(sentinel, url))
PY

if [ "$MODE" = "showcase" ]; then
  echo "==> Uninstalling Snapper from booted simulator (showcase needs clean state)"
  DEVICE_UDID=$(xcrun simctl list devices "iPhone 17 Pro" | grep -E "iOS 26.2|(26.2)" -A1 | grep "iPhone 17 Pro (" | grep -v Max | grep -oE "[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}" | head -1)
  if [ -n "$DEVICE_UDID" ]; then
    xcrun simctl boot "$DEVICE_UDID" 2>/dev/null || true
    xcrun simctl uninstall "$DEVICE_UDID" com.example.snapper 2>/dev/null || true
  fi
fi

XCODEBUILD_ARGS=(
  test
  -scheme Snapper
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2'
  -only-testing:"SnapperUITests/I18nScreenshotUITests/$METHOD"
  -resultBundlePath "$XCRESULT"
)

if command -v xcbeautify >/dev/null 2>&1; then
  xcodebuild "${XCODEBUILD_ARGS[@]}" | xcbeautify
else
  xcodebuild "${XCODEBUILD_ARGS[@]}"
fi

if [ ! -d "$XCRESULT/Data" ]; then
  echo "error: xcresult not produced at $XCRESULT" >&2
  exit 1
fi

echo
echo "==> Extracting attachments + renaming"
python3 "$ROOT/scripts/rename-screenshots.py" "$XCRESULT" "$SCREENSHOTS_OUT"

echo
echo "==> Building INDEX.md"
python3 "$ROOT/scripts/build-screenshot-index.py" "$SCREENSHOTS_OUT"

echo
echo "==> Done. Screenshots in: $SCREENSHOTS_OUT"
