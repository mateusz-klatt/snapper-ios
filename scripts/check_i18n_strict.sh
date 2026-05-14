#!/usr/bin/env bash
# Lint user-visible string literals in iOS view layers (v2 — Phase H).
#
# Scans ios/Snapper/Views/, ios/Snapper/Views/Components/, and
# ios/Snapper/ViewModels/ for bare string literals passed to SwiftUI
# string-taking APIs. Every hit must either be routed through the
# catalog (Text(LocalizedStringKey(...))/LocaleStrings.localized/
# LocaleStrings.localizedPlural) or explicitly allowlisted in
# check_i18n_allowlist.txt with the exact <path>:<line>:<reason> form.
#
# Patterns are loaded from check_i18n_patterns.txt. `rg -U` enables
# multi-line matching so SwiftUI initializers like
# `DatePicker(\n    "Start", ...)` are caught.
#
# Bash 3.2-safe: no mapfile, no readarray, no <<< on shell-special
# input.

set -e
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PATTERNS="$ROOT/scripts/check_i18n_patterns.txt"
ALLOWLIST="$ROOT/scripts/check_i18n_allowlist.txt"

if [ ! -f "$PATTERNS" ]; then
    echo "i18n-check: patterns file missing: $PATTERNS" >&2
    exit 2
fi

SCAN_DIRS=(
    "$ROOT/Snapper/Views"
    "$ROOT/Snapper/Views/Components"
    "$ROOT/Snapper/ViewModels"
)

EXISTING_DIRS=""
for DIR in "${SCAN_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
        EXISTING_DIRS="$EXISTING_DIRS $DIR"
    fi
done

if [ -z "$EXISTING_DIRS" ]; then
    echo "i18n-check: no scan directories exist under $ROOT/Snapper/" >&2
    exit 2
fi

ALLOWED=""
if [ -f "$ALLOWLIST" ]; then
    while IFS= read -r ENTRY; do
        case "$ENTRY" in
            ""|\#*) continue ;;
        esac
        PREFIX_PATH=$(echo "$ENTRY" | sed -nE 's/^([^:]+):([0-9]+):.+$/\1:\2/p')
        if [ -n "$PREFIX_PATH" ]; then
            ALLOWED="$ALLOWED
$PREFIX_PATH"
        fi
    done < "$ALLOWLIST"
fi

FAILED=0
HIT_COUNT=0

while IFS= read -r PATTERN; do
    case "$PATTERN" in
        ""|\#*) continue ;;
    esac

    while IFS= read -r HIT; do
        if [ -z "$HIT" ]; then continue; fi
        FILE_PATH=$(echo "$HIT" | sed -nE 's|^([^:]+):([0-9]+):.*$|\1|p')
        LINE_NUM=$(echo "$HIT" | sed -nE 's|^([^:]+):([0-9]+):.*$|\2|p')
        if [ -z "$FILE_PATH" ] || [ -z "$LINE_NUM" ]; then continue; fi
        REL_PATH=$(echo "$FILE_PATH" | sed -E "s|^$ROOT/||")

        IS_ALLOWED=0
        if [ -n "$ALLOWED" ]; then
            case "$ALLOWED" in
                *"$REL_PATH:$LINE_NUM"*) IS_ALLOWED=1 ;;
            esac
        fi

        if [ "$IS_ALLOWED" -eq 0 ]; then
            HIT_COUNT=$((HIT_COUNT + 1))
            echo "i18n-check: $REL_PATH:$LINE_NUM matches pattern $PATTERN"
            FAILED=1
        fi
    done < <(rg --no-heading --line-number -U --multiline-dotall -P "$PATTERN" $EXISTING_DIRS 2>/dev/null || true)

done < "$PATTERNS"

if [ "$FAILED" -ne 0 ]; then
    echo ""
    echo "i18n-check: $HIT_COUNT unallowlisted hit(s) found."
    echo "Route the string through the catalog (Text(LocalizedStringKey(...)) /"
    echo "LocaleStrings.localized / LocaleStrings.localizedPlural) or add an"
    echo "exact <path>:<line>:<reason> entry to $ALLOWLIST."
    exit 1
fi

echo "i18n-check: clean."
exit 0
