# Cumulus

A watchOS smart-alarm research project. The first implementation is a **foreground data probe**: it displays acceleration and the latest readable heart-rate record with its age. It does not schedule an alarm, infer sleep stages, or collect overnight.

## The idea

Set the latest time you need to wake. During a short window beforehand, Apple Watch may choose an earlier moment to alert you. If no suitable moment is found, it should attempt to alert at the latest time. The reliability of that last step must be measured on a real Watch; this is not yet a dependable replacement for Clock.

We want to understand the measurements ourselves: inspect available Watch data, calculate explainable features, test biological interpretations, and use suitable live inputs in a wake decision. Historical records and live measurements must remain distinct.

## Open the first chunk in Xcode

1. Open Xcode and complete its license/setup prompts, including the watchOS platform download if requested. Local inspection found Xcode 27.0 (27A266a), but command-line builds are blocked by its unaccepted license.
2. Open `Cumulus.xcodeproj`. Select the **Cumulus Watch App** scheme and a Watch simulator or paired physical Watch. The project targets watchOS 27.0, matching the installed SDK and the owner's latest-version preference.
3. For a physical Watch, select your development team in Signing & Capabilities and replace `com.example.cumulus.watchkitapp` with your own unique bundle identifier. Provisioning must support HealthKit.
4. Run the app, tap **Start monitoring**, and respond to the heart-data permission request. Watch the acceleration values and sample count. Heart data can be absent or old; its displayed age is part of the experiment.
5. Tap **Stop monitoring**, or leave the app. Collection stops on background entry; reopening does not automatically restart it. Retained values are labeled and remain only in memory.

Simulator use can check build/layout only. Use a physical Watch for [Experiment 002](docs/experiments/002-live-data.md). No real measurements have been collected yet, and the initial implementation has not passed a full Xcode build.

After Xcode setup, a signing-free simulator build can be requested from the repository root with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Cumulus.xcodeproj -scheme 'Cumulus Watch App' \
  -configuration Debug -sdk watchsimulator \
  -destination 'generic/platform=watchOS Simulator' \
  -derivedDataPath /tmp/cumulus-derived-data CODE_SIGNING_ALLOWED=NO build
```

## Read the implementation

- `Cumulus Watch App/CumulusApp.swift`: SwiftUI app entry, following the standard Watch template.
- `Cumulus Watch App/ContentView.swift`: Start/Stop controls, displayed values, and background-stop handling.
- `Cumulus Watch App/MotionMonitor.swift`: requests 10 Hz acceleration updates and measures observed average frequency from sample timestamps.
- `Cumulus Watch App/HeartRateReader.swift`: requests read-only heart-rate access, queries records starting 24 hours before Start, and watches for stored updates. It does not turn on continuous heart sensing.
- `Cumulus Watch App/Info.plist` and `Cumulus.entitlements`: permission explanations and HealthKit capability. There is no background mode in this chunk.
- `Cumulus.xcodeproj/project.pbxproj` and `Assets.xcassets`: native target/build configuration and starter asset slots. The app icon is a placeholder.

No measurements are persisted, exported, or logged by this probe. Keep any future personal data and raw device logs outside this checkout.

## Working approach

Apple's public watchOS guidance favors brief, focused interactions and information that is useful at a glance. We will use that guidance to make product decisions, while treating the design as our own. A person should be able to understand the next wake time and whether it is set without navigating through a dashboard.

1. **Experience:** describe one night and the one or two interactions that matter.
2. **Behavior:** define what the alarm promises, including uncertainty and failure.
3. **Platform:** verify watchOS limits from documentation and short device experiments.
4. **Architecture:** compare simple designs and record decisions.
5. **Build:** implement one approved vertical slice at a time in the native Xcode Watch App.
6. **Refine:** test on the wrist, observe timing and clarity, then remove unnecessary complexity.

## Structure

```text
cumulus/
├── README.md
├── AGENTS.md
├── Cumulus.xcodeproj/       Native watchOS project
├── Cumulus Watch App/      Foreground probe source and assets
└── docs/
    ├── EXPERIENCE.md          User moment and Watch interaction
    ├── BEHAVIOR.md            States, promises, and failure cases
    ├── PLATFORM.md            Apple API evidence and open questions
    ├── ARCHITECTURE.md        Options and system boundaries
    ├── BUILD_PLAN.md          Thin slices and exit criteria
    ├── decisions/README.md    Why a design choice was made
    └── experiments/README.md Physical Watch experiment notes
```

Start with `docs/BUILD_PLAN.md` and `docs/experiments/002-live-data.md` for the current data milestone. `EXPERIENCE.md`, `BEHAVIOR.md`, and the session-coordinator portion of `ARCHITECTURE.md` describe the later alarm experiment, not the foreground probe's implemented behavior. Leave unanswered sections open rather than inventing certainty.

References: [Designing for watchOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos), [watchOS Pathway](https://developer.apple.com/watchos/get-started/).
