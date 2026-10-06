# Cumulus

A watchOS smart-alarm research app for learning which Watch measurements can support an explainable wake decision. Six experiment screens are implemented, including fixed-duration overnight motion requests and later retrieval. Cumulus does not yet infer sleep stages; overnight feasibility remains unresolved after an owner-reported pilot. Keep an independent alarm for real wake requirements.

## Current experiments

| Screen | What it does | Evidence and next check |
| --- | --- | --- |
| Motion probe | Foreground acceleration and readable heart-rate age | One owner-reported motion run; heart-data freshness remains to be assessed. [Experiment 002](docs/experiments/002-live-data.md) |
| Scheduled alert test | Requests a session three minutes ahead and a haptic while running | Original mixed results, then owner-reported successful retest after changing Watch haptics. [Experiment 001](docs/experiments/001-scheduled-alert.md) |
| Background motion test | Collects 60 seconds of sample timing/count summaries | Owner reports both background trials and manual-stop check passed. [Experiment 003](docs/experiments/003-background-motion.md) |
| Sleep history | Reads stored sleep intervals, dates, and sources | Implemented and software checked; owner reports procedure completion; individual outcomes and trial details are unknown. [Experiment 004](docs/experiments/004-sleep-stage-feasibility.md) |
| Cardiac history | Reads stored heart rate, SDNN, and heartbeat-series metadata with source-specific gap summaries | Owner reports success and all tests passed; grouped quantities, series presence, and trial details remain unknown. [Experiment 005](docs/experiments/005-cardiac-data-coverage.md) |
| Overnight motion | Requests a 20-minute pilot or eight-hour recording; streams later retrieval into bounded timing/battery summaries | Owner reports 59,586 pilot samples, but the 5.42 s leading gap fails and early visibility is unknown. An eight-hour test was reported in progress at approximately 10% battery; its result is pending. [Experiment 006](docs/experiments/006-overnight-motion.md) |

The physical reports support only the tested conditions. Experiment 006 includes owner-reported measurements; earlier experiments lack exact metrics. Setup details and independent inspection remain incomplete. They do not establish overnight reliability, validated sleep staging, or a reliable wake deadline. Each experiment note preserves its procedures, observations, and limitations.

**Next:** finish the outstanding eight-hour test on its current build and preserve its result. Then install the timing fixes and repeat the [Experiment 006](docs/experiments/006-overnight-motion.md) twenty-minute pilot, including timely fixed-block probes. New requests separate preparation from recorder-call timing; earlier trials keep their original windows. Run the qualifying battery comparison and two overnight trials only after the pilot qualifies. Keep missing nonpersonal 004/005 observations unknown; internal cardiac timing remains conditional on observed grouped quantities or heartbeat series. See [the build plan](docs/BUILD_PLAN.md) and [sleep research roadmap](docs/SLEEP_RESEARCH_ROADMAP.md).

## Open in Xcode

1. Open `Cumulus.xcodeproj` and select the **Cumulus Watch App** scheme. Local verification uses Xcode 27; the minimum deployment target is watchOS 26.6. The SDK and minimum supported OS are separate settings.
2. Select a Watch simulator or paired physical Watch. For device installation, choose your development team in Signing & Capabilities and a unique bundle identifier; provisioning must support HealthKit.
3. Choose an experiment from the app's chooser. Motion probe uses **Start monitoring**; Sleep history uses **Read / Refresh**. HealthKit results may be empty or old; neither screen requests continuous optical sensing.
4. Schedule alert and background trials while the app is active, following their linked procedures. **Session scheduled** is an observed software state; **Haptic requested** records an API call, not proof of perception. Cancel or stop with the app active. Do not reinstall or clear app data while a trial is pending.
5. Overnight motion uses one fixed-duration system request. It has no stop-recording API; **Cancel retrieval** stops reading only. Retrieve in the foreground and inspect timing, visibility, and battery separately.

Overnight **Request timing** separates preparation, recorder-call entry/return, sample-window end, and the conservative reservation end. The screen refreshes time-gated read controls and lists failed timing criteria. Old saved trials load with their original dates and unknown recorder-call timing. A reboot after completed observations preserves that evidence; a later read with uncertain clock timing cannot claim new visibility.

The owner reports completing the previous UI and sleep-history checks on 2026-10-06. Detailed outcomes and configuration were not supplied. The owner also reports Experiment 005 succeeded and all tests passed; Codex has not independently inspected its physical/UI outcomes. Simulator builds and synthetic checks do not establish physical sensor or alarm behavior.

## Verify changes

Run the synthetic suites from the repository root:

```sh
./scripts/check-background-motion.sh
./scripts/check-sleep-history.sh
./scripts/check-cardiac-history.sh
./scripts/check-overnight-motion.sh
```

