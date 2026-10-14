#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir=$(mktemp -d /tmp/cumulus-feature-checks.XXXXXX)
trap 'rm -rf "$build_dir"' EXIT
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
sed '/^import CoreMotion$/d' 'Cumulus Watch App/MotionMonitor.swift' > "$build_dir/MotionMonitor.swift"
xcrun --sdk macosx swiftc -swift-version 6 -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -module-cache-path "$build_dir/modules" \
    'Cumulus Watch App/MotionFeatures.swift' "$build_dir/MotionMonitor.swift" \
    Tests/MotionFeatureChecks.swift -o "$build_dir/checks"
"$build_dir/checks"
