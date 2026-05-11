#!/usr/bin/env bash
set -euo pipefail

MANIFEST="${1:-PairShot/PairShot/PrivacyInfo.xcprivacy}"

if [[ ! -f "$MANIFEST" ]]; then
    echo "FAIL: PrivacyInfo.xcprivacy not found at $MANIFEST" >&2
    exit 1
fi

echo "=== Privacy Manifest Verification ==="
echo "File: $MANIFEST"
echo

EXIT=0

check_key() {
    local key="$1"
    local expected_kind="${2:-}"

    if plutil -extract "$key" xml1 -o - "$MANIFEST" >/dev/null 2>&1; then
        echo "OK   $key"
    else
        echo "FAIL missing key: $key" >&2
        EXIT=1
        return
    fi

    if [[ -n "$expected_kind" ]]; then
        local raw
        raw="$(plutil -extract "$key" raw -o - "$MANIFEST" 2>/dev/null || true)"
        case "$expected_kind" in
            bool)
                if [[ "$raw" != "true" && "$raw" != "false" ]]; then
                    echo "FAIL $key expected Bool, got: $raw" >&2
                    EXIT=1
                fi
                ;;
            array)
                if ! plutil -extract "$key" xml1 -o - "$MANIFEST" 2>/dev/null | grep -q "<array>"; then
                    echo "FAIL $key expected Array" >&2
                    EXIT=1
                fi
                ;;
        esac
    fi
}

check_top_keys() {
    check_key "NSPrivacyTracking" bool
    check_key "NSPrivacyTrackingDomains" array
    check_key "NSPrivacyAccessedAPITypes" array
    check_key "NSPrivacyCollectedDataTypes" array
}

check_api_category() {
    local category="$1"
    local reason="$2"

    local count
    count="$(plutil -extract NSPrivacyAccessedAPITypes raw -o - "$MANIFEST" 2>/dev/null || echo 0)"

    local found=0
    local idx=0
    while (( idx < count )); do
        local api_type
        api_type="$(plutil -extract "NSPrivacyAccessedAPITypes.$idx.NSPrivacyAccessedAPIType" raw -o - "$MANIFEST" 2>/dev/null || true)"
        if [[ "$api_type" == "$category" ]]; then
            local reason_count
            reason_count="$(plutil -extract "NSPrivacyAccessedAPITypes.$idx.NSPrivacyAccessedAPITypeReasons" raw -o - "$MANIFEST" 2>/dev/null || echo 0)"
            local r_idx=0
            while (( r_idx < reason_count )); do
                local actual_reason
                actual_reason="$(plutil -extract "NSPrivacyAccessedAPITypes.$idx.NSPrivacyAccessedAPITypeReasons.$r_idx" raw -o - "$MANIFEST" 2>/dev/null || true)"
                if [[ "$actual_reason" == "$reason" ]]; then
                    found=1
                    break 2
                fi
                r_idx=$((r_idx + 1))
            done
        fi
        idx=$((idx + 1))
    done

    if (( found == 1 )); then
        echo "OK   API category: $category ($reason)"
    else
        echo "FAIL API category missing: $category ($reason)" >&2
        EXIT=1
    fi
}

check_top_keys

echo
echo "=== Required Reason API categories ==="
check_api_category "NSPrivacyAccessedAPICategoryUserDefaults" "CA92.1"
check_api_category "NSPrivacyAccessedAPICategoryFileTimestamp" "C617.1"
check_api_category "NSPrivacyAccessedAPICategoryDiskSpace" "E174.1"

echo
if (( EXIT == 0 )); then
    echo "=== Privacy Manifest: PASS ==="
else
    echo "=== Privacy Manifest: FAIL ===" >&2
fi

exit "$EXIT"
