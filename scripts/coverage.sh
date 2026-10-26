#!/usr/bin/env bash
#
# Report code coverage for the test run and optionally enforce a minimum.
#
# Run `swift test --enable-code-coverage` first, then:
#
#   scripts/coverage.sh [minimum-line-percentage]
#
# The default minimum is 0 (report only). Tests are excluded from the report.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MINIMUM="${1:-0}"

SWIFT_BIN="$(dirname "$(command -v swift)")"

if command -v llvm-profdata >/dev/null 2>&1 && command -v llvm-cov >/dev/null 2>&1; then
    LLVM_PROFDATA="llvm-profdata"
    LLVM_COV="llvm-cov"
elif [ -x "$SWIFT_BIN/llvm-profdata" ] && [ -x "$SWIFT_BIN/llvm-cov" ]; then
    LLVM_PROFDATA="$SWIFT_BIN/llvm-profdata"
    LLVM_COV="$SWIFT_BIN/llvm-cov"
else
    LLVM_PROFDATA="$(xcrun --find llvm-profdata)"
    LLVM_COV="$(xcrun --find llvm-cov)"
fi

BIN="$(swift build --show-bin-path)"

TEMP_PROFDATA="$(mktemp)"
REPORT="$(mktemp)"
trap 'rm -f "$TEMP_PROFDATA" "$REPORT"' EXIT

if [ -f "$BIN/codecov/default.profdata" ]; then
    PROFDATA="$BIN/codecov/default.profdata"
elif [ -d "$BIN/codecov" ] && compgen -G "$BIN/codecov/*.profraw" >/dev/null; then
    "$LLVM_PROFDATA" merge -sparse "$BIN"/codecov/*.profraw -o "$TEMP_PROFDATA"
    PROFDATA="$TEMP_PROFDATA"
else
    EXISTING_PROFDATA="$(find .build -name '*.profdata' -type f | head -n 1)"
    if [ -n "$EXISTING_PROFDATA" ]; then
        PROFDATA="$EXISTING_PROFDATA"
    else
        PROFRAW="$(find .build -name '*.profraw' -type f | tr '\n' ' ')"
        if [ -z "$PROFRAW" ]; then
            echo "No coverage data found. Run 'swift test --enable-code-coverage' first." >&2
            exit 1
        fi
        # shellcheck disable=SC2086
        "$LLVM_PROFDATA" merge -sparse $PROFRAW -o "$TEMP_PROFDATA"
        PROFDATA="$TEMP_PROFDATA"
    fi
fi

BINARY=""
for candidate in \
    "$BIN/GISToolsCSVTests.so" \
    "$BIN/GISToolsCSVTests.xctest" \
    "$BIN/GISToolsCSVPackageTests.xctest" \
    "$BIN/GISToolsCSVTests"
do
    if [ -f "$candidate" ]; then
        BINARY="$candidate"
        break
    fi
done

if [ -z "$BINARY" ]; then
    BINARY="$(find "$BIN" -maxdepth 4 -type f \
        \( -name 'GISToolsCSVTests' -o -name 'GISToolsCSVTests.so' -o -name 'GISToolsCSVPackageTests.xctest' \) \
        | head -n 1)"
fi

if [ -z "$BINARY" ]; then
    echo "Could not find the GISToolsCSV test binary in $BIN." >&2
    exit 1
fi

"$LLVM_COV" report "$BINARY" \
    -instr-profile="$PROFDATA" \
    -ignore-filename-regex='(/Tests/|\.build/)' \
    | tee "$REPORT"

if [ "$MINIMUM" != "0" ]; then
    COVERAGE="$(awk '/^TOTAL/ { gsub(/%/, "", $10); print $10 }' "$REPORT")"
    if [ -z "$COVERAGE" ]; then
        echo "Could not parse line coverage from the report." >&2
        exit 1
    fi
    if ! awk -v coverage="$COVERAGE" -v minimum="$MINIMUM" 'BEGIN { exit !(coverage + 0 >= minimum + 0) }'; then
        echo "Line coverage ${COVERAGE}% is below the required ${MINIMUM}%." >&2
        exit 1
    fi
    echo "Line coverage ${COVERAGE}% meets the required ${MINIMUM}%."
fi
