# Experiment 006: Overnight motion feasibility

Status: implemented and software-verified on 2026-10-06. The reported pilot produced 59,586 samples, but its 5.42-second leading gap exceeds the 5-second criterion. Saved diagnostics inspected on October 6 also record 11 order anomalies, differing from the owner's earlier report of none. Timely visibility remains unknown, and the earlier request timing cannot separate preparation from recorder startup. The completed eight-hour comparison records 10% → 85% battery, charging, an interruption, and clock/reboot uncertainty; its battery result is inconclusive. Overnight feasibility remains unresolved.

## Question and prediction

Can this Watch supply useful accelerometer recordings across an eight-hour wear period while Cumulus is inactive, with acceptable continuity, retrieval delay, and battery use?

Prediction: if system recording is available and authorized, one fixed-duration request will produce readable, timestamped acceleration after leaving the app. Test this prediction with a short pilot before overnight trials. Evaluate retrospective research usefulness separately from timely alarm input; neither outcome validates sleep stages or waking benefit.

## Documented behavior, inference, and unknowns

Apple documents `CMSensorRecorder` recording at 50 Hz for up to 12 hours, including while the app is suspended or terminated. Recorded data is retained for up to three days. Retrieval windows must be no longer than 12 hours, missing periods have no samples, and new data may take up to three minutes to become readable. These are API behaviors, not observations from this Watch.

The installed watchOS 27 SDK exposes the recorder from watchOS 2.0, runtime availability and authorization checks, and recorded sample dates. SDK headers instruct enumeration off the main thread and on a single thread per sensor-data list. Runtime support and actual overnight behavior remain unknown. A request returning does not confirm that samples are being recorded; this API has no start-success callback. The reviewed recorder interface has no explicit stop method: Cumulus offers no **Stop recording** action. **Cancel retrieval** cancels only enumeration, and does not stop an already requested system recording. Use fixed durations, avoid overlapping requests, and let the requested duration elapse.

It is reasonable to investigate this path independently of the smart-alarm session's 30-minute limit. It does not imply continuous app execution, background query opportunities, timely delivery, or a reliable alert. Experiment 006 will not create an extended-runtime or workout session or request a haptic.

Sources checked through Context7, official Apple documentation, and the installed Watch SDK on 2026-10-06:

