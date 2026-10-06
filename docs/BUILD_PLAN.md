# Step-by-step build

Cumulus will investigate accessible Watch measurements, apply explainable mathematical features, test their biological interpretation, and use validated inputs to inform a wake decision. Raw motion, derived health measurements, and Apple's sleep classifications are different kinds of evidence. Access to historical data does not establish access to timely live data.

Each chunk requires owner review before editing its files. Explain the behavior, data flow, technical risk, and one alternative; then show the diff and relevant verification. The owner commits. Approval of one chunk does not approve later chunks.

| Chunk | Deliverable | Exit question |
| --- | --- | --- |
| 1. Data experiment specification | Live-data procedure and documented access limits | Do we agree what to measure and what counts as fresh data? |
| 2. Foreground probe | Standard Xcode watchOS app; Start/Stop, motion measurements, latest readable heart rate with sample age | Can the physical Watch supply samples, and does the screen distinguish current from stale data? |
| 3. Scheduled-alert feasibility | Separate alert screen, scheduled smart-alarm session, relaunch handling, and physical Watch trials | Do three alerts and a cancellation trial satisfy Experiment 001 under the recorded conditions? |
| 4. Background motion feasibility | Separate Experiment 003: short background collection, bounded timestamp/count metadata, and prewritten device criteria | Is motion collection supported under the tested conditions, independently of unresolved alert reliability? |
| 5. Stored-record inspection | Read-only sleep history first; separately reviewed cardiac and other record coverage checks | What can Cumulus read, with what sources, gaps, and availability times? |
| 6. Overnight motion feasibility | Prewritten `CMSensorRecorder` trial with availability, continuity, retrieval-delay, battery, and storage checks | Can this Watch supply useful overnight recordings without assuming continuous app execution? |
| 7. Offline model comparison | Reproduce a BIDSleep/SLAMSS-IFS benchmark and an explainable baseline | Can we reproduce results on held-out participants with compatible inputs and labels? |
| 8. Causal alarm-window estimation | Predictions using only measurements available at decision time, including uncertainty | Does the model work under the real input and latency constraints? |
| 9. Alarm-outcome evaluation | Separate trials of alert reliability and the waking benefit of the decision rule | Does the estimator improve the experience without hiding alert failures? |
| 10. Refinement | Repeated nights, accessibility, battery, privacy, and architecture decision | What evidence supports release and Watch-only or companion design? |

## Implemented chunk: foreground probe

The foreground probe uses the native watchOS target with small motion and HealthKit adapters. It adds no modules or companion app.

- Tap Start to collect motion and read available heart-rate samples after requesting access. Show measurement units, sample age, and errors. An empty query means "No readable samples," not a proven permission denial.
- Tap Stop to release collection resources. Stop collection when the app enters the background; describe this boundary in the UI. The separate background experiment owns its own collection lifetime.
- Keep this first chunk's data in memory. No raw logs, HealthKit records, or exports belong in the repository. Persistent private recording requires a later storage decision.
- Data flow: Core Motion / HealthKit callbacks → timestamped in-memory state → SwiftUI screen. HealthKit query updates do not request continuous optical sensing.
- Main risk: old heart-rate samples can appear live. Display their age and keep them distinct from newly received motion.
- Alternative: implement motion alone first, then add the HealthKit adapter after the screen works.

Read [Experiment 002](experiments/002-live-data.md) for the staged procedure. Preserve [Experiment 001](experiments/001-scheduled-alert.md) as the separate alert-delivery test; its number does not imply it must run first. Background measurement trials must honor the smart-alarm session's intended use, including its alert requirement.

## Implemented chunk: scheduled-alert feasibility

The owner reported one successful physical foreground motion run: movement changed the samples, and Stop stopped collection. Device model, OS, exact sample counts, and timing were not recorded for that run. This is useful preliminary evidence, not completed data-quality validation.

The chooser keeps the motion probe and alert experiment accessible. Leaving the probe stops its sensors, and an unresolved alert test disables entry to the probe. The alert coordinator owns the session for the app lifetime; navigating away from the alert screen does not cancel it. No motion or heart readings are collected by the alert session.

Tap Schedule test alert while active to request a session three minutes ahead. Show Session scheduled only after reading `.scheduled`. A running session requests the notification haptic with `repeatHandler: nil`, using Apple's documented three-second interval. Cancel and Stop alert request invalidation while the app is active. Final status follows the invalidation callback.

The app delegate attaches the delivered session's delegate synchronously on relaunch, then checks its state. The coordinator stores the requested date, unresolved-session and haptic-request bookkeeping, and the latest 40 timestamped events in local UserDefaults. A saved request alone is Unverified after relaunch; the app blocks another schedule and cannot cancel a session it has not received. Keep an independent alarm. Do not clear history or reinstall while a trial is pending.

Data flow: screen action → coordinator → WatchKit → lifecycle callbacks → local event history and displayed state. SwiftUI state updates run on MainActor; session callbacks hand off identity and timestamped event details. Old-session callbacks are ignored.

