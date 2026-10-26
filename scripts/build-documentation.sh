#!/usr/bin/env bash
#
# Build the DocC catalog for GISToolsCSV and fail on documentation warnings.
#
# Usage: scripts/build-documentation.sh
#
# Requires a Swift toolchain with `docc` and `symbolgraph-extract`.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SWIFT_BIN="$(dirname "$(command -v swift)")"

if command -v docc >/dev/null 2>&1; then
    DOCC="docc"
elif [ -x "$SWIFT_BIN/docc" ]; then
    DOCC="$SWIFT_BIN/docc"
else
    DOCC="$(xcrun --find docc)"
fi

swift build

BIN="$(swift build --show-bin-path)"
TARGET="$(swift -print-target-info \
    | grep -o '"triple"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -n 1 \
    | cut -d'"' -f4)"

SYMBOLS="$ROOT/.build/documentation-symbols"
OUTPUT="$ROOT/.build/documentation"

rm -rf "$SYMBOLS" "$OUTPUT"
mkdir -p "$SYMBOLS"

swift symbolgraph-extract \
    -module-name GISToolsCSV \
    -I "$BIN" \
    -I "$ROOT/.build/checkouts/gis-tools/Sources/GISToolsCZlib" \
    -target "$TARGET" \
    -minimum-access-level public \
    -output-dir "$SYMBOLS"

"$DOCC" convert \
    "$ROOT/Sources/GISToolsCSV/GISToolsCSV.docc" \
    --fallback-display-name GISToolsCSV \
    --fallback-bundle-identifier com.outdooractive.GISToolsCSV \
    --additional-symbol-graph-dir "$SYMBOLS" \
    --output-path "$OUTPUT" \
    --warnings-as-errors

echo "Documentation built at $OUTPUT"
