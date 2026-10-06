# Experiment 006: Overnight motion feasibility

Status: implemented and software-verified on 2026-10-06. An owner-reported physical pilot produced 59,586 samples, but its recorded 5.42-second leading gap exceeds the 5-second criterion, and timely visibility was not established. The earlier request timing cannot separate app preparation from recorder startup. The reported eight-hour run has no final result recorded here. Overnight feasibility remains unresolved.

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

Raw motion data must stay outside Git. This implementation provides no raw-data export or new persistent private recording feature; such storage requires its own retention/deletion proposal. System-managed retention is distinct from Cumulus retaining data. Summaries and nonpersonal outcomes may be documented without adding health records or raw device logs.

The corrected recorder-call timing is identified as app version **0.1 (2)** in both Debug and Release. Earlier revisions shared **0.1 (1)**, so that older identifier alone cannot establish which timing implementation ran. Preserve those trials without attributing a source revision from the number. The existing pilot gate compares the recorded build and watchOS against the running app; changing the build number requires a new qualifying pilot without deleting earlier summaries. Increment the build number whenever collection, timing, or qualification behavior changes. Do not install this build until the outstanding fixed window has ended and its result has been preserved.

Software checks on 2026-10-06 passed for rejection of a qualifying pilot from another build or watchOS, preservation of earlier pilot evidence, and the existing overnight synthetic suite. Signing-free Debug builds passed for generic watchOS and watchOS Simulator; both generated apps report **0.1 (2)**. Project parsing and whitespace checks passed. These checks do not establish physical collection, alert behavior, or interactive layout.

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

The owner supplied the following diagnostic summary in conversation. The physical run date, Watch model, watchOS, app build, setup conditions, and saved trial were not independently established. No raw logs or personal records are included.

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

Empty-chunk count, outside-window count, the trial's clock/reboot warning, battery readings, interruptions, and remaining setup details are **Unknown**.

The requested start was reported as **2:52** and the first useful pilot probe as **3:16:24**. Start seconds, date, AM/PM, and time zone were not provided. The owner confirmed pressing **Read pilot block** later; the prior incomplete observation is **Unknown**. Thus useful data was observed retrospectively, but visibility within four minutes of the block end is **inconclusive**. Do not interpret the late observation as a measured API publication delay.

**Pilot qualification was not established.** The reported leading gap fails the unchanged sample-window criterion; early visibility was not observed. Code review found that the earlier build timestamped the window before preparation and the recorder call. That confounds attribution of the 5.42 s to app preparation versus recorder startup; the new timing fields do not repair or relabel the old result. Repeat the pilot using the corrected build and prewritten probe schedule after the outstanding trial finishes.

### Eight-hour test in progress

The owner subsequently reported an eight-hour test running with approximately **10% battery remaining** and later confirmed that the outstanding run had not ended. Exact trial mode, initial battery, elapsed duration, observation time, charging, and final retrieval outcome are **Unknown**. Charging was recommended, but the owner has not confirmed charging. Do not infer recorder battery cost from this observation. A final uncharged return below 20% would fail the battery threshold; charging would make the battery comparison inconclusive. No eight-hour pass or feasibility conclusion is recorded.

Keep the current build installed until that fixed window finishes and preserve its summary. The next qualifying work remains the corrected pilot, a comparable nonrecording night, and two recording nights under the prewritten criteria. Use Experiment 005 observations to decide whether internal cardiac timing inspection has a reason; grouped heart-rate records and heartbeat-series availability remain **Unknown**.

## Software verification

On 2026-10-06, `git diff --check`, all four synthetic suites, and signing-free Debug builds for generic watchOS and watchOS Simulator destinations passed with Xcode 27. The overnight suite compiles the actual model, worker, coordinator, and ownership code against deterministic platform doubles. It checks bucket/chunk boundaries, gaps, finite values, clocks, storage/enumeration limits, nil/empty results, authorization gating, one request, pilot gating, relaunch, cancellation, summary replacement, and battery comparison. The existing background suite also compiles the updated app delegate. These checks establish software behavior, not physical sensor delivery. Interactive navigation, scrolling, permissions, large text, and VoiceOver remain unverified.

The subsequent timing/UI fixes passed the same four suites and both signing-free builds. Added regression cases cover slow battery preparation, slow recorder-call return, ownership held beyond the sample-window end, explicit display-time eligibility at minute ten, loading legacy in-progress trials without re-arming, clock uncertainty before first retrieval, completed evidence surviving a later reboot, and rejection of new visibility claims from a later clock-uncertain read. A synthetic 5.42 s leading gap still fails and displays its specific reason. Initial sandboxed builds could not launch Xcode's macro helpers; rerunning with compiler access succeeded. No corrected-build physical run or interactive UI check is recorded.

## Learning exercise

A sample measured at 02:00 first appears in a query at 02:03, after an empty query at 02:02:30. State the bounds on its observed delay. Then explain why finding the same sample at 08:00 cannot reconstruct those bounds or prove that a 02:01 alarm decision could have used it. In **Request timing**, distinguish preparation → recorder call → first sample; only the last interval estimates observed startup after the request.
