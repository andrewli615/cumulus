#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir=$(mktemp -d /tmp/cumulus-motion-checks.XXXXXX)
trap 'rm -rf "$build_dir"' EXIT
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
# Compile the actual coordinators against deterministic platform doubles on macOS.
for source in AlarmCoordinator BackgroundMotionCoordinator ScheduledAlertCoordinator WatchAppDelegate OvernightMotionRecorder OvernightMotionCoordinator; do
    sed '/^import WatchKit$/d; /^import CoreMotion$/d' "Cumulus Watch App/$source.swift" > "$build_dir/$source.swift"
done
xcrun --sdk macosx swiftc -swift-version 6 -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -module-cache-path "$build_dir/modules" \
    'Cumulus Watch App/TestReport.swift' \
    'Cumulus Watch App/TestArchiveStore.swift' \
    'Cumulus Watch App/BackgroundMotionTrial.swift' \
    'Cumulus Watch App/AlarmRecord.swift' \
    "$build_dir/AlarmCoordinator.swift" \
    'Cumulus Watch App/ExperimentSessionOwner.swift' \
    "$build_dir/BackgroundMotionCoordinator.swift" \
    "$build_dir/ScheduledAlertCoordinator.swift" \
    "$build_dir/WatchAppDelegate.swift" \
    'Cumulus Watch App/OvernightMotionTrial.swift' \
    "$build_dir/OvernightMotionRecorder.swift" \
    "$build_dir/OvernightMotionCoordinator.swift" \
    Tests/OvernightPlatformDoubles.swift Tests/BackgroundMotionChecks.swift -o "$build_dir/checks"
"$build_dir/checks"
