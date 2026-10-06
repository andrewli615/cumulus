#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir=$(mktemp -d /tmp/cumulus-motion-checks.XXXXXX)
trap 'rm -rf "$build_dir"' EXIT
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
# Compile the actual coordinators against deterministic platform doubles on macOS.
for source in BackgroundMotionCoordinator ScheduledAlertCoordinator WatchAppDelegate; do
    sed '/^import WatchKit$/d; /^import CoreMotion$/d' "Cumulus Watch App/$source.swift" > "$build_dir/$source.swift"
done
xcrun --sdk macosx swiftc -swift-version 6 -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -module-cache-path "$build_dir/modules" \
    'Cumulus Watch App/BackgroundMotionTrial.swift' \
    'Cumulus Watch App/ExperimentSessionOwner.swift' \
    "$build_dir/BackgroundMotionCoordinator.swift" \
    "$build_dir/ScheduledAlertCoordinator.swift" \
    "$build_dir/WatchAppDelegate.swift" \
    Tests/BackgroundMotionChecks.swift -o "$build_dir/checks"
"$build_dir/checks"
