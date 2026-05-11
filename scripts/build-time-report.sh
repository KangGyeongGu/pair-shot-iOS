#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-PairShot/PairShot.xcodeproj}"
SCHEME="${SCHEME:-PairShot}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 15 Pro}"
OUTPUT="${OUTPUT:-/tmp/PairShot-build-time.txt}"

echo "=== Build Time Report ==="
echo "Project: $PROJECT"
echo "Scheme: $SCHEME"
echo "Destination: $DESTINATION"
echo

xcodebuild clean \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    >/dev/null 2>&1 || true

xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    OTHER_SWIFT_FLAGS="\$(inherited) -Xfrontend -debug-time-function-bodies -Xfrontend -debug-time-expression-type-checking" \
    2>&1 | tee "$OUTPUT.raw" | \
    grep -E "^[0-9]+\.[0-9]+ms" | \
    sort -rn | \
    head -20 | \
    tee "$OUTPUT"

echo
echo "=== TOP 20 slowest function bodies (saved to $OUTPUT) ==="
echo "Raw build log: $OUTPUT.raw"
