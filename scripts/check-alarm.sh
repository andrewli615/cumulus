#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir=$(mktemp -d /tmp/cumulus-alarm-checks.XXXXXX)
trap 'rm -rf "$build_dir"' EXIT
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
sed '/^import WatchKit$/d' 'Cumulus Watch App/AlarmCoordinator.swift' > "$build_dir/AlarmCoordinator.swift"
xcrun --sdk macosx swiftc -swift-version 6 -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -module-cache-path "$build_dir/modules" \
    'Cumulus Watch App/AlarmRecord.swift' 'Cumulus Watch App/ExperimentSessionOwner.swift' \
    "$build_dir/AlarmCoordinator.swift" Tests/AlarmPlatformDoubles.swift Tests/AlarmChecks.swift \
    -o "$build_dir/checks"
"$build_dir/checks"
