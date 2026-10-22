#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SELECTOR="$ROOT/scripts/select-simulator.sh"
FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT
mkdir -p "$FIXTURE/bin"
export SIMULATOR_TEST_STATE="$FIXTURE/state.json"
export SIMULATOR_TEST_CALLS="$FIXTURE/calls"
export SIMULATOR_TEST_DOWNLOADED="$FIXTURE/downloaded.json"
export PATH="$FIXTURE/bin:$PATH"
unset SIMULATOR SIMULATOR_OS

cat > "$FIXTURE/available.json" <<'JSON'
{
  "runtimes": [
    {"identifier":"com.apple.CoreSimulator.SimRuntime.iOS-26-2","version":"26.2","isAvailable":false},
    {"identifier":"com.apple.CoreSimulator.SimRuntime.iOS-26-1","version":"26.1","isAvailable":true},
    {"identifier":"com.apple.CoreSimulator.SimRuntime.tvOS-27-0","version":"27.0","isAvailable":true},
    {"identifier":"com.apple.CoreSimulator.SimRuntime.iOS-26-6","version":"26.6","isAvailable":true},
    {"identifier":"com.apple.CoreSimulator.SimRuntime.iOS-26-10","version":"26.10","isAvailable":true}
  ],
  "devicetypes": [
    {"identifier":"ipad","name":"iPad Pro","minRuntimeVersionString":"26.0"},
    {"identifier":"future","name":"iPhone Future","minRuntimeVersionString":"27.0"},
    {"identifier":"iphone17","name":"iPhone 17","minRuntimeVersionString":"26.0"},
    {"identifier":"iphone17pro","name":"iPhone 17 Pro","minRuntimeVersionString":"26.0"}
  ],
  "devices": {
    "com.apple.CoreSimulator.SimRuntime.iOS-26-10": [
      {"deviceTypeIdentifier":"iphone17pro","isAvailable":false,"udid":"00000000-0000-0000-0000-000000000000"},
      {"deviceTypeIdentifier":"iphone17pro","isAvailable":true,"udid":"11111111-1111-1111-1111-111111111111"}
    ]
  }
}
JSON
cp "$FIXTURE/available.json" "$SIMULATOR_TEST_DOWNLOADED"

cat > "$FIXTURE/bin/xcrun" <<'SHELL'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$SIMULATOR_TEST_CALLS"
case "$*" in
  'simctl list --json') cat "$SIMULATOR_TEST_STATE" ;;
  'simctl create '*) echo 22222222-2222-2222-2222-222222222222 ;;
  'simctl list runtimes'|'simctl list devices available') echo 'Fixture diagnostics' ;;
  *) exit 19 ;;
esac
SHELL
cat > "$FIXTURE/bin/xcodebuild" <<'SHELL'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$SIMULATOR_TEST_CALLS"
case "$*" in
  '-downloadPlatform iOS'*) cp "$SIMULATOR_TEST_DOWNLOADED" "$SIMULATOR_TEST_STATE" ;;
  '-version') echo 'Fixture Xcode' ;;
  *) exit 20 ;;
esac
SHELL
chmod +x "$FIXTURE/bin/xcrun" "$FIXTURE/bin/xcodebuild"

reset_state() {
  cp "$FIXTURE/available.json" "$SIMULATOR_TEST_STATE"
  : > "$SIMULATOR_TEST_CALLS"
}

expect_destination() {
  local expected=$1
  shift
  local actual
  actual=$(bash "$SELECTOR" "$@" 2> "$FIXTURE/stderr")
  [[ "$actual" == "platform=iOS Simulator,id=$expected" ]] || {
    echo "Unexpected destination: $actual" >&2
    exit 1
  }
}

expect_failure() {
  if bash "$ROOT/scripts/select-simulator.sh" > "$FIXTURE/stdout" 2> "$FIXTURE/stderr"; then
    echo "Expected simulator preparation to fail" >&2
    exit 1
  fi
  [[ ! -s "$FIXTURE/stdout" ]]
  grep -q 'Fixture Xcode' "$FIXTURE/stderr"
  grep -q 'Fixture diagnostics' "$FIXTURE/stderr"
}

assert_no_call() {
  if grep -Fq -- "$1" "$SIMULATOR_TEST_CALLS"; then
    echo "Unexpected simulator command: $1" >&2
    exit 1
  fi
}

expect_device_id() {
  local actual
  actual=$(bash "$ROOT/scripts/simulator-device-id.sh" "$1")
  [[ "$actual" == '11111111-1111-1111-1111-111111111111' ]] || {
    echo "Unexpected simulator UUID: $actual" >&2
    exit 1
  }
}

expect_invalid_destination() {
  if bash "$ROOT/scripts/simulator-device-id.sh" "$1" > "$FIXTURE/stdout" 2> "$FIXTURE/stderr"; then
    echo "Expected showcase destination validation to fail" >&2
    exit 1
  fi
  [[ ! -s "$FIXTURE/stdout" ]]
  grep -q 'requires DESTINATION with an explicit simulator UUID' "$FIXTURE/stderr"
}

