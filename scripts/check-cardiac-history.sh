#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir=$(mktemp -d /tmp/cumulus-cardiac-checks.XXXXXX)
trap 'rm -rf "$build_dir"' EXIT
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
sed '/^import HealthKit$/d' 'Cumulus Watch App/CardiacHistoryReader.swift' > "$build_dir/CardiacHistoryReader.swift"
xcrun --sdk macosx swiftc -swift-version 6 -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -module-cache-path "$build_dir/modules" \
    "$build_dir/CardiacHistoryReader.swift" \
    Tests/CardiacHistoryChecks.swift -o "$build_dir/checks"
"$build_dir/checks"
