# Experiment 002: Live Watch data availability

Date drafted: 2026-09-26  
Status: one successful foreground run reported; short background trials supported by owner report in Experiment 003; heart-data coverage and freshness unresolved; build 20 adds in-memory foreground movement features, physically unverified

Device / watchOS / Xcode: record exact values before each run

## Question

Which measurements can Cumulus read, how old are they on arrival, and under which app states can they inform a live wake decision?

## Prediction

A foreground Watch app can obtain motion samples on supported hardware. Readable HealthKit heart-rate samples may arrive less frequently or represent earlier measurements. A later smart-alarm session may support useful collection during a short wake window. These are predictions, not observed results.

## Staged implementation

1. Foreground screen: Start/Stop, current motion, latest readable heart rate, and sample age. Hold data in memory; stop collection on background entry.
2. Experiment 001 preserves the original October 5 inconclusive trials and a subsequent owner-reported pass of all three alerts and cancellation after changing Watch haptics. Exact retest settings and timings were not supplied; summaries were not independently inspected.
3. [Experiment 003](003-background-motion.md) implements the short background sensor window and bounded diagnostics. Its two background runs and manual-stop check passed according to the owner, with exact measurements and device/setup details unrecorded here. No raw acceleration vectors or HealthKit records are persisted by that trial.
4. Next, propose read-only sleep-history inspection and then broader stored-record coverage checks. Overnight motion recording through `CMSensorRecorder` is a separate, untested candidate requiring its own reviewed procedure. See [the research roadmap](../SLEEP_RESEARCH_ROADMAP.md).

The first stage cannot establish background or overnight collection. Do not substitute a workout session for a smart alarm.

## Signals

| Signal | Initial role | Interpretation boundary |
| --- | --- | --- |
| Acceleration x/y/z | First live measurement | Raw acceleration includes gravity; it is not a sleep stage. |
| Heart rate | Read latest and newly available HealthKit records | Beats per minute is a derived measurement; receipt does not imply recent sensing. |
| Heartbeat series | Later feasibility query | Optional stored series may have gaps; do not assume a continuous live beat stream. |
| Sleep categories | Later historical comparison | Apple's inferred categories are not independent ground truth or a promised live feed. |

## Evidence fields

For each run, record hardware model, OS/build versions, app build, wrist state, battery state, power mode, app state, and whether the debugger is attached. Keep personal records outside the repository.

For instrumented samples, retain signal, unit, source, measurement start/end or motion timestamp, receipt timestamp, and gap/error indicators. Distinguish newly received records from repeated reads of the same record.

- Sample interval: elapsed measurement time between successive samples.
- Receipt delay: receipt time minus measurement time (or end time for an interval sample).
- Current age: now minus the latest measurement time.
- Coverage: samples and missing stretches across the run, including the longest observed gap.

Use a monotonic clock for motion intervals. Map motion uptime to wall-clock time explicitly when calculating receipt delay; record that mapping and any clock discontinuity. Never mix clock origins silently.

## Procedure

1. Install the probe on a physical Watch from Xcode. Record the run configuration. Grant only the requested data access you intend to test.
2. With the app open, tap Start. Sit still for one minute, then gently move your wrist for one minute. Confirm motion responds and heart-rate age advances honestly when no new measurement appears.
3. Tap Stop. Verify collection stops and the screen does not describe retained values as actively monitored. Start again and check for duplicate callbacks or counters from the prior run.
4. In the foreground-only version, leave the app and reopen it. Verify the UI reports stopped collection rather than implying monitoring continued. This checks the boundary, not background feasibility.
5. After instrumentation exists, repeat the foreground trial three times. Inspect sample intervals, delay distribution, and longest gaps. An empty HealthKit query is "No readable samples," not proof of a denied permission or absent sensor.
6. For background measurement, use the prewritten procedure and criteria in the implemented Experiment 003 for any separately justified further trials. Run with the debugger detached. Its required haptic request occurs after motion collection and does not repeat or rescore Experiment 001.
7. Repeat only after recording the result and changing one condition at a time. Overnight trials come later, after short-window behavior is understood.

## Outcome criteria

