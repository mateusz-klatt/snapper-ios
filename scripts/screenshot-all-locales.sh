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
# viewer-uat also requires a fresh development fixture with seeded admin,
# operator, and viewer accounts, a paper wallet, static instruments, a scope
# grant, one additional unscoped desk labelled ios-uat-secondary for the
# admin-vs-operator filter proof,
# and an active VIEWER named deskviewer with no initial desk membership.
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

DEFAULT_DESK_SENTINEL="snapper-uitest-no-default-desk.invalid"
SECONDARY_DESK_SENTINEL="snapper-uitest-no-secondary-desk.invalid"
FIXTURE_MARKER_SENTINEL="snapper-uitest-no-fixture-marker.invalid"
DEFAULT_DESK_PUBLIC_ID="$DEFAULT_DESK_SENTINEL"
SECONDARY_DESK_PUBLIC_ID="$SECONDARY_DESK_SENTINEL"
FIXTURE_MARKER="$FIXTURE_MARKER_SENTINEL"

if [ "$MODE" = "viewer-uat" ]; then
  if [ "${SNAPPER_UITEST_ALLOW_FIXTURE_WRITES:-}" != "1" ]; then
    echo "error: viewer-uat mutates its disposable fixture; set SNAPPER_UITEST_ALLOW_FIXTURE_WRITES=1 explicitly" >&2
    exit 1
  fi
  FIXTURE_URL="${SNAPPER_UITEST_FIXTURE_URL:-}"
  FIXTURE_RECORD="$ROOT/.desk-uat-fixture.json"
  if [ -z "$FIXTURE_URL" ] || [ ! -r "$FIXTURE_RECORD" ]; then
    echo "error: viewer-uat requires SNAPPER_UITEST_FIXTURE_URL and $FIXTURE_RECORD" >&2
    exit 1
  fi
  IFS=$'\t' read -r DEFAULT_DESK_PUBLIC_ID SECONDARY_DESK_PUBLIC_ID FIXTURE_MARKER < <(
    python3 - "$FIXTURE_RECORD" "$URL" "$FIXTURE_URL" <<'PY'
import ipaddress
import hashlib
import json
import os
import re
import sys
import uuid
from urllib.parse import urlsplit

record_path, backend_url, fixture_url = sys.argv[1:]

def normalized_origin(raw):
    parsed = urlsplit(raw)
    if parsed.scheme != "http" or parsed.username or parsed.password:
        raise SystemExit("viewer-uat fixture URL must be an unauthenticated http loopback origin")
    if parsed.query or parsed.fragment or parsed.path not in ("", "/"):
        raise SystemExit("viewer-uat fixture URL must not contain a path, query, or fragment")
    try:
        address = ipaddress.ip_address(parsed.hostname or "")
    except ValueError:
        if parsed.hostname != "localhost":
            raise SystemExit("viewer-uat fixture URL must resolve explicitly to loopback")
    else:
        if not address.is_loopback:
            raise SystemExit("viewer-uat fixture URL must resolve explicitly to loopback")
    return raw.rstrip("/")

backend_origin = normalized_origin(backend_url)
fixture_origin = normalized_origin(fixture_url)
if backend_origin != fixture_origin:
    raise SystemExit("SNAPPER_UITEST_BACKEND_URL and SNAPPER_UITEST_FIXTURE_URL must match")

with open(record_path, encoding="utf-8") as handle:
    record = json.load(handle)
if normalized_origin(record.get("backend_url", "")) != fixture_origin:
    raise SystemExit("fixture record backend_url does not match the selected loopback backend")
expected_database_sha256 = record.get("database_sha256", "")
if not re.fullmatch(r"[0-9a-f]{64}", expected_database_sha256):
    raise SystemExit("fixture record requires a lowercase SHA-256 database fingerprint")
database_path = record.get("database_path", "")
if not isinstance(database_path, str) or not os.path.isabs(database_path):
    raise SystemExit("fixture record requires an absolute database_path")
if not os.path.isfile(database_path):
    raise SystemExit("fixture record database_path is not a regular file")
digest = hashlib.sha256()
with open(database_path, "rb") as database:
    for chunk in iter(lambda: database.read(1024 * 1024), b""):
        digest.update(chunk)
if digest.hexdigest() != expected_database_sha256:
    raise SystemExit("fixture database fingerprint changed; rebuild a fresh disposable fixture")
if not re.fullmatch(r"[A-Za-z0-9._:-]{8,128}", record.get("fixture_marker", "")):
    raise SystemExit("fixture record marker is missing or unsafe")
for key in ("default_desk_public_id", "secondary_desk_public_id", "deskviewer_public_id"):
    try:
        parsed_id = uuid.UUID(record.get(key, ""))
    except (AttributeError, ValueError):
        raise SystemExit(f"fixture record has invalid {key}") from None
    if parsed_id.version != 7:
        raise SystemExit(f"fixture record {key} must be UUID7")

print("\t".join([
    record["default_desk_public_id"],
    record["secondary_desk_public_id"],
    record["fixture_marker"],
]))
PY
  )
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

for sentinel in "$SENTINEL" "$DEFAULT_DESK_SENTINEL" "$SECONDARY_DESK_SENTINEL" "$FIXTURE_MARKER_SENTINEL"; do
  if ! grep -q "$sentinel" "$TEST_FILE"; then
    echo "error: sentinel \"$sentinel\" not found in $TEST_FILE — has the harness moved?" >&2
    exit 1
  fi
done

restore_test_file() {
  python3 - "$TEST_FILE" \
    "$URL" "$SENTINEL" \
    "$DEFAULT_DESK_PUBLIC_ID" "$DEFAULT_DESK_SENTINEL" \
    "$SECONDARY_DESK_PUBLIC_ID" "$SECONDARY_DESK_SENTINEL" \
    "$FIXTURE_MARKER" "$FIXTURE_MARKER_SENTINEL" <<'PY'
import sys
path, *values = sys.argv[1:]
text = open(path).read()
for current, sentinel in zip(values[0::2], values[1::2]):
    text = text.replace(current, sentinel)
open(path, 'w').write(text)
PY
}
trap restore_test_file EXIT

python3 - "$TEST_FILE" \
  "$SENTINEL" "$URL" \
  "$DEFAULT_DESK_SENTINEL" "$DEFAULT_DESK_PUBLIC_ID" \
  "$SECONDARY_DESK_SENTINEL" "$SECONDARY_DESK_PUBLIC_ID" \
  "$FIXTURE_MARKER_SENTINEL" "$FIXTURE_MARKER" <<'PY'
import sys
path, *values = sys.argv[1:]
text = open(path).read()
for sentinel, current in zip(values[0::2], values[1::2]):
    if sentinel not in text:
        raise SystemExit(f"sentinel {sentinel!r} not found in {path}")
    text = text.replace(sentinel, current)
open(path, 'w').write(text)
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
