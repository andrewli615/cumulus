# Step-by-step build

Cumulus will investigate accessible Watch measurements, apply explainable mathematical features, test their biological interpretation, and use validated inputs to inform a wake decision. Raw motion, derived health measurements, and Apple's sleep classifications are different kinds of evidence. Access to historical data does not establish access to timely live data.

The intended first release is **Watch-only and for personal use**: a latest wake time, an earlier wake window, an evidence-backed early decision, and a separately tested latest-wake fallback when inputs are insufficient. See [the target experience](EXPERIENCE.md) and [behavior requirements](BEHAVIOR.md). Research gates precede that product flow. Sleep-stage classification is a possible task, not a required solution; wake-opportunity or sleep/wake estimation may fit the evidence better. The [research input audit](research/INPUT_COMPATIBILITY_AUDIT.md) is complete, but no decision method or benchmark is selected for implementation yet.

For each requested chunk, explain the behavior, data flow, technical risk, and one alternative, then implement and verify it without pausing for routine approval. Keep changes small and revisable; inspect the diff and relevant checks. Commit each coherent chunk after its checks pass, write a concise message, and report it. Do not push unless asked. Completing one chunk does not authorize unrelated later work.

| Chunk | Deliverable | Exit question |
| --- | --- | --- |
| 1. Data experiment specification | Live-data procedure and documented access limits | Do we agree what to measure and what counts as fresh data? |
| 2. Foreground probe | Standard Xcode watchOS app; Start/Stop, motion measurements, latest readable heart rate with sample age | Can the physical Watch supply samples, and does the screen distinguish current from stale data? |
| 3. Scheduled-alert feasibility | Separate alert screen, scheduled smart-alarm session, relaunch handling, and physical Watch trials | Do three alerts and a cancellation trial satisfy Experiment 001 under the recorded conditions? |
| 4. Background motion feasibility | Separate Experiment 003: short background collection, bounded timestamp/count metadata, and prewritten device criteria | Is motion collection supported under the tested conditions, independently of unresolved alert reliability? |
| 5. Stored-record inspection | Read-only sleep history first; separately reviewed cardiac and other record coverage checks | What can Cumulus read, with what sources, gaps, and availability times? |
| 6. Overnight motion feasibility | Prewritten `CMSensorRecorder` trial with availability, continuity, retrieval-delay, battery, and storage checks | Can this Watch supply useful overnight recordings without assuming continuous app execution? |
| 7. Task selection and offline comparison | After inputs qualify, define the supported decision task, prewrite success criteria, and compare a reproducible method with a simple baseline outside the Watch target | Are required signals, artifacts/terms, participant-separated evaluation, uncertainty, coverage, and causal availability sufficient for this task? |
| 8. Personal alarm flow | After research gates pass, implement setup/edit/cancel/recovery, a causal wake-window rule, truthful readiness, and a separately tested latest-wake fallback | Does the rule use only information available at the decision time, and does missing/stale/uncertain data follow the tested fallback? |
| 9. Alarm-outcome evaluation | Separate trials of alert delivery, fallback behavior, and waking outcomes under criteria written before evaluation | Does the decision improve the experience under tested conditions without treating a request or stage agreement as a wake outcome? |
| 10. Personal Watch MVP refinement | Repeated nights, accessibility, battery, privacy, interruptions, and waking benefit | What evidence supports the personal Watch-only release? |

## Parallel visual design goal

The presentation-only cloud pass is implemented in [the experience guide](EXPERIENCE.md): one small decorative system cloud at the chooser and each experiment's top heading, the existing dark cards and blue actions, and plain diagnostics. Watch/device-simulator builds and normal/larger-text preview compilation passed; interactive inspection was blocked by macOS screen-capture permission. Physical layout, larger text, and VoiceOver checks remain. Sensing, HealthKit access, sessions, and storage are unchanged. Original app-icon artwork remains a later step; simulator previews are for layout only.

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

Signing-free device/simulator builds and focused synthetic reader checks passed. Codex has not independently inspected the physical/UI outcomes. The owner subsequently reported completing the UI, sleep-history, and reporting steps on October 6. Detailed outcomes and configuration were not supplied; retain that evidence limit before using the records as a reference.