- **Foreground path demonstrated:** observed motion reacts to the trial, stopping releases collection, and the UI truthfully shows readable heart data or an empty/error state. Heart data may still be unsuitable for live decisions.
- **Live signal candidate:** repeated device runs quantify its coverage and delay in the intended app state. Before adding an algorithm, choose a maximum acceptable age and minimum coverage for that algorithm and evaluate these measurements against them.
- **Historical only in tested conditions:** records are readable but arrive too late for the proposed decision window.
- **Inconclusive:** instrumentation, access, clock mapping, or inconsistent results prevent a conclusion. Preserve the uncertainty and identify the next isolated test.

No pass condition establishes biological accuracy, overnight reliability, or that a person will wake. Keep an independent alarm for real wake requirements during development.

## Result

Foreground probe source and native Xcode project are present. A signing-free Debug build for the watchOS 27.0 simulator SDK passed with Xcode 27.0 (27A266a) on 2026-09-26. Project/permission property lists passed validation. The only build warning was skipped App Intents metadata extraction because the app has no App Intents dependency.

During the initial 2026-09-26 build check, no Watch simulator device was available. This historical limitation is separate from the later device observation below.

### Owner-reported physical observation, recorded 2026-10-02

One foreground motion run succeeded: samples responded to wrist movement and stopped when the owner stopped monitoring. The run's exact date/time, device model, watchOS version, sample counts, rates, and debugger attachment were unrecorded. Do not fill these gaps from the intended device or project settings. No raw measurements are stored here.

This supports foreground motion response and manual stop for one reported run. It does not establish heart-rate freshness, permission behavior, background-stop handling, sampling quality, biological interpretation, or alarm reliability. Experiment 001 separately preserves the original inconclusive alert outcomes and the owner-reported successful retest after changing haptics. Experiment 003 records owner-reported successful background sample/freshness checks and a manual-stop count that stayed fixed for at least five seconds. Those summaries were not independently inspected and exact measurements and trial-specific settings were not supplied. They support the respective tested conditions, not overnight sensing, sleep-stage accuracy, or reliable wake timing.

## Learning exercise

Suppose a heart-rate sample was measured at 07:10 but received at 07:13. At 07:13:30, its receipt delay is three minutes and its current age is three minutes thirty seconds. Explain why it must not be used to replay a decision at 07:11 as if Cumulus already knew it.

## Foreground movement features — build 20, October 14

**Implementation:** the existing foreground-only 10 Hz request now feeds a streaming movement-feature calculation. It retains only the current and latest completed 30-second window in memory; no raw samples, feature values or additional HealthKit readings are written to disk. Existing Saved tests still store diagnostic counts/status only. Start resets the feature state; Stop/background/navigation/error freezes it and queued callbacks from an old run are ignored. The alarm and system recorder are unchanged.

**Calculation contract:**

- For each finite, ordered sample in g, magnitude is `hypot(hypot(x, y), z)`. Mean magnitude and population standard deviation describe the observed magnitudes; variability needs at least two samples.
- ENMO is `max(magnitude - 1, 0)` per sample, then averaged over accepted samples. Values are displayed in g. This follows the published movement-metric definition, without adopting a study's activity thresholds, calibration procedure, filtering, classifier or claimed accuracy. It is sensitive to calibration; it is not true vector gravity removal or a sleep label. See [Bakrania et al., PLOS ONE](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0164045).
- Windows start at the first accepted sensor timestamp and are half-open: a sample exactly at the end belongs to the next window. Completion is observed only when a later accepted sensor time reaches the next window. Whole empty windows are counted and skipped, not filled with zeros. Stop never converts the current partial window into a complete one.
- Arithmetic uses Welford's streaming variance and an online mean; raw vectors are discarded after use. Observed rate is `(count - 1) / (last - first)` and is not the requested rate or proof of continuous coverage. No interpolation, future-window values or whole-night normalization enters a completed window.
- Leading/trailing and within-window gaps, the largest inter-sample gap across the run, receipt delay, sample age, invalid-value/clock counts and duplicate/backward-time counts remain visible. The trailing gap is shown only for the completed window. A completed window has no automatic quality pass and no sleep/wake classification. Invalid/overflow/future-clock data and non-increasing sensor times do not enter the features or the displayed accepted-sample count. While monitoring, a latest accepted sample older than two seconds is labeled as not recent; this is a display diagnostic, not a physiological cutoff or quality pass.