- [System recording](https://developer.apple.com/documentation/coremotion/cmsensorrecorder/recordaccelerometer%28forduration%3A%29)
- [Retrieval and delay](https://developer.apple.com/documentation/coremotion/cmsensorrecorder/accelerometerdata%28from%3Ato%3A%29)
- [Runtime availability](https://developer.apple.com/documentation/coremotion/cmsensorrecorder/isaccelerometerrecordingavailable%28%29)
- [Authorization](https://developer.apple.com/documentation/coremotion/cmsensorrecorder/authorizationstatus%28%29)
- [Sample dates](https://developer.apple.com/documentation/coremotion/cmrecordedaccelerometerdata/startdate)

## Implemented boundary

Choose **20-minute pilot**, **8-hour comparison**, or **8-hour recording** in Overnight motion. **Setup & conditions** captures owner-reported settings; watchOS, build, and time zone are filled automatically. **Check motion access** attempts a historical activity query, discards its records, and rechecks the recorder's own authorization. Using that activity request to establish shared Motion & Fitness permission is an inference to verify on the Watch; an activity callback alone never authorizes a recording. Unavailable, denied, restricted, and unresolved access block recording requests.

**Request recording** issues one fixed-duration request while active. **Start comparison** makes no recorder call. Both reserve shared experiment ownership, preserving the other screens but preventing conflicting sensor/session trials. **Request issued** does not mean samples started. New recordings capture preparation time separately, anchor the sample window to entry into the recorder call, and save its return date and uptime. Ownership lasts at least the full duration after the call returns; this conservative reservation can end slightly later than the sample window. **Request timing** shows the distinction. Earlier saved trials retain their original dates, results, and unknown call timing; their leading gap can include app preparation. Do not reinterpret their reported gaps as sensor-start latency.

Relaunch retains the saved window and never re-arms. A provisional window is saved before the API call; interruption before saving call timing leaves an uncertain request. The coordinator compares wall time against uptime until recording and its final retrieval/return observation are complete. A clock/reboot change during that period preserves uncertainty. A reboot after completed observations does not rewrite them or remove a completed pilot's qualification. Later reads with uncertain clock timing cannot establish visibility or replace that completed summary. After waiting the full reserved duration, the owner may explicitly **Confirm fixed window elapsed** for an uncertain request. That acknowledgement cannot resolve sample/clock evidence or stop system recording. Corrupt metadata blocks requests without deleting evidence. UserDefaults bookkeeping is not a transactional recording receipt; it cannot guarantee exactly one request across lost metadata or process failure. Do not clear app data during a request.

**Read pilot block (9–10 min)** always queries the same one-minute window. **Retrieve whole window** is enabled after its sample-window end. A periodic SwiftUI timeline refreshes time-gated controls without depending on sensor or lifecycle events; actions still check current time and app state. Apple can reduce [timeline cadence](https://developer.apple.com/documentation/swiftui/timelineview) on the Watch, so this is a display update, not a background deadline mechanism. Reads run only while active, are cancelled on exit/background, and cannot overwrite a prior summary after cancellation. Each completed read with verified clock timing replaces its corresponding summary; counts are never added across attempts. **Sample timing** lists individual failed criteria without relaxing the thresholds. The app keeps the first useful observation and the preceding incomplete pilot observation separately. An eight-hour recording requires the pilot timing/quality and four-minute visibility criteria to pass on the same OS/build. A new pilot clears that gate; conflicting new sample evidence also clears it. This gate is a software check, not an independent audit of the wearer's conditions.

The app records battery immediately before first background departure and on the first active return after the reserved end, before retrieval. **Return observations** records actual charging and interruptions; unknowns remain unknown. Comparisons require matching recorded settings and elapsed wear durations. No overall feasibility verdict is automated; classify each dimension against the procedure below.

Data flow: explicit action → system recorder → later bounded retrieval on a serial worker → streaming timing/quality summaries → Watch display and local diagnostic metadata. Process ten-minute retrieval chunks with a separate autorelease pool per query without retaining a whole night of sample objects in memory; keep every query within the documented duration limit. Account for overlap at chunk boundaries using sample timing, not by treating a batch identifier as a unique sample identifier. Validate clock continuity and preserve original dates rather than smoothing away discontinuities.

For an eight-hour request, retain at most 960 thirty-second bucket summaries, 40 lifecycle/retrieval/error events, and three recent trial summaries. Record each bucket's valid sample count, first/last sample times, maximum gap, and invalid/out-of-order counts. Keep at most 40 compact retrieval-attempt observations per trial, with probe/full-window identity, request/completion dates, count, first/last dates, nil/empty counts, cancellation, and error. Include cross-bucket gaps and window boundaries in global calculations. Streaming acceleration can be inspected for finite values without storing raw vectors in diagnostics.

Raw motion data must stay outside Git. This implementation provides no raw-vector export. Build **0.1 (5)** adds a local diagnostic archive, retaining each bounded trial independently of the three-trial recovery history. It stores metadata and summaries, not acceleration values. See the [retention and deletion design](../ARCHITECTURE.md#storage-boundaries) and README retrieval instructions. System-managed retention is distinct from Cumulus retaining data. Summaries and nonpersonal outcomes may be documented without adding health records or raw device logs.

The recorder-call timing fix was first identified as app version **0.1 (2)** in both Debug and Release. Earlier revisions shared **0.1 (1)**, so that older identifier alone cannot establish which timing implementation ran. Preserve those trials without attributing a source revision from the number. The existing pilot gate compares the recorded build and watchOS against the running app; changing the build number requires a new qualifying pilot without deleting earlier summaries. Increment the build number whenever collection, timing, or qualification behavior changes. Do not install a new build until the outstanding fixed window has ended and its result has been preserved.

Software checks on 2026-10-06 passed for rejection of a qualifying pilot from another build or watchOS, preservation of earlier pilot evidence, and the existing overnight synthetic suite. Signing-free Debug builds passed for generic watchOS and watchOS Simulator; both generated apps report **0.1 (2)**. Project parsing and whitespace checks passed. These checks do not establish physical collection, alert behavior, or interactive layout.

The latest qualification fix is **0.1 (3)**. Code review found that an early useful probe could keep the overnight gate open even after a newer completed probe of the same block was incomplete. Qualification now also requires the latest probe to be useful. The first useful observation and existing full summary stay recorded; cancellation or clock-uncertain reads cannot replace completed evidence. A later usable retry can restore qualification using the preserved early observation. The screen identifies the conflicting latest block. This corrects the software gate without changing any threshold or owner-reported outcome; preserve the outstanding run before installing.

The new missing-probe regression failed against the earlier qualification logic. After the fix, the overnight suite passed revocation, persistence across relaunch, recovery after a useful retry, and preservation across cancellation and clock-uncertain probes. Signing-free Debug Watch and simulator builds passed on 2026-10-06; both generated apps report **0.1 (3)**. Local documentation links, project parsing, and whitespace checks passed. Interactive layout and physical qualification remain unverified.

The order-anomaly diagnostic milestone was **0.1 (4)**. New full-window reads retain four bounded order-anomaly counts: both date and sensor time exactly repeat the last accepted pair; only date fails to increase; only sensor time fails to increase; or both fail to increase without exactly repeating the pair. Expected chunk overlap is counted separately before this classification. **Timing, battery & history → Inspect order anomalies** displays the breakdown. It identifies the failed comparison, not the physical cause, and changes no sample-acceptance or experiment threshold. Older summaries remain readable with their recorded total and an unavailable breakdown; do not infer subtypes for the saved 11 anomalies.

On 2026-10-06, the overnight suite passed category, expected-overlap, bounded-count, round-trip, and older-summary checks. The new model also validated the privately copied pilot archive, retaining 59,586 samples and 11 anomalies with its breakdown unknown and pilot unqualified. Signing-free Debug Watch and simulator builds passed; both generated apps report **0.1 (4)**. No new physical trial or interactive layout inspection was performed. Preserve the outstanding comparison result before installing; qualify a new pilot before a matching comparison and recording nights.

Main risk: readable daytime samples may conceal missing overnight periods, delayed retrieval, or unsustainable battery use. Alternative: retain the existing short session experiment and revisit other collection paths if the system recorder fails availability or continuity checks. No alternative implementation is selected here.

## Setup and measures

Record Watch model, watchOS, app build, time zone, availability result, authorization, wrist/lock state, Sleep Focus and sleep-tracking settings, Low Power Mode, debugger state, charging, other active apps, and observed interruptions. Unknown fields stay **Unknown**. Record clock changes or reboot separately; do not assume the wearer slept throughout an eight-hour wear period.

Measure:

- Request date, requested duration/end, app exit and return, retrieval attempt start/completion, and errors. Record the recorder's availability/authorization again when retrieving.
- Unique valid samples, finite axes, first/last dates, thirty-second bucket counts, inter-sample spacing, maximum gap across all buckets, invalid and unexpected order counts, and observed rate `(N - 1) / (last - first)` where defined. Count is not proof that every intended instant was measured.
- Leading/trailing missing time relative to the requested window. Use only samples within that window; exclude later samples and do not count overlapping query results twice.
- Battery immediately before leaving and upon returning before expensive retrieval; record percentages and measurement dates. An eight-hour comparison night uses the same settings and wear conditions with no Cumulus recording request; elapsed wear times should differ by no more than 15 minutes for this comparison. Battery drop is start minus end in percentage points; charging invalidates that comparison. A missing end reading is unknown, not zero consumption.
- Retrieval visibility: measurement dates and first observed readable dates are distinct. A first morning query can show retrospective availability only. Without earlier probes, overnight publication delay remains unknown.

## Physical procedure

1. Review the implementation diff and software checks (`./scripts/check-overnight-motion.sh`), including bucket/chunk boundaries, missing intervals, clocks, duplicate retrievals, limits, errors, and relaunch recovery. Check UI layout if a simulator is available. Simulator success is not sensor evidence.
2. Finish scheduled experiments, install the approved build, detach the debugger, and launch from the Watch icon. Keep an independent alarm. Do not reinstall or clear trial metadata during an outstanding request.
3. **Availability gate:** check recording availability and authorization on the physical Watch. If unavailable or denied/restricted, stop here and record that outcome. If authorization is unresolved, resolve it before starting a timed pilot. Do not proceed because the SDK compiled.
4. **Twenty-minute pilot:** open **Setup & conditions**, record settings, choose **20-minute pilot**, tap **Request recording** once, and leave via the Digital Crown. Return at ten minutes. Use **Read pilot block (9–10 min)** to inspect the fixed one-minute block at 30-second intervals after its end, up to four minutes. Inspect **Timing, battery & history → Retrieval attempts** for attempt start/completion, counts, latest sample date, and errors for every probe. Keep manual notes outside Git if more than 40 attempts are needed. Re-query the same block; do not sum samples across attempts. If incomplete after four minutes, probe again at six and ten minutes and record the delay as exceeding the criterion. Remain active during these probes; they do not test background querying.
5. After the pilot's requested end, tap **Retrieve whole window** at end + five minutes, then again at end + ten minutes if incomplete. Inspect the prewritten criteria. Proceed overnight only if availability, continuity, and pilot visibility criteria pass. Record a relaunch before final retrieval to check recovery without issuing another recording request.
6. **Comparison night:** choose **8-hour comparison**, tap **Start comparison**, and wear the Watch for eight hours under the intended sleep settings with no Cumulus recording request or other Cumulus experiment. Record start/end dates and battery before opening retrieval or doing other work. Record all charging, off-wrist, power, and app interruptions. If conditions differ substantially, repeat the comparison rather than attributing a difference to recording alone.
7. **Two recording nights:** on each separate night, record setup, choose **8-hour recording**, tap **Request recording** once, leave Cumulus via the Digital Crown, and wear the Watch. Do not keep Xcode attached or reopen Cumulus during the intended recording period. On one trial, let another ordinary app be foreground before lowering the wrist; record which app. Normal system suspension is allowed. Do not intentionally reboot the Watch.
8. Return at requested end + five minutes where practical. Return battery is captured before retrieval; confirm its timestamp in **Timing, battery & history**, save actual charging/interruption observations, then retrieve the requested window. Repeat at end + ten minutes if incomplete. Record actual retrieval offsets even when waking late; a late return cannot establish the five-minute availability criterion. Check first/last dates, all buckets, gaps, errors, and whether recovery issued an unintended new request. Retrieve within system retention; a missed retention window is inconclusive.
9. Compare the two recording nights and comparison night. Keep any personal details and raw files outside Git. Add only the nonpersonal result summary, metrics needed for classification, and explicit unknowns to this note.

## Predefined decision criteria

These are exploratory project thresholds chosen before trials, not Apple guarantees or validated sleep-model requirements. Evaluate each dimension separately.

| Dimension | Criterion |
| --- | --- |
| Timing usefulness, pilot and each night | At least 95% of thirty-second buckets contain at least 1,350 unique valid samples (90% of nominal 50 Hz); observed rate over the full returned span is 45–55 Hz; no inter-sample gap exceeds two seconds; leading and trailing missing time are each at most five seconds. |
| Data quality | No nonfinite axis/timing values or unresolved clock discontinuity; unexpected duplicate/order anomalies are investigated, not concealed. Expected chunk overlap is deduplicated and counted separately. |
| Pilot retrieval visibility | The fixed one-minute block meets its count/boundary criteria and is first observed complete by four minutes after the block ends. Record the prior incomplete observation and successful query completion; delay is an observation interval, not an exact publication timestamp. |
| Morning retrieval | Timing-useful data for the whole eight-hour request is readable on an attempt completed within five minutes of requested end. If first queried later, visibility by five minutes is unknown even when data is useful retrospectively. Ten-minute retry is diagnostic, not a pass substitute. |
| Battery practicality | No charging during measured wear; no more than 25 percentage points lost per recording night; at least 20% battery remains on return; each recording night's drop is no more than ten points greater than the comparable nonrecording night. Report actual elapsed durations/settings and treat differences greater than 15 minutes, setting mismatches, or absent readings as inconclusive. |
| Execution and errors | One intended recording request per trial, no automatic re-arm, no unexplained missing interval or observed recording/retrieval crash, and successful retrieval after returning/relaunching. Nil/empty retrieval is recorded separately from a thrown or system error; APIs without error callbacks must not fabricate an error reason. |

- **Retrospective motion feasibility supported under tested conditions:** pilot and both overnight runs meet timing/quality/execution criteria and the battery comparison is complete and passes. Report all metrics and conditions; a small trial does not establish all-night availability on other devices or settings.
- **Retrieval visibility supported only for the tested probes:** pilot and morning visibility criteria are met. This does not establish that Cumulus can execute timely queries while backgrounded or use samples in a live alarm.
- **Contradicted for a dimension under tested conditions:** an adequately observed valid trial fails that dimension. Preserve the failure even if a later retest passes. Unavailability blocks this path on that device/configuration.
- **Inconclusive:** missing configuration, unreadable results with unresolved authorization, late-only retrieval, charging, reboot/clock changes, missing baseline, or incomplete metrics prevent classification. Identify one next check; do not relabel missing evidence as a pass.

Useful retrospective data may coexist with unknown or failed timely visibility. Battery may fail even when sample coverage passes. Keep these conclusions separate. No result validates a sleep-stage algorithm, reliable alarm delivery, or a wake deadline.

## Result and next decision

### Owner-reported pilot

The owner supplied the following diagnostic summary in conversation. That report did not independently establish the physical run date, Watch model, watchOS, app build, setup conditions, or saved trial. Preserve it separately from the later saved-metadata inspection below. No raw logs or personal health records are included.

| Measure | Reported result | Original criterion |
| --- | --- | --- |
| Unique valid samples | 59,586 | Count alone does not establish coverage. |
| Thirty-second buckets with at least 1,350 samples | 39 / 40 (97.5%) | Meets at least 95%. |
| Observed rate | 49.95 Hz | Meets 45–55 Hz. |
| Largest inter-sample gap | 0.1 s | Meets at most 2 s. |
| Leading missing time | 5.42 s | **Does not meet** at most 5 s; exceeds it by 0.42 s. |
| Trailing missing time | 1.58 s | Meets at most 5 s. |
| Invalid samples / order anomalies | None reported | No such anomalies reported. |
| Expected overlap / nil chunks / unexpected objects | None reported | No such anomalies reported; overlap is not required. |
| Enumeration / API error | Enumeration completed; no API error reported | Reported software observations only. |

At the time of that report, empty-chunk count, outside-window count, clock/reboot warning, battery readings, interruptions, and remaining setup details were **Unknown**. The later inspection below resolves some recorded fields; it does not supply unobserved conditions.

The requested start was reported as **2:52** and the first useful pilot probe as **3:16:24**. Start seconds, date, AM/PM, and time zone were not provided. The owner confirmed pressing **Read pilot block** later; the prior incomplete observation is **Unknown**. Thus useful data was observed retrospectively, but visibility within four minutes of the block end is **inconclusive**. Do not interpret the late observation as a measured API publication delay.

**Pilot qualification was not established.** The reported leading gap fails the unchanged sample-window criterion; early visibility was not observed. Code review found that the earlier build timestamped the window before preparation and the recorder call. That confounds attribution of the 5.42 s to app preparation versus recorder startup; the new timing fields do not repair or relabel the old result. The comparison outcome below is now preserved; repeat the pilot using the corrected build and prewritten probe schedule.

### Saved pilot diagnostics inspected on October 6

At 12:44 UTC on 2026-10-06, Codex inspected a private copy of Cumulus's bounded diagnostic preferences through Xcode's read-only device tools. The connected device reported **Apple Watch Series 8, watchOS 26.6**, with **0.1 (1)** installed. The two-trial archive passed structural validation using the current summary model. The saved pilot matches the reported count and rounded timing metrics. This corroborates stored software observations; it does not reconstruct the discarded sensor stream or verify wearing, charging, or debugger conditions. The owner's model entry is not treated as independent hardware evidence for the earlier run.

Recorded dates below use the saved **America/Vancouver** time zone, UTC−07:00 on this date.

| Saved observation | Inspection result |
| --- | --- |
| Pilot requested window | 2026-10-06, 02:52:22.865–03:12:22.865; recorded watchOS 26.6 and app 0.1 (1); recorder-call timing absent. |
| Full-window summary | 59,586 accepted samples; 39/40 qualifying buckets; 49.9453 Hz; largest gap 0.1025 s; leading/trailing gaps 5.4171 s / 1.5781 s. |
| Order anomalies | **11**, whereas the owner reported none. One-based buckets 12, 25, 26, and 32 contain 1, 3, 4, and 3 respectively. The stored total cannot distinguish exact repeats from nonincreasing sample dates or sensor timestamps. Cause unresolved. |
| Other recorded diagnostics | Invalid samples, expected boundary overlap, outside-window samples, nil/empty chunks, and unexpected objects are all zero. Trial/sample clock-discontinuity flags are false; enumeration was not aborted. |
| Full read | Completed at 03:16:12.345, 229.480 s after requested end. No useful full-window observation was recorded because timing/quality checks failed. |
| Useful fixed-block probe | 2,868 samples; completed at 03:16:24.997, **842.133 s after the 9–10-minute block ended**. No preceding incomplete probe is saved. Earlier availability remains unknown; this is not measured publication latency. |
| Pilot battery observations | 25% at first departure, 02:56:27.528; 25% on return, 03:12:23.422. Charging is unknown, and these readings cover less than the whole requested window. They do not establish overnight battery cost. |
| Recorded conditions | Wrist was recorded as worn/unlocked. Low Power Mode, Sleep Focus, sleep tracking, debugger detachment, charging, and interruptions remain unknown. |

The unchanged software checks reject the saved pilot for **leading gap and order anomalies**. Preserve the earlier report and this discrepancy; do not relabel the order count as expected overlap or infer its cause. The corrected pilot must investigate order failures as well as startup timing and timely visibility.

### Eight-hour comparison: completed, battery baseline inconclusive

The owner reported an eight-hour test at approximately **10% battery remaining** and later confirmed it had not ended. The initial 12:44 UTC inspection identifies the saved mode as **comparison**, with **zero recording requests**, not an eight-hour sensor recording. Its requested window is 2026-10-06 **03:31:21.450–11:31:21.450 America/Vancouver**. First background departure and the saved 10% starting battery reading are at **04:00:08.533**, 28 min 47.084 s after the requested start. That initial snapshot has comparison phase, no return reading, and no retrieval observations. Saved watchOS/build are 26.6 / 0.1 (1); wearing, power/sleep settings, debugger detachment, charging, and interruptions are unknown.

That initial snapshot does not establish completed eight-hour wear or consumption. Read-only development-tool inspection occurred while the comparison was pending; no app launch, debugger attachment, or installation was performed by Codex. Include that tooling activity when assessing comparison conditions. At that inspection, charging had been recommended but was not yet confirmed. The 10% observation cannot establish recorder battery cost because this trial issued no recording request. It did not establish a comparison pass, recording-night pass, or feasibility conclusion.

On October 6, the owner reported that the eight-hour trial had finished. At **15:47 America/Vancouver** (22:47 UTC), a second read-only private copy of the same app's diagnostic preferences passed validation against the current model. The installed app remains **0.1 (1)**. No app launch, debugger attachment, sensor retrieval, or installation was performed by Codex.

| Final saved observation | Result |
| --- | --- |
| Mode / lifecycle | Comparison; elapsed; zero recording requests; relaunch recovery recorded. No motion summary or retrieval observations. |
| Starting battery | 10% at 2026-10-06, 04:00:08.533 America/Vancouver. |
| Return battery | 85% at 15:43:24.926; battery increased by approximately 75 percentage points. This is not measured consumption. |
| Difference between saved battery dates | 11 h 43 min 16.393 s; the saved return date is 4 h 12 min 3.476 s after the requested eight-hour window ended. These wall-clock differences do not establish uninterrupted wear, especially with the uncertainty flag. |
| Recorded return conditions | Charging **Yes**; interruption **Observed**. Details and timing of the interruption remain unknown. |
| Clock evidence | Clock/reboot-discontinuity flag is true. The stored flag does not identify its cause or establish that a reboot occurred. Treat timing as uncertain. |
| Other conditions | Wearing/lock state, Low Power Mode, Sleep Focus, sleep tracking, and debugger detachment remain unknown. |

**Battery baseline: inconclusive.** Charging violates the predefined no-charging comparison condition; the increased battery and extended measurement interval cannot estimate eight-hour battery drain. Preserve the original pending snapshot and this final observation without treating the run as a recording night or changing the criteria. The owner-reported finish and elapsed app state do not independently establish eight hours of uninterrupted wear. Overall overnight-motion feasibility remains unresolved; no corrected-build pilot or two qualifying recording nights are recorded.

The exploratory comparison outcome is now preserved. On October 6, a signed Debug build of **0.1 (4)** was installed on the connected Series 8 using the existing development signing configuration. Device metadata confirmed the installed version. A read-back found the overnight, alert, background-motion, and shared-ownership entries unchanged from the private pre-install backup; the current model validated both preserved completed overnight trials. Codex did not launch the app, attach a debugger, request recording, or change trial criteria. This verifies deployment and retained metadata, not physical sensor behavior on the corrected build. Launch from the Watch icon and repeat the corrected pilot, followed by a matching nonrecording night and two recording nights only if it qualifies. A comparison from 0.1 (1) does not match a recording on a newer build under the existing configuration checks; retain it as exploratory evidence rather than relaxing the match. Use Experiment 005 observations to decide whether internal cardiac timing inspection has a reason; grouped heart-rate records and heartbeat-series availability remain **Unknown**.

## Software verification

On 2026-10-06, `git diff --check`, all four synthetic suites, and signing-free Debug builds for generic watchOS and watchOS Simulator destinations passed with Xcode 27. The overnight suite compiles the actual model, worker, coordinator, and ownership code against deterministic platform doubles. It checks bucket/chunk boundaries, gaps, finite values, clocks, storage/enumeration limits, nil/empty results, authorization gating, one request, pilot gating, relaunch, cancellation, summary replacement, and battery comparison. The existing background suite also compiles the updated app delegate. These checks establish software behavior, not physical sensor delivery. Interactive navigation, scrolling, permissions, large text, and VoiceOver remain unverified.

The subsequent timing/UI fixes passed the same four suites and both signing-free builds. Added regression cases cover slow battery preparation, slow recorder-call return, ownership held beyond the sample-window end, explicit display-time eligibility at minute ten, loading legacy in-progress trials without re-arming, clock uncertainty before first retrieval, completed evidence surviving a later reboot, and rejection of new visibility claims from a later clock-uncertain read. A synthetic 5.42 s leading gap still fails and displays its specific reason. Initial sandboxed builds could not launch Xcode's macro helpers; rerunning with compiler access succeeded. No corrected-build physical run or interactive UI check is recorded.

## Learning exercise

A sample measured at 02:00 first appears in a query at 02:03, after an empty query at 02:02:30. State the bounds on its observed delay. Then explain why finding the same sample at 08:00 cannot reconstruct those bounds or prove that a 02:01 alarm decision could have used it. In **Request timing**, distinguish preparation → recorder call → first sample; only the last interval estimates observed startup after the request.

### Build 5 diagnostic retention

Saved tests imports the retained pilot/comparison and preserves subsequent per-run diagnostic reports, including the latest full-window bucket summary and up to 40 compact read observations per trial. It does not recover discarded vectors, missing conditions, or previously trimmed history. Capture build 5 can differ from an original trial's build 1. Existing results and criteria remain unchanged. Additional file writes may affect timing and battery: establish a new build-5 pilot and matched comparison before qualifying recording nights. Hardware archive retrieval/deletion and interactive layout remain separate checks.

On October 6, signed build **0.1 (5)** was installed on the connected Series 8 after checking that all saved trials were complete. Existing recovery entries were unchanged across installation. Opening the app without a debugger imported the retained pilot and comparison; read-only private retrieval returned both alongside alert/background reports, with zero unreadable files. The pilot still contains 59,586 samples and 11 anomalies, and the comparison contains no recording request. This is storage/retrieval verification, not a new pilot, recording night, or evidence of timely sample availability. Raw vectors and individual HealthKit records were not stored or added to Git. Interactive layout and physical deletion remain unverified.

### Build 6 guided pilot

The overnight screen now presents the next manual return/probe/read target from the original start time, including later diagnostic probes after a failed early window. It does not issue automatic queries, haptics, reminders or recording requests. Clock uncertainty suppresses countdown advice. The four-minute block-visibility deadline is based on query completion, not tapping before its end. Saved tests now validates and explains archived timing failures and inconclusive comparisons without changing recorded results. Storage-readiness checks block new trials when a report cannot predictably fit. These software/UI changes do not relax any criterion or establish a new physical pass; qualify the current build before matching comparison/recording nights.
