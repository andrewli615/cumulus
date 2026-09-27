# Step-by-step build

Cumulus will investigate accessible Watch measurements, apply explainable mathematical features, test their biological interpretation, and use validated inputs to inform a wake decision. Raw motion, derived health measurements, and Apple's sleep classifications are different kinds of evidence. Access to historical data does not establish access to timely live data.

Each chunk requires owner review before editing its files. Explain the behavior, data flow, technical risk, and one alternative; then show the diff and relevant verification. The owner commits. Approval of one chunk does not approve later chunks.

| Chunk | Deliverable | Exit question |
| --- | --- | --- |
| 1. Data experiment specification | Live-data procedure and documented access limits | Do we agree what to measure and what counts as fresh data? |
| 2. Foreground probe | Standard Xcode watchOS app; Start/Stop, motion measurements, latest readable heart rate with sample age | Can the physical Watch supply samples, and does the screen distinguish current from stale data? |
| 3. Measurement quality | Sample intervals, receipt delays, gaps, and bounded private recording | Can we quantify coverage without confusing sample time with arrival time? |
| 4. Background and alert feasibility | Scheduled smart-alarm session, lifecycle handling, and physical Watch trials | Does collection continue in the intended wake window, and does the alert occur? |
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

## Verification and learning

Build with the installed Xcode SDK and inspect layout in a simulator. Use physical Watch results for sensor availability, delivery delay, background behavior, battery observations, and alarm delivery. Simulator success establishes none of those properties.

For each chunk, explain one concept the owner can inspect in Xcode. Start with sample time versus receipt time; later cover callback ownership, state transitions, windowed calculations, and evaluation without using future data.

Do not infer sleep stages from an unvalidated feature or treat Apple's classifications as independent ground truth. Defer ML, dashboards, and additional health types until the measured inputs and evaluation question justify them. Keep an independent alarm for real wake requirements during development.