**Documented platform behavior:** Apple defines [acceleration axes in g](https://developer.apple.com/documentation/coremotion/cmacceleration) and [motion timestamps as seconds since boot](https://developer.apple.com/documentation/coremotion/cmlogitem/timestamp). Context7 and official Apple documentation were checked October 14. Receipt is captured on the motion callback queue using the existing uptime clock; measurement time drives windows, rather than main-thread update time. This foreground diagnostic does not establish recorder availability, all-night clock mapping or an alarm-window input path.

**Short awake walkthrough (physical result not yet reported):** finish any pending alarm/research session, install build 20 without clearing saved data, then open Research → Motion probe. Keep an independent alarm for real waking requirements.

1. Tap Start and hold the wrist comfortably still for about 35 seconds while keeping the probe active. Inspect **Features**: a completed window should appear after the boundary is crossed by a later sample. Record accepted count/rate and quality diagnostics; an approximately 1 g quiet magnitude is a sanity check, not a calibrated tolerance or pass threshold.
2. Move the wrist gently for another minute. Compare magnitude variability/ENMO across completed windows; movement need not increase both metrics for every motion. Rotation at constant magnitude can leave both low. Do not interpret either as sleep or deep sleep.
3. Tap Stop; verify summary counts and values remain fixed while displayed sample age increases. Start again and verify summaries/counters reset. Leave via the Crown and return; collection must be stopped. Inspect normal/larger text and VoiceOver labels while scrolling.
4. Keep unobserved values unknown. The summaries are not exported or saved, so an observation needed for later evaluation must be captured privately before restarting/leaving. No personal data belongs in Git. This walkthrough checks foreground sensing/display behavior only; intended-state availability, calibration, biological meaning and overnight battery remain unresolved.

**Software verification:** the new synthetic suite checks known magnitudes/variance/ENMO, orientation invariance, boundaries, missing windows and gaps, receipt delay, invalid/order/clock input, numerical overflow, bounded state, freezing/restart and the actual monitor's callback handoff. All existing regression checks and signing-free Watch/Simulator builds pass; physical feature behavior remains untested. Initial-viewport screenshots on an isolated 40 mm watchOS 27 simulator were inspected at normal and larger text (`.large`/`.xxxLarge`); the heading/intro were shortened to avoid an oversized opening. These screenshots do not verify the lower diagnostics, interactive scrolling, VoiceOver or physical layout. Simulator was not available to the UI-control tool, so those checks remain unverified. No physical Watch installation, sensing or trial was performed by this milestone.

Learning exercise: a stationary awake wrist and a sleeping wrist can both have low ENMO. Explain what additional signal/reference evidence would be needed before labeling either window asleep.

## Optional saved movement windows — build 21, October 15

**Implemented; first physical saved captures inspected October 16 below.** Research → Motion probe now offers **Save movement summaries**, off by default on entry and locked during a run. Read the on-screen retention explanation before enabling it. Memory-only monitoring still works. HealthKit query behavior and the fixed alarm are not used as feature inputs. No new permissions, raw recording, background session or sleep classifier are added.

When enabled, the initial report must save before the sensor starts. Completed windows save at their boundaries; Stop, leaving/background entry, API error, storage failure or the ten-minute deadline stops saved collection and attempts a final snapshot containing the partial window. The foreground deadline is cooperative; actual stop can be delayed by execution, while callback checks prevent accepting later samples. At most twenty completed windows and one partial are retained per run. A cached measurement earlier than the run start is counted and excluded; invalid, order and skipped-window diagnostics remain distinct. Empty windows are not fabricated. A failed write preserves the previous snapshot and stops collection; an abruptly terminated process leaves completion **unrecorded**, without automatically restarting sensors.

The versioned payload includes g units, requested 10 Hz rate, calculation/source versions and original build/OS. It stores derived magnitude/SD/ENMO, counts/gaps/delays, relative sample/receipt bounds and snapshot calculation/observation time. Wall/uptime disagreement beyond two seconds is flagged as a diagnostic mismatch, not a validated accuracy tolerance. Observation time is a conservative availability observation for that snapshot, not the earliest sensor publication; partial features can have been available earlier. Feature rows are not enough to reconstruct raw vectors or arbitrary model preprocessing.

**Retention:** one foreground report in the existing local archive (200 reports/32 MB, protected and backup-excluded). No automatic upload or eviction. Delete through Saved tests → Delete completed test data when no session is pending; this also clears other completed research reports/qualification, so preserve needed histories first. Alarm history is separate. Exported private copies survive app deletion. Derived movement and timing can still be personal data; keep exports and device logs outside Git. See [the storage policy](../ARCHITECTURE.md#foreground-feature-retention--october-15).

**Short physical procedure:**

1. Finish/preserve pending requests and install build 21 without deleting Cumulus. Open Research → Motion probe and enable Save movement summaries. Start, keep the screen active and the wrist comfortably still for about 35 seconds, then move gently for another minute. Do not infer sleep from either condition.
2. Stop, then open Saved tests → Foreground movement features → Movement windows. Verify completed and partial rows are separately labeled. Compare counts, gaps, delays and feature values with the live probe; a completed row is not an automatic quality pass. Confirm original build/OS and stop reason.
3. Reopen the app and verify the report remains readable without collection restarting. Save the report privately using `scripts/retrieve-test-archive.py`; the decoded `diagnostics` contains the feature rows, with Unix dates and relative uptime seconds explicitly separate. Do not transcribe every row manually.
4. Check normal/larger text, scrolling and VoiceOver. Before any deletion check, preserve existing reports and confirm no alarm/research request is pending. Deletion must leave research history empty after reopen while alarm history remains separate. Do not delete unrelated evidence merely to run this procedure. Leave missed observations unknown.

Synthetic checks cover the model, real archive/monitor integration, format/identity and legacy handling, bounds/deadlines, calculation availability, pre-start/late samples, clock shifts, stop/restart/relaunch/deletion and actual write failure. Python checks verify exported feature payloads preserve fractional times and values. Software outcomes do not establish physical sensor delivery, battery practicality, all-night inputs or biological meaning.

Learning exercise: compare the last sample time, last receipt time and feature observation time in one saved row. Only the observation bounds when this particular summary was known to the app.

Build-21 software verification completed October 16: all nine Swift suites and five Python checks pass, as do signing-free Debug Watch/Simulator builds (both 0.1 (21)), project parsing, links and whitespace. Initial synthetic probe/saved-window viewports were inspected on a task-only 40 mm watchOS 27 simulator at `.large` and `.xxxLarge`; source preserves scrolling layouts, 44-point primary actions and combined metric accessibility labels. Interactive scrolling, save selection, row navigation, VoiceOver and physical layout were not verified because Simulator was unavailable to the UI-control tool. No physical Watch install, launch, sensor request or user-data deletion was performed.

### First saved-capture inspection — October 16

**Read-only physical evidence:** the connected Series 8 archive contains two new foreground feature reports, both recording original build **0.1 (21)** and watchOS **26.6**. All eleven archived reports decode and pass the actual app's report/assessment validators. Both foreground captures record manual Stop, no clock mismatch, and zero invalid, order-anomaly, skipped-window or pre-start counts. The short capture lasts about 1.68 seconds and retains two samples in a partial window only; it cannot demonstrate a completed window.

The longer capture lasts about **88.46 seconds**, with **884 accepted samples**: two completed 30-second windows of **300 samples each**, then a separately labeled **284-sample partial**. Row counts sum exactly to the run count. Each row measures about **9.99 Hz**; the largest sample gap is **0.100100 seconds**, and maximum callback receipt delay is **0.049317 seconds**. Completed snapshots were observed about **0.035 and 0.065 seconds after their window boundaries**. Wall/uptime elapsed differences are below 0.001 seconds in these two snapshots. These are observed software timings, not guaranteed latency or calibrated clock accuracy.

This supports physical foreground sampling, completed/partial separation and readable local persistence for these runs. Derived features differ between windows, but still/moving periods were not labeled; no known-state response, raw-vector arithmetic reproduction, sleep estimate or all-night input qualification follows. Reopen behavior, physical deletion, interactive accessibility and storage/battery overhead remain unverified. The seven older overnight payloads are unchanged; updated outer capture metadata does not turn an old trial into a new recording.

**Next:** use these saved rows for the timing/quality review; no repeat is needed merely to obtain a readable capture. Before a known-state feature comparison, record the still/moving phase boundaries privately and preserve the report. Keep the next algorithm step a separately specified simple offline sleep/wake baseline only after its input path, coverage, availability and comparison reference are established. Exact dates, identities, feature rows and exports remain outside Git. Inspection did not install, launch, schedule or delete anything on the Watch.
