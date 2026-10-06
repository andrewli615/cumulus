# Experiment 006: Overnight motion feasibility

Status: plan only. Cumulus has no overnight recorder, retrieval screen, or private recording workflow. The procedure below requires a separately reviewed implementation and software checks before it can be run in the app. No physical result is recorded.

## Question and prediction

Can this Watch supply useful accelerometer recordings across an eight-hour wear period while Cumulus is inactive, with acceptable continuity, retrieval delay, and battery use?

Prediction: if system recording is available and authorized, one fixed-duration request will produce readable, timestamped acceleration after leaving the app. Test this prediction with a short pilot before overnight trials. Evaluate retrospective research usefulness separately from timely alarm input; neither outcome validates sleep stages or waking benefit.

## Documented behavior, inference, and unknowns

Apple documents `CMSensorRecorder` recording at 50 Hz for up to 12 hours, including while the app is suspended or terminated. Recorded data is retained for up to three days. Retrieval windows must be no longer than 12 hours, missing periods have no samples, and new data may take up to three minutes to become readable. These are API behaviors, not observations from this Watch.

The installed watchOS 27 SDK exposes the recorder from watchOS 2.0, runtime availability and authorization checks, and recorded sample dates. SDK headers instruct enumeration off the main thread and on a single thread per sensor-data list. Runtime support and actual overnight behavior remain unknown. A request returning does not confirm that samples are being recorded; this API has no start-success callback. The reviewed recorder interface has no explicit stop method: a future **End trial** action must not claim it stops an already requested system recording. Use fixed durations, avoid overlapping requests, and let the requested duration elapse.

It is reasonable to investigate this path independently of the smart-alarm session's 30-minute limit. It does not imply continuous app execution, background query opportunities, timely delivery, or a reliable alert. Experiment 006 will not create an extended-runtime or workout session or request a haptic.

Sources checked through Context7, official Apple documentation, and the installed Watch SDK on 2026-10-06:

