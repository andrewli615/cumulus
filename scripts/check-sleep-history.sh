#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir=$(mktemp -d /tmp/cumulus-sleep-checks.XXXXXX)
trap 'rm -rf "$build_dir"' EXIT
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
# Compile the actual reader against synthetic HealthKit doubles on macOS.
sed '/^import HealthKit$/d' 'Cumulus Watch App/SleepStageReader.swift' > "$build_dir/SleepStageReader.swift"
xcrun --sdk macosx swiftc -swift-version 6 -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -module-cache-path "$build_dir/modules" \
    'Cumulus Watch App/TestReport.swift' \
    'Cumulus Watch App/TestArchiveStore.swift' \
    "$build_dir/SleepStageReader.swift" \
    Tests/SleepHistoryChecks.swift -o "$build_dir/checks"
"$build_dir/checks"
