#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ALLOWLIST="$ROOT/scripts/check_i18n_allowlist.txt"

PATTERN='String\(\s*localized:\s*"[^"]+"'

HITS=()
while IFS= read -r line; do
  HITS+=("$line")
done < <(rg --no-heading --line-number -U --multiline-dotall -P "$PATTERN" "$ROOT/Snapper" || true)

if [ "${#HITS[@]}" -eq 0 ]; then
  exit 0
fi

ALLOWED_PATHS=()
if [ -f "$ALLOWLIST" ]; then
  while IFS= read -r prefix; do
    case "$prefix" in
      ""|\#*) continue ;;
    esac
    ALLOWED_PATHS+=("$prefix")
  done < "$ALLOWLIST"
fi

failed=0
for hit in "${HITS[@]}"; do
  file="${hit%%:*}"
  allowed=0
  for prefix in "${ALLOWED_PATHS[@]:-}"; do
    [ -z "$prefix" ] && continue
    case "$file" in
      *"$prefix"*) allowed=1; break ;;
    esac
  done
  if [ "$allowed" -eq 0 ]; then
    echo "i18n-check: forbidden String(localized:) usage (use LocaleStrings.localized instead): $hit"
    failed=1
  fi
done

exit "$failed"
