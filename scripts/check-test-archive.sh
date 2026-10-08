#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir=$(mktemp -d /tmp/cumulus-archive-checks.XXXXXX)
trap 'rm -rf "$build_dir"' EXIT
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun --sdk macosx swiftc -swift-version 6 -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -module-cache-path "$build_dir/modules" \
    'Cumulus Watch App/TestReport.swift' 'Cumulus Watch App/TestArchiveStore.swift' \
    'Cumulus Watch App/OvernightMotionTrial.swift' 'Cumulus Watch App/SavedReportAssessment.swift' \
    Tests/TestArchiveChecks.swift -o "$build_dir/checks"
"$build_dir/checks"
