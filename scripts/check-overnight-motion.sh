#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir=$(mktemp -d /tmp/cumulus-overnight-checks.XXXXXX)
trap 'rm -rf "$build_dir"' EXIT
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
for source in OvernightMotionRecorder OvernightMotionCoordinator; do
    sed '/^import WatchKit$/d; /^import CoreMotion$/d' "Cumulus Watch App/$source.swift" > "$build_dir/$source.swift"
done
xcrun --sdk macosx swiftc -swift-version 6 -D OVERNIGHT_CHECKS -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -module-cache-path "$build_dir/modules" \
    'Cumulus Watch App/TestReport.swift' \
    'Cumulus Watch App/TestArchiveStore.swift' \
    'Cumulus Watch App/OvernightMotionTrial.swift' \
    'Cumulus Watch App/PilotGuide.swift' \
    'Cumulus Watch App/ExperimentSessionOwner.swift' \
    "$build_dir/OvernightMotionRecorder.swift" \
    "$build_dir/OvernightMotionCoordinator.swift" \
    Tests/OvernightPlatformDoubles.swift Tests/OvernightMotionChecks.swift -o "$build_dir/checks"
"$build_dir/checks"
