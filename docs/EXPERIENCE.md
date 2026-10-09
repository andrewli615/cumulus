# The experience

## First release — fixed alarm

The accelerated first release is a calm, Watch-only **one-time fixed alarm**. Set a time, review its full date, schedule it, edit/cancel it, and stop an active alert. Show Scheduled only from WatchKit session evidence; saved intent after relaunch stays Unverified until a session arrives. Research screens and saved tests remain available under Research.

This first version collects no motion/HealthKit data and does not estimate sleep, decide an early wake, repeat or snooze. It retains a bounded local lifecycle account, with explicit errors and no perceived-wake claim. Physical delivery, battery and accessibility must meet the [fixed-alarm acceptance criteria](BUILD_PLAN.md#accelerated-fixed-alarm-mvp--october-9). Keep an independent alarm during validation. Build 19 retains the initial alarm screen, separate hour/minute choice lists, full date/time-zone confirmation, edit/cancel/stop and a local 40-event history. Existing experiments remain under Research. Integrated physical tests are pending.

## Future smart-waking experience

### One sentence

Cumulus aims to be a calm personal Watch alarm that, after a sufficient sleep opportunity, may choose an earlier wake opportunity from validated, timely data and otherwise follows a separately tested latest-wake fallback. Its intended benefit is less sleep inertia, not a particular sleep-stage label.

This is the product target. The current app has six research screens; it does not implement that alarm flow, a production wake rule, or its fallback. Overnight input qualification remains unresolved in [Experiment 006](experiments/006-overnight-motion.md).

## A single night

1. **Before sleep:** I set the latest time I need to wake and an earlier wake window. I can review, edit, or cancel them in a few clear steps.
2. **A glance:** I see whether the alarm is armed, the latest wake time, what can trigger an earlier alert, and the fallback Cumulus expects. Saved settings alone never look armed.
3. **During sleep:** Cumulus uses only inputs qualified for this Watch configuration and available at the decision time. Old HealthKit records, Apple sleep labels, and delayed motion are not presented as live sensing.
4. **Waking:** A validated rule may select an earlier alert when current information is sufficient. Missing, stale, or uncertain inputs follow the separately tested latest-wake fallback. I can stop the alert.
5. **Afterward:** I see a brief account of the decision path, what alert Cumulus requested, and any errors or uncertainty. A recorded haptic request does not claim I felt it or woke.

The target interaction is defined; exact controls, the qualified input path, decision rule, and fallback mechanism still need design and evidence. The existing scheduled-alert experiment's short relative delay answers a different, limited delivery question. See [behavior requirements](BEHAVIOR.md).

## Product goal

The first release is for personal use on Apple Watch alone. Cumulus remains a research app until its inputs, decision method, fallback, and alert behavior have evidence behind them. Meeting the night's required minimum sleep opportunity is an eligibility gate: cycle estimates or sensor signals must never move the alarm earlier by shortening it. A planned opportunity is not proof of time actually asleep; Cumulus must validate sleep-onset and sleep/wake estimates before claiming measured sleep duration. Sleep-stage classification is one possible research task, not a required solution. A phone companion, server, or cloud sync needs a demonstrated requirement.

Evaluate the intended benefit through waking outcomes, such as repeated self-reports of grogginess and a brief, consistent post-wake performance measure. An estimated stage or cycle boundary is an intermediate prediction, not evidence that someone woke with less tiredness. Define the measurement protocol before comparing alarm strategies.

Process locally by default and retain only what the chosen behavior needs. Define retention and deletion before adding persistent health-data storage. Final battery, privacy, clearing, accessibility, interruption, delivery, and waking-outcome criteria must be written before their validation trials; see [the MVP evidence gates](BUILD_PLAN.md#personal-mvp-exit-evidence).

## Experience principles

- **Glanceable:** show the next wake time and an honest set/unset/error state first.
- **Focused:** one clear action to set or edit; avoid a deep settings hierarchy.
- **Calm:** minimal interaction before bed and a clear, tactile wake experience.
- **Trustworthy:** never label a saved preference as an armed system alarm.
- **Private:** collect only data needed for the chosen wake behavior.
- **Accessible:** readable on small Watch displays and usable with VoiceOver.

These principles apply Apple's public advice for short, specialized Watch interactions to this product; they are not a claim about Apple's internal design process. See [Designing for watchOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos) and the [watchOS Pathway](https://developer.apple.com/watchos/get-started/).

## Visual direction

Use a quiet night-sky palette: the existing black background and charcoal cards, with restrained sky-blue actions and a small cloud accent. Lavender can be a secondary decorative accent, never the only way to communicate status. Keep semantic system font sizes with the owner-selected serif design, readable labels, and clear full-width actions.

Use one compact cloud motif on the experiment chooser and shared page heading. Render the current SVG in its original colors, verify it on the minimum supported watchOS version, and hide it from VoiceOver when decorative. Keep detailed records and trial diagnostics free of repeated decoration. The current logo adapts an openly licensed SVG rather than using an SF Symbol as the app icon; its sources and notice are recorded below.

This visual pass is presentation-only: it must not change sensor collection, permissions, alert sessions, or experiment results. Check the physical Watch at normal and larger text sizes, scrolling, and VoiceOver before adopting the treatment across the app.

## Implemented cloud accent

On 2026-10-06, the chooser and each experiment's top heading gained one small blue `cloud.fill` SF Symbol through the shared `ExperimentPageHeading`. The accent sits above the heading to preserve its text width, scales with a semantic caption font, and is hidden from VoiceOver. Existing heading text, experiment symbols, dark cards, and blue actions remain. Diagnostic headings, records, and event histories stay plain. No sensor, HealthKit, session, storage, dependency, asset, or project-setting changes are included.

File purposes: `ExperimentStyle.swift` owns the decorative wrapper and synthetic normal/larger-text previews; `ExperimentChooserView.swift` applies it to the chooser introduction. `ContentView.swift`, `ScheduledAlertView.swift`, `BackgroundMotionView.swift`, `SleepHistoryView.swift`, and `CardiacHistoryView.swift` wrap only their existing top heading. `OvernightMotionView.swift` wraps its introductory title, keeping recorder diagnostics plain. This note records the treatment and verification limits.

Signing-free Debug builds passed for generic watchOS and watchOS Simulator, including previews configured for `.large` and `.xxxLarge` text. Whitespace and diff review passed. Simulator runtimes were available, but interactive preview/layout inspection was blocked when macOS declined screen-capture permission. Compilation is not visual verification. Physical small-screen scrolling, normal/larger text, VoiceOver announcements, and symbol appearance on the minimum supported watchOS 26.6 remain unverified. The attached screenshot showed the earlier motion heading and scrolling/Crown runtime warnings; it is not evidence for the new layout or the cause of those warnings. The existing physical Watch run was left alone.

Learning exercise: open the two `ExperimentStyle.swift` previews and explain why adding the cloud above the heading preserves its width as text grows. On the Watch, confirm that VoiceOver announces the heading without announcing the decorative cloud.

## First design exercise

Sketch three target states: **unset**, **armed**, and **needs attention**. For each, write the one thing someone must understand within a few seconds and the observed evidence needed to show it. Explain why saving a wake time alone cannot produce the armed state.

## Fixed-alarm UI verification — October 9

Build 16 passes signing-free Debug Watch and Watch Simulator builds and alarm/shared-session checks. An isolated 40 mm simulator renders synthetic home, setup, unverified and history states at normal (`.large`) and larger (`.xxxLarge`) text. The first screenshots revealed an oversized introduction and a wrapping history navigation title; these were shortened before final verification. The primary Set alarm action is visible on the initial home viewport at both sizes. Separate native hour/minute lists preserve large selection targets. Screenshots check initial rendering only: interactive choice/return, date confirmation after scrolling, Crown scrolling, VoiceOver and physical layout remain unverified. No physical Watch was installed, launched or scheduled for this verification.

## Cloud identity and visual pass — build 18, October 9

The owner requested an SVG cloud identity with Apple's calm visual style as a reference. The mark adapts [Lucide's cloud](https://lucide.dev/icons/cloud) into a solid silhouette, paired with a restrained sky-blue gradient for the app icon. [Apple's app-icon guidance](https://developer.apple.com/design/human-interface-guidelines/app-icons) supports simple, recognizable shapes and a background that remains visible against the Watch display; [Watch button guidance](https://developer.apple.com/design/human-interface-guidelines/buttons) favors full-width primary actions. No Apple artwork or SF Symbol is used as the logo.

Sources and file purposes:

- [SVG icon master](../design/cumulus-app-icon.svg): editable full square background and cloud. Export at 1024×1024 without an alpha channel into `Assets.xcassets/AppIcon.appiconset/AppIcon.png`; let watchOS apply its mask. The current asset catalog uses this flattened export, not an Icon Composer layered icon. No simulated glass highlights or baked corner masks are added.
- [In-app SVG](../Cumulus%20Watch%20App/Assets.xcassets/CumulusCloud.imageset/cloud.svg): template vector rendering for the matching blue heading accent, kept hidden from VoiceOver. The imageset preserves vector representation.
- [Full upstream notice](../design/LUCIDE-LICENSE.txt): ISC license and source attribution, pinned to Lucide revision `70562c1ee1c4fdcf736fe97bc893fb8511927934`. SVG copies embed the ISC notice; `CloudArtworkLicense.txt` is copied into the app bundle. The cloud is not among the upstream Feather-derived icon list. There is no runtime icon-library dependency.
- `ExperimentStyle.swift`: shared cloud styling with a compact, side-by-side home heading and vertical research headings. Detailed metrics and event rows remain plain.
- `AlarmView.swift`: full-width native actions, wrapping status/time text and the compact home heading, preserving serif typography, charcoal cards, blue actions and existing action handlers.
- The Xcode project includes the license resource and identifies this visual pass as build 18. Sensor, HealthKit, session ownership, scheduling and storage code are unchanged.

Verification: signing-free Debug Watch and Watch Simulator builds and the alarm regression suite pass. SVG parsing, opaque 1024×1024 icon dimensions and the included license resource were checked. The initial larger-text screenshot revealed a cropped button edge; the compact home header resolves that without shrinking text. Final normal/larger (`.large`/`.xxxLarge`) initial-viewport screenshots are checked on an isolated 40 mm Watch simulator. Interactive scrolling, lower-screen controls, VoiceOver and physical Watch appearance remain unverified. No physical Watch was installed or launched for this pass, and no new delivery or research result follows.

Learning exercise: compare the SVG source with its PNG app-icon export. Explain why the in-app mark remains vector, why watchOS masks the launcher icon, and why the decorative cloud is hidden from VoiceOver.

## Sleep-themed nightcap — build 19, October 9

The owner suggested a sleeping cap for the cloud. A simple original indigo cap, pale curved brim and round pom-pom now sit on the existing licensed cloud. No face, lettering, stars or extra animation is added. The icon keeps its sky-blue background and white cloud; the small in-app mark uses a blue cloud and lighter lavender cap for contrast against dark cards. The SVG geometry matches in both uses.

File purposes: `design/cumulus-app-icon.svg` remains the editable launcher source; its opaque 1024px PNG export updates the app icon. `CumulusCloud.imageset/cloud.svg` contains the same cap geometry and retains the vector/ISC notice. Its catalog now uses original colors, and `ExperimentStyle.swift` explicitly preserves those colors while keeping the mark hidden from VoiceOver and the compact layout unchanged. The project identifies this artwork revision as build 19. No new library or image-generation dependency is introduced; alarm, sensor, HealthKit and storage code are unchanged.

The launcher preview was inspected at 256px and 48px under a circular mask: the cap and pom-pom remain distinct. Normal/larger-text home screenshots on an isolated 40 mm simulator show the colored mark and fully visible Set alarm action. Watch/Simulator builds and the alarm regression suite pass; the opaque 1024px PNG matches its SVG source. Physical Watch appearance, scrolling and VoiceOver remain unverified; no alarm was scheduled by this visual pass.

Learning exercise: compare the dark cap on the bright app icon with the lighter cap on the dark in-app card. Explain why their geometry stays the same while their contrast needs differ.
