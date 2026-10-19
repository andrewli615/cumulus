#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir=$(mktemp -d /tmp/cumulus-alarm-trials.XXXXXX)
trap 'rm -rf "$build_dir"' EXIT
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun --sdk macosx swiftc -swift-version 6 -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -module-cache-path "$build_dir/modules" \
    'Cumulus Watch App/AlarmRecord.swift' 'Cumulus Watch App/AlarmTrial.swift' \
    'Cumulus Watch App/AlarmTrialStore.swift' 'Cumulus Watch App/TestReport.swift' \
    'Cumulus Watch App/TestArchiveStore.swift' Tests/AlarmTrialChecks.swift -o "$build_dir/checks"
"$build_dir/checks"
