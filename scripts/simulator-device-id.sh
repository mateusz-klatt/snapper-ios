#!/usr/bin/env bash
set -euo pipefail

DESTINATION=${1:-}
UUID='[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}'
if [[ "$DESTINATION" =~ (^|,)id=($UUID)(,|$) ]]; then
  printf '%s\n' "${BASH_REMATCH[2]}"
else
  echo 'Showcase capture requires DESTINATION with an explicit simulator UUID: platform=iOS Simulator,id=UUID' >&2
  exit 1
fi