- [System recording](https://developer.apple.com/documentation/coremotion/cmsensorrecorder/recordaccelerometer%28forduration%3A%29)
- [Retrieval and delay](https://developer.apple.com/documentation/coremotion/cmsensorrecorder/accelerometerdata%28from%3Ato%3A%29)
- [Runtime availability](https://developer.apple.com/documentation/coremotion/cmsensorrecorder/isaccelerometerrecordingavailable%28%29)
- [Authorization](https://developer.apple.com/documentation/coremotion/cmsensorrecorder/authorizationstatus%28%29)
- [Sample dates](https://developer.apple.com/documentation/coremotion/cmrecordedaccelerometerdata/startdate)

## Future implementation boundary

A future proposal must provide one clearly consented fixed-duration request, availability/authorization state, requested start/end, retrieval, bounded diagnostics, and honest interruption/error states. Record requests only while active. Never re-arm on relaunch or infer recording success from saved metadata. Preserve enough metadata to retrieve the original window after relaunch.

Data flow: explicit action → system recorder → later bounded retrieval on a serial worker → streaming timing/quality summaries → Watch display and local diagnostic metadata. Process ten-minute retrieval chunks without retaining a whole night of sample objects in memory; keep every query within the documented duration limit. Account for overlap at chunk boundaries using sample timing, not by treating a batch identifier as a unique sample identifier. Validate clock continuity and preserve original dates rather than smoothing away discontinuities.

For an eight-hour request, retain at most 960 thirty-second bucket summaries, 40 lifecycle/retrieval/error events, and three recent trial summaries. Record each bucket's valid sample count, first/last sample times, maximum gap, and invalid/out-of-order counts. Include cross-bucket gaps and window boundaries in global calculations. Streaming acceleration can be inspected for finite values without storing raw vectors in diagnostics.

Raw motion data must stay outside Git. This plan authorizes no raw-data export or new persistent private recording feature; such storage requires its own retention/deletion proposal. System-managed retention is distinct from Cumulus retaining data. Summaries and nonpersonal outcomes may be documented without adding health records or raw device logs.

Main risk: readable daytime samples may conceal missing overnight periods, delayed retrieval, or unsustainable battery use. Alternative: retain the existing short session experiment and revisit other collection paths if the system recorder fails availability or continuity checks. No alternative implementation is selected here.

## Setup and measures

Record Watch model, watchOS, app build, time zone, availability result, authorization, wrist/lock state, Sleep Focus and sleep-tracking settings, Low Power Mode, debugger state, charging, other active apps, and observed interruptions. Unknown fields stay **Unknown**. Record clock changes or reboot separately; do not assume the wearer slept throughout an eight-hour wear period.

Measure:

- Request date, requested duration/end, app exit and return, retrieval attempt start/completion, and errors. Record the recorder's availability/authorization again when retrieving.
- Unique valid samples, finite axes, first/last dates, thirty-second bucket counts, inter-sample spacing, maximum gap across all buckets, invalid and unexpected order counts, and observed rate `(N - 1) / (last - first)` where defined. Count is not proof that every intended instant was measured.
- Leading/trailing missing time relative to the requested window. Use only samples within that window; exclude later samples and do not count overlapping query results twice.
- Battery immediately before leaving and upon returning before expensive retrieval; record percentages and measurement dates. An eight-hour comparison night uses the same settings and wear conditions with no Cumulus recording request; elapsed wear times should differ by no more than 15 minutes for this comparison. Battery drop is start minus end in percentage points; charging invalidates that comparison. A missing end reading is unknown, not zero consumption.
- Retrieval visibility: measurement dates and first observed readable dates are distinct. A first morning query can show retrospective availability only. Without earlier probes, overnight publication delay remains unknown.

## Physical procedure after implementation

1. Review the future implementation diff, build the Watch target, and run synthetic checks for bucket/chunk boundaries, missing intervals, clocks, duplicate retrievals, limits, errors, and relaunch recovery. Check UI layout if a simulator is available. Simulator success is not sensor evidence.
2. Finish scheduled experiments, install the approved build, detach the debugger, and launch from the Watch icon. Keep an independent alarm. Do not reinstall or clear trial metadata during an outstanding request.
3. **Availability gate:** check recording availability and authorization on the physical Watch. If unavailable or denied/restricted, stop here and record that outcome. If authorization is unresolved, resolve it before starting a timed pilot. Do not proceed because the SDK compiled.
4. **Twenty-minute pilot:** record settings/battery, request 20 minutes once, and leave via the Digital Crown. Return at ten minutes. Inspect the fixed one-minute block from minute nine to minute ten at 30-second intervals after its end, up to four minutes. Record attempt start/completion, counts, latest sample date, and errors for every probe. Re-query the same block; do not sum samples across attempts. If incomplete after four minutes, probe again at six and ten minutes and record the delay as exceeding the criterion. Remain active during these probes; they do not test background querying.
5. After the pilot's requested end, retrieve its whole window at end + five minutes, then again at end + ten minutes if incomplete. Inspect the prewritten criteria. Proceed overnight only if availability, continuity, and pilot visibility criteria pass. Record a relaunch before final retrieval to check recovery without issuing another recording request.
6. **Comparison night:** wear the Watch for eight hours under the intended sleep settings with no Cumulus recording request or other Cumulus experiment. Record start/end dates and battery before opening retrieval or doing other work. Record all charging, off-wrist, power, and app interruptions. If conditions differ substantially, repeat the comparison rather than attributing a difference to recording alone.
7. **Two recording nights:** on each separate night, record setup and battery, request eight hours once, leave Cumulus via the Digital Crown, and wear the Watch. Do not keep Xcode attached or reopen Cumulus during the intended recording period. On one trial, let another ordinary app be foreground before lowering the wrist; record which app. Normal system suspension is allowed. Do not intentionally reboot the Watch.
8. Return at requested end + five minutes where practical. Record return/battery first, then retrieve the requested window. Repeat at end + ten minutes if incomplete. Record actual retrieval offsets even when waking late; a late return cannot establish the five-minute availability criterion. Check first/last dates, all buckets, gaps, errors, and whether recovery issued an unintended new request. Retrieve within system retention; a missed retention window is inconclusive.
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

Not run. Overnight implementation is **absent**; availability, samples, retrieval delay, battery change, and errors are **Unknown**. Approve an implementation proposal separately before running this procedure. Use Experiment 005 observations to decide whether internal cardiac timing inspection has a reason; grouped heart-rate records and heartbeat-series availability are currently **Unknown**.

## Learning exercise

A sample measured at 02:00 first appears in a query at 02:03, after an empty query at 02:02:30. State the bounds on its observed delay. Then explain why finding the same sample at 08:00 cannot reconstruct those bounds or prove that a 02:01 alarm decision could have used it.
