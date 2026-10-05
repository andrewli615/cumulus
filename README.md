# Cumulus

A watchOS smart-alarm research project with two experiments: a **foreground motion probe** showing acceleration and readable heart-rate age, and a **scheduled alert test** requesting a WatchKit session three minutes ahead. Alert delivery is not yet validated on a physical Watch. The app does not infer sleep stages or collect overnight sensor data.

## The idea

Set the latest time you need to wake. During a short window beforehand, Apple Watch may choose an earlier moment to alert you. If no suitable moment is found, it should attempt to alert at the latest time. The reliability of that last step must be measured on a real Watch; this is not yet a dependable replacement for Clock.

We want to understand the measurements ourselves: inspect available Watch data, calculate explainable features, test biological interpretations, and use suitable live inputs in a wake decision. Historical records and live measurements must remain distinct.

Next is the **planned, not implemented** [background motion experiment](docs/experiments/003-background-motion.md): two short background collection trials and a manual-stop check, with predefined sample/lifecycle criteria and bounded diagnostic metadata. The October 5 alert result stays **inconclusive**; those trials will not be repeated. Successful sensor collection would not establish reliable alerts or wake timing.

## Open the experiments in Xcode

1. Open Xcode and complete any setup prompts. Local builds use Xcode 27.0 (27A266a). Install the watchOS simulator runtime in Xcode Settings → Components if needed.
2. Open `Cumulus.xcodeproj`. Select the **Cumulus Watch App** scheme and a Watch simulator or paired physical Watch. The minimum deployment target is watchOS 26.6, allowing installation on the owner's Series 8 running that version. Xcode can still build with the watchOS 27 SDK; the SDK and minimum supported OS are separate settings. Device installation and runtime behavior still require verification.
3. For a physical Watch, select your development team in Signing & Capabilities and replace `com.example.cumulus.watchkitapp` with your own unique bundle identifier. Provisioning must support HealthKit.
4. Choose **Motion probe**, tap **Start monitoring**, and respond to the heart-data permission request. Watch the acceleration values and sample count. Heart data can be absent or old; its displayed age is part of the experiment. Stop or leave the probe to end collection.
5. Choose **Scheduled alert test** and tap **Schedule test alert** while active. Requested start is three minutes ahead. **Session scheduled** describes the observed WatchKit state; **Haptic requested** describes an API call, not a perceived alert. Use **Cancel** while pending or **Stop alert** while running, with the app active.
6. For physical alert trials, launch from the Watch app icon without an attached debugger and follow [Experiment 001](docs/experiments/001-scheduled-alert.md). Keep an independent alarm for any real wake requirement. Do not reinstall or clear app data during a pending trial.

The owner reported one successful physical foreground motion run: samples reacted to wrist movement and stopped on request. Its device model, OS, and exact counts were unrecorded; see [Experiment 002](docs/experiments/002-live-data.md). October 5 physical testing was **inconclusive**: two of three scheduled trials produced an observed alert and haptic; one did not despite recorded start and haptic-request events. No alert appeared after cancellation. See [Experiment 001](docs/experiments/001-scheduled-alert.md) for details and missing measurements. Simulator results are not alarm evidence.

On 2026-10-02, the alert milestone passed a signing-free simulator build and synthetic coordinator checks, and installed/launched on a 40 mm Watch simulator. Interactive navigation and layout verification remain pending because Computer Use permission was not granted. See Experiment 001 for the verification limits and private trial worksheet.

After Xcode setup, a signing-free simulator build can be requested from the repository root with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Cumulus.xcodeproj -scheme 'Cumulus Watch App' \
  -configuration Debug -sdk watchsimulator \
  -destination 'generic/platform=watchOS Simulator' \
  -derivedDataPath /tmp/cumulus-derived-data CODE_SIGNING_ALLOWED=NO build
```

## Read the implementation

- `Cumulus Watch App/CumulusApp.swift` and `ExperimentChooserView.swift`: app entry and navigation between experiments.
- `Cumulus Watch App/WatchAppDelegate.swift`: immediately attaches sessions delivered by WatchKit during relaunch.
- `Cumulus Watch App/ScheduledAlertCoordinator.swift`: session lifecycle, truthful status, and a local history capped at 40 events.
- `Cumulus Watch App/ScheduledAlertView.swift`: scheduling, cancellation, stop, requested time, and event inspection.
- `Cumulus Watch App/ContentView.swift`: Start/Stop controls, displayed values, and background-stop handling.
- `Cumulus Watch App/MotionMonitor.swift`: requests 10 Hz acceleration updates and measures observed average frequency from sample timestamps.
- `Cumulus Watch App/HeartRateReader.swift`: requests read-only heart-rate access, queries records starting 24 hours before Start, and watches for stored updates. It does not turn on continuous heart sensing.
- `Cumulus Watch App/Info.plist` and `Cumulus.entitlements`: permission explanations, HealthKit capability, and the single Alarm background mode.
- `Cumulus.xcodeproj/project.pbxproj` and `Assets.xcassets`: native target/build configuration and starter asset slots. The app icon is a placeholder.

The motion probe keeps readings in memory and stops when you leave it. The alert test stores only its requested date, lifecycle bookkeeping, and last 40 timestamped events in local UserDefaults. It collects no motion or HealthKit readings; entry to the motion probe is disabled while an alert is attached or unresolved. A saved pending request alone displays **Unverified after relaunch**, blocks another schedule, and cannot be canceled until WatchKit supplies the session. Keep personal data and raw device logs outside this checkout.

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
├── Cumulus Watch App/      Motion and scheduled-alert experiments
└── docs/
    ├── EXPERIENCE.md          User moment and Watch interaction
    ├── BEHAVIOR.md            States, promises, and failure cases
    ├── PLATFORM.md            Apple API evidence and open questions
    ├── ARCHITECTURE.md        Options and system boundaries
    ├── BUILD_PLAN.md          Thin slices and exit criteria
    ├── decisions/README.md    Why a design choice was made
    └── experiments/README.md Physical Watch experiment notes
```

Start with `docs/BUILD_PLAN.md` and `docs/experiments/001-scheduled-alert.md` for the current milestone. The broader experience and architecture documents remain revisable proposals. Alert feasibility precedes background sensor trials; leave unanswered questions open rather than inventing certainty.

References: [Designing for watchOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos), [watchOS Pathway](https://developer.apple.com/watchos/get-started/).
