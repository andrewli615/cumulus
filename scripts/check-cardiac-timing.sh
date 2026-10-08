#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir=$(mktemp -d /tmp/cumulus-cardiac-timing-checks.XXXXXX)
trap 'rm -rf "$build_dir"' EXIT
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun --sdk macosx swiftc -swift-version 6 -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -module-cache-path "$build_dir/modules" \
    'Cumulus Watch App/TestReport.swift' 'Cumulus Watch App/TestArchiveStore.swift' \
    'Cumulus Watch App/CardiacTiming.swift' Tests/CardiacTimingChecks.swift -o "$build_dir/checks"
"$build_dir/checks"
sed '/^import HealthKit$/d' 'Cumulus Watch App/HealthKitCardiacTimingQuery.swift' > "$build_dir/HealthKitCardiacTimingQuery.swift"
xcrun --sdk macosx swiftc -swift-version 6 -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -module-cache-path "$build_dir/modules" \
    'Cumulus Watch App/TestReport.swift' 'Cumulus Watch App/TestArchiveStore.swift' \
    'Cumulus Watch App/CardiacTiming.swift' "$build_dir/HealthKitCardiacTimingQuery.swift" \
    Tests/CardiacTimingPlatformDoubles.swift Tests/CardiacTimingProviderChecks.swift -o "$build_dir/provider-checks"
"$build_dir/provider-checks"