The reader checks are now repeatable through `./scripts/check-sleep-history.sh`; see [test coverage](../Tests/README.md). Software implementation is complete for this chunk; the owner reports completing physical inspection, with detailed outcomes unspecified.

## Implemented chunk: cardiac-data coverage

[Experiment 005](experiments/005-cardiac-data-coverage.md) adds read-only heart-rate, SDNN, and heartbeat-series metadata snapshots for the preceding 24 elapsed hours. It retains at most 2,000, 500, and 50 records respectively, marks truncation, and keeps per-type errors separate. Source-specific summaries merge record spans and include window-edge gaps; they do not establish continuous sensing. Grouped quantity counts are visible. Internal quantity timestamps and individual beat timings/gap flags remain a separate proposal.

Records and summaries stay in memory and clear on exit/background. On October 6 the owner reported Experiment 005 succeeded and all tests passed. Treat this as an owner-reported pass under tested conditions; individual type outcomes, measurements, and setup remain unknown. Confirm grouped quantities or heartbeat series before adding internal timing readers. The repeatable reader checks run through `./scripts/check-cardiac-history.sh`.

## Implemented chunk: overnight motion feasibility

[Experiment 006](experiments/006-overnight-motion.md) now has a system-recorder screen, coordinator, serial retrieval worker, and bounded summary model. The owner approved this implementation milestone. Choose a 20-minute pilot, a nonrecording eight-hour battery comparison, or an eight-hour recording. Check recorder availability/authorization before requests; the overnight recording is gated by a qualifying pilot on the same OS/build.

One active-app action issues one fixed-duration request. New requests measure the sample window from recorder-call entry after preparation, save call-return timing, and reserve ownership through the full duration after return. Earlier saved dates remain unchanged. Relaunch never re-arms. Completed observations survive later reboot checks; uncertain new reads retain prior completed evidence and cannot claim visibility. Time-driven read controls and individual failed criteria make the pilot inspectable. No extended-runtime/workout session or haptic is added. There is no stop-recording API; cancelling retrieval stops only enumeration. Ten-minute queries stream timing/quality metadata into thirty-second buckets, with three recent trials, up to 960 buckets, 40 events and 40 compact retrieval observations per trial. Raw vectors and activity-query records are discarded. No raw-data export or HealthKit recording is added.

The initial implementation passed all four synthetic suites and signing-free Watch/device-simulator builds; interactive UI remains unverified. The owner reports 59,586 pilot samples, 39/40 qualifying buckets, 49.95 Hz, a 0.1 s largest gap, and 5.42 s / 1.58 s boundary gaps. The leading gap fails the unchanged threshold, and late-only probing leaves early visibility unknown. The old preparation timestamp confounds attribution of startup delay; preserve its failed result. An eight-hour test was subsequently reported in progress at approximately 10% battery, with its detailed outcome then unknown. The owner has since reported finishing it; the inspected comparison outcome below is preserved. Install the latest fixes and repeat the pilot. Then perform the comparable battery night and two recording nights only if the pilot qualifies. Apply timing, visibility, battery, and execution criteria independently; retrospective usefulness does not prove live availability or a reliable wake deadline.

The initial read-only saved-metadata inspection on October 6 corroborates those pilot counts and rounded gaps, but also records **11 order anomalies**, unlike the earlier report of none. Their cause is unresolved. It identified the then-pending run as a **nonrecording comparison**, with zero requests, a 10% departure reading, and no return reading. Stored watchOS/build are 26.6 / 0.1 (1); the connected device reports Series 8. The useful probe was recorded 842.133 s after the fixed block ended; earlier visibility remains unknown. See Experiment 006 for exact saved dates, missing conditions, and the development-tool inspection during the comparison. The owner later reported finishing the trial. The 15:47 America/Vancouver inspection records elapsed comparison state, zero recording requests, 10% → 85% battery, charging Yes, interruption Observed, relaunch recovery, and clock/reboot uncertainty. The saved battery dates span 11 h 43 min; the return date is 4 h 12 min after the requested end. These wall-clock differences do not establish uninterrupted wear. This battery baseline is inconclusive under the unchanged criteria. The exploratory old-build outcome is preserved; qualify the pilot and matching comparison/recording nights on the latest build.