See [Tests/README.md](Tests/README.md) for coverage and limits. A signing-free simulator build:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Cumulus.xcodeproj -scheme 'Cumulus Watch App' \
  -configuration Debug -sdk watchsimulator \
  -destination 'generic/platform=watchOS Simulator' \
  -derivedDataPath /tmp/cumulus-derived-data CODE_SIGNING_ALLOWED=NO build
```

For a generic device build, use `-sdk watchos` and `-destination 'generic/platform=watchOS'`. Device installation additionally needs signing.

## Find the implementation

Xcode groups organize the files by responsibility; source files remain in `Cumulus Watch App/` on disk.

| Xcode group | Files and purpose |
| --- | --- |
| App | `CumulusApp.swift`, `ExperimentChooserView.swift`, `WatchAppDelegate.swift`, `ExperimentSessionOwner.swift`: entry, navigation, relaunch routing, and exclusive session ownership. `ExperimentStyle.swift` supplies shared page, card, heading, and metric views. |
| Foreground probe | `ContentView.swift`, `MotionMonitor.swift`, `HeartRateReader.swift`: screen, motion callbacks, and read-only heart records. |
| Scheduled alert | `ScheduledAlertView.swift`, `ScheduledAlertCoordinator.swift`: controls, lifecycle, and event history. |
| Background motion | `BackgroundMotionView.swift`, `BackgroundMotionCoordinator.swift`, `BackgroundMotionTrial.swift`: trial setup, collection lifetime, and bounded summaries. |
| Sleep history | `SleepHistoryView.swift`, `SleepStageReader.swift`: historical interval display and read-only snapshot query. |
| Cardiac history | `CardiacHistoryView.swift`, `CardiacHistoryReader.swift`: read-only snapshots, grouped record counts, and source-specific record-span gaps. |
| Overnight motion | `OvernightMotionView.swift`, `OvernightMotionCoordinator.swift`, `OvernightMotionRecorder.swift`, `OvernightMotionTrial.swift`: setup, fixed-window ownership/recovery, serial streaming retrieval, and bounded timing/battery summaries. |
| Resources | `Info.plist`, `Cumulus.entitlements`, `Assets.xcassets`: permission explanations, capabilities, and starter assets. The app icon remains a placeholder. |

Foreground readings, sleep intervals, and cardiac snapshots stay in memory. Cardiac history clears on exit or background entry, with separate result/error states and explicit per-type limits. Sleep history clears on screen exit or background entry. Alert diagnostics retain the latest 40 events; background diagnostics retain five trials, twelve five-second buckets per trial, and up to 40 events per trial. Overnight diagnostics retain three trials, up to 960 thirty-second buckets, 40 events and 40 compact retrieval observations per trial, plus a small qualifying-pilot record. Raw vectors are inspected for finite values and discarded; Apple manages sensor-recording retention independently. These store no raw motion vectors or HealthKit readings. Shared session ownership blocks conflicting experiments and preserves uncertainty after relaunch. See [architecture](docs/ARCHITECTURE.md) for data flow.

## Interface

The Watch UI uses black backgrounds, charcoal cards, semantic system fonts, and blue primary actions, inspired by the visual hierarchy of Apple's website. Status and actions come before diagnostics. Background trial details remain available through **Inspect trial** and the recent-trial list; native setup controls preserve all trial fields. Sleep intervals retain their sources and full dates. Color is accompanied by text, and content wraps rather than relying on fixed-height cards.

The refresh changes presentation only. Collection, authorization, persistence, and session coordinators retain their existing behavior. SwiftUI previews are included for the shared components and foreground probe. On 2026-10-05, the UI refresh passed both synthetic suites, signing-free Debug builds for generic watchOS and watchOS Simulator, project parsing, and whitespace checks. Interactive layout, large-text, and VoiceOver checks remain pending because Computer Use permission was previously unavailable; builds and synthetic checks cannot establish those results.

## Repository map

- `Cumulus.xcodeproj/` — native Watch target and build configuration.
- `Cumulus Watch App/` — app implementation and resources.
- `Tests/` and `scripts/` — synthetic checks and repeatable runners.
- [Experiment index](docs/experiments/README.md) — procedures, outcomes, and evidence limits.
- [Build plan](docs/BUILD_PLAN.md) — implemented chunks and future milestones.
- [Research roadmap](docs/SLEEP_RESEARCH_ROADMAP.md) — signal access, candidate methods, and evaluation rules.
- [Platform](docs/PLATFORM.md) and [architecture](docs/ARCHITECTURE.md) — API evidence and implementation boundaries.
- [Experience](docs/EXPERIENCE.md), [behavior](docs/BEHAVIOR.md), and [decisions](docs/decisions/README.md) — revisable product questions and decision records.

Review each proposed chunk before editing, then inspect its diff and relevant checks. Follow [AGENTS.md](AGENTS.md) for collaboration rules. Keep personal HealthKit data, screenshots, and raw device logs outside the repository.
