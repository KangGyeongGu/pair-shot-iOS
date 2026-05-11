#!/usr/bin/env bash
set -euo pipefail

ARCHIVE_PATH="${1:-/tmp/PairShot.xcarchive}"
APP_PATH="$ARCHIVE_PATH/Products/Applications/PairShot.app"
BINARY_PATH="$APP_PATH/PairShot"

if [[ ! -d "$APP_PATH" ]]; then
    echo "FAIL: app bundle not found at $APP_PATH" >&2
    echo "Hint: run xcodebuild archive first (-archivePath $ARCHIVE_PATH)" >&2
    exit 1
fi

echo "=== Binary Size Report ==="
echo "Archive: $ARCHIVE_PATH"
echo

echo "--- App bundle size ---"
du -sh "$APP_PATH"

echo
echo "--- Top 10 frameworks ---"
if [[ -d "$APP_PATH/Frameworks" ]]; then
    du -sh "$APP_PATH/Frameworks/"* 2>/dev/null | sort -rh | head -10
else
    echo "(no Frameworks directory)"
fi

echo
echo "--- Binary section sizes ---"
if [[ -f "$BINARY_PATH" ]]; then
    xcrun size -m "$BINARY_PATH"
else
    echo "FAIL: binary not found at $BINARY_PATH" >&2
    exit 1
fi

echo
echo "--- Resource bundle top entries ---"
du -sh "$APP_PATH"/* 2>/dev/null | sort -rh | head -10

echo
echo "=== Binary Size Report: DONE ==="
