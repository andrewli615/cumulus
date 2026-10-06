# Experiment 002: Live Watch data availability

Date drafted: 2026-09-26  
Status: one successful foreground run reported; short background trials supported by owner report in Experiment 003; heart-data coverage and freshness unresolved

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