The recorder-call timing fix was first identified as **0.1 (2)**; earlier revisions shared **0.1 (1)**. The build number changed in Debug and Release so the existing same-build pilot gate could distinguish that implementation. Regression checks reject a pilot from another build or watchOS without deleting its evidence. The overnight suite and signing-free Watch/simulator builds passed, and both generated apps reported that identifier. Future collection/timing/qualification changes must increment the number. Build verification does not establish physical recording; preserve any outstanding Watch run before installing.

The latest qualification fix is **0.1 (3)**. An early useful probe no longer keeps the gate open after a newer completed, clock-verified probe is incomplete. Qualification requires a usable latest block as well as the original timely first observation and full-window timing checks. Earlier dates and summaries remain inspectable; cancelled or clock-uncertain reads preserve completed evidence. A usable retry can restore qualification without inventing an earlier availability time. The screen explains a conflicting block; this changes no experiment threshold or physical result.

The regression failed before the fix and the overnight suite passed afterward, including revocation/relaunch/retry and preservation during cancelled or clock-uncertain probes. Signing-free Debug Watch/simulator builds passed; both generated apps report **0.1 (3)**. Links, project parsing, and whitespace checks passed. Interactive layout and physical qualification remain unverified.

The current diagnostic build is **0.1 (4)**. New full-window reads split order anomalies into repeated time pairs, date-only, sensor-time-only, and both-field failures relative to the last accepted sample. Expected chunk overlap remains separate; no sample acceptance or qualification threshold changes. **Inspect order anomalies** shows these four bounded counts. Older summaries retain their total with an unknown breakdown. Category, storage-bound, round-trip, and legacy checks passed, including loading the privately copied pilot with its 59,586 samples and 11 anomalies unchanged. Signing-free Debug Watch/simulator builds passed and both generated apps report **0.1 (4)**; interactive layout and physical qualification remain unverified.

## Current input gate

| Required evidence | Current evidence | Next action |
| --- | --- | --- |
| Corrected pilot timing and early visibility | Saved pilot fails leading gap and records 11 order anomalies; late-only reads cannot establish early visibility. | Repeat the unchanged pilot procedure on the latest build, including fixed-block probes and investigation of order failures. |
| Overnight continuity and battery practicality | The completed old-build comparison is inconclusive because charging was recorded; no qualifying matching baseline and two recording nights are documented. | Keep the preserved exploratory outcome, then classify matching trials against Experiment 006 without inferring a pass from sample count or increased battery. |
| Inputs actually usable by a decision | Short motion delivery has owner-reported passes; system-recording retrieval occurs while active. No live alarm-window input path is qualified. | Measure coverage, measurement time, first observed availability, and supported execution opportunities before choosing a method. A morning read cannot prove overnight publication timing. |
| Cardiac input contract | Overall cardiac procedure passed by owner report; grouped quantities, heartbeat-series presence, density, and freshness remain unknown. | Keep internal timing work conditional on observed record types and a concrete input need. |
| Feature values and private handling | Current motion vectors are discarded; stored timing summaries cannot reconstruct magnitude or variability. | Define required signals and local retention/deletion before adding any persistent health-data handling or benchmark input pipeline. |

No model or final wake-decision flow should be selected while these input questions remain unresolved. A successful retrospective recording alone does not qualify a live decision path.

## Subsequent proposals

The completed [input compatibility audit](research/INPUT_COMPATIBILITY_AUDIT.md) keeps SLAMSS-IFS/BIDSleep as a conditional offline candidate, not a ready-to-run live model. Cumulus currently discards raw acceleration values after timing/quality inspection; the stored summaries cannot supply model features. Heart-rate density and beat-series presence remain unknown. Resolve these input and availability gates plus preprocessing, label-initialization, artifacts, and reuse terms before proposing benchmark code or private feature handling. No dataset download, app feature, or classifier is added by the audit.

