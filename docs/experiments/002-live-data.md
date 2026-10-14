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