reset_state
expect_destination 11111111-1111-1111-1111-111111111111
grep -q 'iOS 26.10' "$FIXTURE/stderr"
assert_no_call 'simctl create'

reset_state
jq '.devices = {}' "$FIXTURE/available.json" > "$SIMULATOR_TEST_STATE"
expect_destination 22222222-2222-2222-2222-222222222222
grep -q 'simctl create Snapper tests iphone17pro com.apple.CoreSimulator.SimRuntime.iOS-26-10' "$SIMULATOR_TEST_CALLS"

reset_state
SIMULATOR_OS=26.6 expect_destination 22222222-2222-2222-2222-222222222222
grep -q 'iOS-26-6' "$SIMULATOR_TEST_CALLS"

reset_state
SIMULATOR='iPhone 17' expect_destination 22222222-2222-2222-2222-222222222222
grep -q 'simctl create Snapper tests iphone17 ' "$SIMULATOR_TEST_CALLS"

reset_state
SIMULATOR='iPhone Missing' expect_failure
grep -q 'No compatible iPhone model iPhone Missing' "$FIXTURE/stderr"

reset_state
SIMULATOR_OS=26.1 expect_failure
grep -q 'No available iOS Simulator runtime 26.1' "$FIXTURE/stderr"
assert_no_call 'downloadPlatform'

reset_state
jq '.runtimes = []' "$FIXTURE/available.json" > "$SIMULATOR_TEST_STATE"
expect_failure
grep -q 'No available iOS Simulator runtime' "$FIXTURE/stderr"

reset_state
jq '.runtimes = []' "$FIXTURE/available.json" > "$SIMULATOR_TEST_STATE"
expect_destination 11111111-1111-1111-1111-111111111111 --install-runtime
grep -q '^-downloadPlatform iOS$' "$SIMULATOR_TEST_CALLS"

reset_state
jq '.runtimes = []' "$FIXTURE/available.json" > "$SIMULATOR_TEST_STATE"
SIMULATOR_OS=26.6 expect_destination 22222222-2222-2222-2222-222222222222 --install-runtime
grep -q '^-downloadPlatform iOS -buildVersion 26.6$' "$SIMULATOR_TEST_CALLS"

reset_state
jq '(.devicetypes[] | select(.identifier == "iphone17pro") | .minRuntimeVersionString) = "26.6.0"' \
  "$FIXTURE/available.json" > "$SIMULATOR_TEST_STATE"
SIMULATOR_OS=26.6 expect_destination 22222222-2222-2222-2222-222222222222
grep -q 'simctl create Snapper tests iphone17pro com.apple.CoreSimulator.SimRuntime.iOS-26-6' "$SIMULATOR_TEST_CALLS"

reset_state
jq '(.runtimes[] | select(.version == "26.6") | .version) = "26.6.0"
  | (.devicetypes[] | select(.identifier == "iphone17pro") | .maxRuntimeVersionString) = "26.6"' \
  "$FIXTURE/available.json" > "$SIMULATOR_TEST_STATE"
SIMULATOR_OS=26.6.0 expect_destination 22222222-2222-2222-2222-222222222222
grep -q 'simctl create Snapper tests iphone17pro com.apple.CoreSimulator.SimRuntime.iOS-26-6' "$SIMULATOR_TEST_CALLS"

reset_state
SIMULATOR_OS=26.6.0 expect_destination 22222222-2222-2222-2222-222222222222
grep -q 'iOS-26-6' "$SIMULATOR_TEST_CALLS"
assert_no_call 'downloadPlatform'

reset_state
mkdir -p "$FIXTURE/project/scripts"
cp "$SELECTOR" "$FIXTURE/project/scripts/select-simulator.sh"
printf 'options:\n  deploymentTarget:\n    iOS: "26.2.0"\n' > "$FIXTURE/project/project.yml"
jq '(.runtimes[] | select(.version == "26.2") | .isAvailable) = true' \
  "$FIXTURE/available.json" > "$SIMULATOR_TEST_STATE"
SELECTOR="$FIXTURE/project/scripts/select-simulator.sh" SIMULATOR_OS=26.2 \
  expect_destination 22222222-2222-2222-2222-222222222222
grep -q 'iOS-26-2' "$SIMULATOR_TEST_CALLS"

printf 'simctl create forbidden fixture\n' > "$SIMULATOR_TEST_CALLS"
if (assert_no_call 'simctl create') 2> "$FIXTURE/stderr"; then
  echo 'The forbidden-command assertion did not stop its process' >&2
  exit 1
fi
grep -q 'Unexpected simulator command' "$FIXTURE/stderr"

expect_device_id 'platform=iOS Simulator,id=11111111-1111-1111-1111-111111111111'
expect_device_id 'platform=iOS Simulator,id=11111111-1111-1111-1111-111111111111,OS=26.6,arch=arm64'
expect_invalid_destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.6'
expect_invalid_destination 'platform=iOS Simulator,id=11111111-1111-1111-1111-111111111111invalid,arch=arm64'

echo 'Simulator selection and destination parsing: 18 regression scenarios passed.'
