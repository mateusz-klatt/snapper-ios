#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MINIMUM_OS=$(sed -nE 's/^[[:space:]]+iOS: "([0-9.]+)"$/\1/p' "$ROOT/project.yml" | head -1)
INSTALL_RUNTIME=false
if [[ "${1:-}" == "--install-runtime" ]]; then
  INSTALL_RUNTIME=true
elif [[ $# -ne 0 ]]; then
  echo "Usage: $0 [--install-runtime]" >&2
  exit 1
fi

diagnostics() {
  local status=$?
  if [[ $status -ne 0 ]]; then
    echo "iOS Simulator preparation failed; selected Xcode and available simulators:" >&2
    xcodebuild -version >&2 || true
    xcrun simctl list runtimes >&2 || true
    xcrun simctl list devices available >&2 || true
  fi
}
trap diagnostics EXIT

command -v jq >/dev/null || { echo "Install jq: brew install jq" >&2; exit 1; }
[[ -n "$MINIMUM_OS" ]] || { echo "Missing iOS deployment target in project.yml" >&2; exit 1; }
STATE=$(xcrun simctl list --json)
COMPATIBILITY_FILTER='
  def version: split(".") | map(tonumber) | . + [range(length; 3) | 0];
  def compatible_model($name; $runtime):
    (.name | startswith("iPhone "))
    and ($name == "" or .name == $name)
    and (((.minRuntimeVersionString // "0") | version) <= ($runtime | version))
    and (((.maxRuntimeVersionString // "65535") | version) >= ($runtime | version));
'
if [[ -n "${SIMULATOR:-}" ]]; then
  if ! jq -e --arg name "$SIMULATOR" '
    any(.devicetypes[]; .name == $name and (.name | startswith("iPhone ")))
  ' <<< "$STATE" >/dev/null; then
    echo "No compatible iPhone model $SIMULATOR in the selected Xcode installation" >&2
    exit 1
  fi
fi

select_runtime() {
  jq -r --arg minimum "$MINIMUM_OS" --arg requested "${SIMULATOR_OS:-}" \
    --arg model "${SIMULATOR:-}" "$COMPATIBILITY_FILTER"'
    .devicetypes as $models
    | [.runtimes[]
      | select(.identifier | startswith("com.apple.CoreSimulator.SimRuntime.iOS-"))
      | select(.isAvailable == true)
      | select((.version | version) >= ($minimum | version))
      | select($requested == "" or (.version | version) == ($requested | version))]
    | sort_by(.version | version) | reverse
    | . as $eligible
    | ([.[] | . as $runtime
        | select(any($models[]; compatible_model($model; $runtime.version)))]
        + $eligible)
    | first
    | if . == null then empty else [.identifier, .version] | @tsv end
  ' <<< "$STATE"
}

RUNTIME=$(select_runtime)
if [[ -z "$RUNTIME" && "$INSTALL_RUNTIME" == true ]]; then
  DOWNLOAD_ARGS=(-downloadPlatform iOS)
  if [[ -n "${SIMULATOR_OS:-}" ]]; then
    DOWNLOAD_ARGS+=(-buildVersion "$SIMULATOR_OS")
  fi
  xcodebuild "${DOWNLOAD_ARGS[@]}" >&2
  STATE=$(xcrun simctl list --json)
  RUNTIME=$(select_runtime)
fi
if [[ -z "$RUNTIME" ]]; then
  echo "No available iOS Simulator runtime ${SIMULATOR_OS:->= $MINIMUM_OS}. Install it in Xcode Settings > Components, or pass --install-runtime." >&2
  exit 1
fi
IFS=$'\t' read -r RUNTIME_ID RUNTIME_VERSION <<< "$RUNTIME"

MODEL=$(jq -r --arg runtime "$RUNTIME_VERSION" --arg requested "${SIMULATOR:-}" "$COMPATIBILITY_FILTER"'
  [.devicetypes[]
    | select(compatible_model($requested; $runtime))]
  | sort_by(.name != "iPhone 17 Pro") | first
  | if . == null then empty else [.identifier, .name] | @tsv end
' <<< "$STATE")
if [[ -z "$MODEL" ]]; then
  echo "No compatible iPhone model ${SIMULATOR:-available} for iOS $RUNTIME_VERSION" >&2
  exit 1
fi
IFS=$'\t' read -r MODEL_ID MODEL_NAME <<< "$MODEL"
DEVICE_ID=$(jq -r --arg runtime "$RUNTIME_ID" --arg model "$MODEL_ID" '
  [.devices[$runtime][]? | select(.isAvailable == true and .deviceTypeIdentifier == $model)]
  | first | .udid // empty
' <<< "$STATE")
if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID=$(xcrun simctl create "Snapper tests" "$MODEL_ID" "$RUNTIME_ID")
fi
if [[ ! "$DEVICE_ID" =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]]; then
  echo "simctl did not return a valid simulator UUID: $DEVICE_ID" >&2
  exit 1
fi
echo "Using $MODEL_NAME / iOS $RUNTIME_VERSION ($DEVICE_ID)" >&2
printf 'platform=iOS Simulator,id=%s\n' "$DEVICE_ID"