The exploratory comparison outcome is preserved. The sequence remains: repeat the corrected pilot with unchanged thresholds; qualify the comparison and two recording nights; confirm compatible, sufficiently available inputs; then select the supported task and implement its offline comparison. Report task-appropriate errors, participant-separated results, uncertainty/coverage, and causal replay separately from retrospective reproduction. Stage classification would also require per-stage errors and macro-F1. Define acceptance criteria before evaluation. If no input path qualifies, record that outcome without selecting a classifier or final wake rule. Only after research gates support it should the personal alarm flow add readiness/uncertainty states and a separately verified latest-wake fallback, followed by separate delivery, fallback, and waking-outcome trials.

Internal series timing is conditional on observed grouped quantities or heartbeat series in Experiment 005. Both are currently unknown; defer that reader unless observations provide a reason. Other stored-record coverage remains separately reviewed. Offline model comparison and causal alarm-window estimation remain later reviewed chunks in [the sleep research roadmap](SLEEP_RESEARCH_ROADMAP.md). No production model is selected, and this reader adds no persistent health-data recording.

The research changes the order of work: an explainable feature remains valuable as a baseline, but signal availability and timing must inform its design. A 30-minute alarm session does not exclude a different system-managed recording path. Conversely, retrospective data access does not establish timely availability for an alarm.

## Personal MVP exit evidence

These requirements preserve the full product goal. They are not satisfied by the existing research screens. Write measurable final validation criteria before the corresponding trials; Experiment 006's exploratory thresholds remain specific to that experiment.

| Requirement | Evidence required to call it ready | Current state |
| --- | --- | --- |
| Setup, review, edit, cancellation, stop, and recovery | Synthetic state/error checks and physical trials show understandable outcomes after relaunch and interruptions. Saved preferences and API requests are distinguished from observed scheduling state. | Final flow not implemented; only experiment controls exist. |
| Qualified and inspectable wake decision | A defined task, compatible signals, reproducible method versus a simple baseline, participant-separated evaluation, causal replay, predefined success criteria, uncertainty/coverage, and tested missing/stale inputs. | Inputs unresolved; no production method selected. |
| Latest-wake fallback and alert delivery | A supported mechanism and repeated physical tests independently establish fallback and delivery under recorded conditions, including insufficient-data and interruption paths. Requests, perceived alerts, and waking outcomes are recorded separately. | Short alert retest passed by owner report; final fallback and overnight delivery remain untested. |
| Battery practicality | Repeated physical observations meet predefined final-product battery criteria under recorded wear, settings, charging, and interruption conditions. | Overnight experiment pending; final-product criteria not yet defined. |
| Accessibility and calm presentation | Physical normal/larger-text, scrolling, and VoiceOver checks meet predefined usability criteria. Decoration stays hidden from VoiceOver; essential status uses readable text. | Cloud accent implemented; physical accessibility/layout checks incomplete. |
| Privacy and clearing | Local processing and minimal retention; storage/deletion design before persistent health data; clearing checks show intended data is removed without misrepresenting a pending alarm or system-managed recording. No personal records or raw logs in Git. | Bounded experiment metadata and in-memory readers exist; final retention/deletion design and validation remain. |
| Software checks and truthful account | Relevant synthetic checks and Watch builds pass. A concise after-action account identifies the decision path, requests, errors, and uncertainty; claims stay within tested devices/software/settings/conditions. | Experiment checks/builds pass; product account and final validation remain. |

Both a qualified wake decision and a separately tested fallback are required for the intended MVP. Agreement with Apple's sleep labels alone does not prove a better waking experience. No medical or guaranteed-wake claim follows from these experiments.

## Verification and learning

Build with the installed Xcode SDK and inspect layout in a simulator. Use physical Watch results for sensor availability, delivery delay, background behavior, battery observations, and alarm delivery. Simulator success establishes none of those properties.

For each chunk, explain one concept the owner can inspect in Xcode. Start with sample time versus receipt time; later cover callback ownership, state transitions, windowed calculations, and evaluation without using future data.

Do not infer sleep stages from an unvalidated feature or treat Apple's classifications as independent ground truth. Keep offline model research separate from product claims; add health types only through reviewed coverage experiments. Keep an independent alarm for real wake requirements during development.
