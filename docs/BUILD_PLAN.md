# Step-by-step build

Cumulus will investigate accessible Watch measurements, apply explainable mathematical features, test their biological interpretation, and use validated inputs to inform a wake decision. Raw motion, derived health measurements, and Apple's sleep classifications are different kinds of evidence. Access to historical data does not establish access to timely live data.

Each chunk requires owner review before editing its files. Explain the behavior, data flow, technical risk, and one alternative; then show the diff and relevant verification. The owner commits. Approval of one chunk does not approve later chunks.

| Chunk | Deliverable | Exit question |
| --- | --- | --- |
| 1. Data experiment specification | Live-data procedure and documented access limits | Do we agree what to measure and what counts as fresh data? |
| 2. Foreground probe | Standard Xcode watchOS app; Start/Stop, motion measurements, latest readable heart rate with sample age | Can the physical Watch supply samples, and does the screen distinguish current from stale data? |
| 3. Scheduled-alert feasibility | Separate alert screen, scheduled smart-alarm session, relaunch handling, and physical Watch trials | Do three alerts and a cancellation trial satisfy Experiment 001 under the recorded conditions? |
| 4. Background motion feasibility | Separate Experiment 003: short background collection, bounded timestamp/count metadata, and prewritten device criteria | Is motion collection supported under the tested conditions, independently of unresolved alert reliability? |
| 5. Explainable calculation | One motion feature, synthetic tests, and private recording replay | Can we explain and reproduce the calculation, including missing-data handling? |
| 6. Biological comparison | Compare features with available heart and sleep records | What evidence supports the interpretation, and where does it fail? |
| 7. Alarm product slice | Next-occurrence wake time, tested decision rule, honest status and fallback behavior | Can the rule operate using only information actually available at decision time? |
| 8. Refinement | Repeated nights, accessibility, battery, privacy, and architecture decision | What device evidence supports release and the choice of Watch-only or companion design? |

## First code chunk: foreground probe

Start from Xcode's standard watchOS App template, keeping its usual app entry, view, and asset structure. Add small motion and HealthKit adapters rather than new modules or a companion app.

- Tap Start to collect motion and read available heart-rate samples after requesting access. Show measurement units, sample age, and errors. An empty query means "No readable samples," not a proven permission denial.
- Tap Stop to release collection resources. Stop collection when the app enters the background; describe this boundary in the UI. Background monitoring is a later, separately reviewed chunk.
- Keep this first chunk's data in memory. No raw logs, HealthKit records, or exports belong in the repository. Persistent private recording requires a later storage decision.
- Data flow: Core Motion / HealthKit callbacks → timestamped in-memory state → SwiftUI screen. HealthKit query updates do not request continuous optical sensing.
- Main risk: old heart-rate samples can appear live. Display their age and keep them distinct from newly received motion.
- Alternative: implement motion alone first, then add the HealthKit adapter after the screen works.

Read [Experiment 002](experiments/002-live-data.md) for the staged procedure. Preserve [Experiment 001](experiments/001-scheduled-alert.md) as the separate alert-delivery test; its number does not imply it must run first. Background measurement trials must honor the smart-alarm session's intended use, including its alert requirement.

## Implemented chunk: scheduled-alert feasibility

The owner reported one successful physical foreground motion run: movement changed the samples, and Stop stopped collection. Device model, OS, exact sample counts, and timing were not recorded for that run. This is useful preliminary evidence, not completed data-quality validation.

The chooser keeps both experiments accessible. Leaving the probe stops its sensors, and an unresolved alert test disables entry to the probe. The alert coordinator owns the session for the app lifetime; navigating away from the alert screen does not cancel it. No motion or heart readings are collected by the alert session.

Tap Schedule test alert while active to request a session three minutes ahead. Show Session scheduled only after reading `.scheduled`. A running session requests the notification haptic with `repeatHandler: nil`, using Apple's documented three-second interval. Cancel and Stop alert request invalidation while the app is active. Final status follows the invalidation callback.

The app delegate attaches the delivered session's delegate synchronously on relaunch, then checks its state. The coordinator stores the requested date, unresolved-session and haptic-request bookkeeping, and the latest 40 timestamped events in local UserDefaults. A saved request alone is Unverified after relaunch; the app blocks another schedule and cannot cancel a session it has not received. Keep an independent alarm. Do not clear history or reinstall while a trial is pending.

Data flow: screen action → coordinator → WatchKit → lifecycle callbacks → local event history and displayed state. SwiftUI state updates run on MainActor; session callbacks hand off identity and timestamped event details. Old-session callbacks are ignored.

Risks: relaunch ordering, cancellation racing with session start, callback delay, and process termination around the haptic request or persistence. The local record cannot prove haptic delivery or provide a transactional exactly-once guarantee across crashes. Alternative: a foreground alert prototype is simpler but does not answer the scheduled/relaunch question.

The October 5 physical results in Experiment 001 are **inconclusive**. Preserve that result and do not repeat the alert trials as part of the next milestone. Simulator builds and synthetic lifecycle checks do not change the physical conclusion.

## Next chunk: background motion feasibility plan

[Experiment 003](experiments/003-background-motion.md) defines two 60-second background measurement trials at a requested 10 Hz and a separate manual-stop check. The plan fixes sample coverage, freshness, lifecycle criteria, and diagnostic bounds before implementation. Only metadata is retained; raw acceleration and HealthKit data are excluded.

The sensor window ends before the platform-required haptic request. That request is not a new alert-delivery assessment. Keep the foreground probe available between trials and distinguish collection stopping from session invalidation. Do not silently restart an interrupted measurement window on relaunch.

Implementation requires a separate file-level proposal and review. Build and simulator navigation checks precede debugger-detached physical trials. A successful measurement trial supports only the recorded conditions; alert reliability and any wake-deadline claim remain unresolved.

## Verification and learning

Build with the installed Xcode SDK and inspect layout in a simulator. Use physical Watch results for sensor availability, delivery delay, background behavior, battery observations, and alarm delivery. Simulator success establishes none of those properties.

For each chunk, explain one concept the owner can inspect in Xcode. Start with sample time versus receipt time; later cover callback ownership, state transitions, windowed calculations, and evaluation without using future data.

Do not infer sleep stages from an unvalidated feature or treat Apple's classifications as independent ground truth. Defer ML, dashboards, and additional health types until the measured inputs and evaluation question justify them. Keep an independent alarm for real wake requirements during development.