Risks: relaunch ordering, cancellation racing with session start, callback delay, and process termination around the haptic request or persistence. The local record cannot prove haptic delivery or provide a transactional exactly-once guarantee across crashes. Alternative: a foreground alert prototype is simpler but does not answer the scheduled/relaunch question.

Experiment 001 is **supported for the tested conditions, based on owner report**, following a change to the Watch’s haptics setting and a successful retest of all three scheduled alerts and cancellation. Preserve the original October 5 inconclusive results alongside that retest. The exact setting and retest timings are unspecified; trial summaries were not independently inspected. This does not establish overnight reliability or a guaranteed wake deadline. Simulator builds and synthetic lifecycle checks do not strengthen the physical evidence.

## Implemented chunk: background motion feasibility

[Experiment 003](experiments/003-background-motion.md) defines two 60-second background measurement trials at a requested 10 Hz and a separate manual-stop check. The plan fixes sample coverage, freshness, lifecycle criteria, and diagnostic bounds before implementation. Only metadata is retained; raw acceleration and HealthKit data are excluded.

The sensor window ends before the platform-required haptic request. That request is not a new alert-delivery assessment. Keep the foreground probe available between trials and distinguish collection stopping from session invalidation. Do not silently restart an interrupted measurement window on relaunch.

The reviewed implementation now adds the background screen, session coordinator, bounded sample summaries, and shared session ownership. Signing-free device and simulator builds and synthetic checks passed on October 5. Interactive simulator navigation/layout is still unverified because Computer Use permission was not granted. The owner subsequently reported that both background trials met the sample/freshness thresholds, that the manual-stop count stayed fixed for at least five seconds, and that alerts/cancellation worked with no observed errors. Experiment 003 is **supported under tested conditions, based on owner confirmation**. Exact measurements and trial-specific device details are unrecorded here, and the summaries were not independently inspected. Alert reliability and any wake-deadline claim remain unresolved.

## Implemented chunk: inspect stored sleep records

[Experiment 004](experiments/004-sleep-stage-feasibility.md) now has a read-only HealthKit reader and Sleep history screen showing category, original start/end dates, and source. Read / Refresh takes an in-memory snapshot of intervals overlapping the preceding seven days. It shows up to 500 intervals with explicit truncation, preserves overlaps, and clears records on screen exit or background entry. Empty results do not imply permission denial. This is historical reference-data inspection, not Cumulus sleep detection.

Signing-free device/simulator builds and focused synthetic reader checks passed. Interactive UI checks and physical record availability remain pending. The owner subsequently reported completing the UI, sleep-history, and reporting steps on October 6. Detailed outcomes and configuration were not supplied; retain that evidence limit before using the records as a reference.

The reader checks are now repeatable through `./scripts/check-sleep-history.sh`; see [test coverage](../Tests/README.md). Software implementation is complete for this chunk; the owner reports completing physical inspection, with detailed outcomes unspecified.

## Implemented chunk: cardiac-data coverage

[Experiment 005](experiments/005-cardiac-data-coverage.md) adds read-only heart-rate, SDNN, and heartbeat-series metadata snapshots for the preceding 24 elapsed hours. It retains at most 2,000, 500, and 50 records respectively, marks truncation, and keeps per-type errors separate. Source-specific summaries merge record spans and include window-edge gaps; they do not establish continuous sensing. Grouped quantity counts are visible. Internal quantity timestamps and individual beat timings/gap flags remain a separate proposal.

Records and summaries stay in memory and clear on exit/background. Verify physical availability and UI behavior with Experiment 005 before selecting model inputs. The repeatable reader checks run through `./scripts/check-cardiac-history.sh`.

## Subsequent proposals

After reviewing cardiac coverage, propose internal series timing and other stored-record coverage checks separately. Overnight motion recording, offline model comparison, and causal alarm-window estimation remain later reviewed chunks in [the sleep research roadmap](SLEEP_RESEARCH_ROADMAP.md). No production model is selected, and this reader adds no persistent health-data recording.

The research changes the order of work: an explainable feature remains valuable as a baseline, but signal availability and timing must inform its design. A 30-minute alarm session does not exclude a different system-managed recording path. Conversely, retrospective data access does not establish timely availability for an alarm.

## Verification and learning

Build with the installed Xcode SDK and inspect layout in a simulator. Use physical Watch results for sensor availability, delivery delay, background behavior, battery observations, and alarm delivery. Simulator success establishes none of those properties.

For each chunk, explain one concept the owner can inspect in Xcode. Start with sample time versus receipt time; later cover callback ownership, state transitions, windowed calculations, and evaluation without using future data.

Do not infer sleep stages from an unvalidated feature or treat Apple's classifications as independent ground truth. Keep offline model research separate from product claims; add health types only through reviewed coverage experiments. Keep an independent alarm for real wake requirements during development.
