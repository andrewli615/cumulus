# Experiment 005: Cardiac-data coverage

Status: owner reports Experiment 005 succeeded and all tests passed. Detailed per-type observations and trial configuration remain unknown. Software verification is recorded below.

## Question

Which stored heart-rate quantities, SDNN summaries, and heartbeat series can Cumulus read on this Watch over a 24-hour window? How do counts, sources, record spans, and gaps constrain later signal research?

This experiment measures historical record availability. A read timestamp is when this query received a snapshot; it does not reconstruct when each record first became available for an alarm decision.

## Implemented behavior

Finish any scheduled session, open **Cardiac history**, and tap **Read / Refresh**. The app requests read access to heart rate, heart-rate variability SDNN, and heartbeat series with no write types. Three independent queries inspect records overlapping the preceding 24 elapsed hours ending at the tap time. Original boundaries are preserved, including records crossing the window boundary. Rows are sorted by record start, newest first.

The limits are 2,000 heart-rate records, 500 HRV records, and 50 heartbeat-series records. Each query requests one extra record to detect truncation. A truncated result is explicitly partial; counts and gap summaries cannot establish completeness. Unexpected or invalid records are skipped with a visible count and incomplete-evidence warning. Each type has its own read time or error, so one failed query does not erase another successful result. Empty results do not prove denied permission.

- Heart rate displays stored quantity values in bpm and the quantity count. Records with count greater than one are labeled grouped. Their individual quantity values and timestamps are not expanded by this milestone.
- HRV displays stored SDNN in milliseconds, dates, sources, and quantity counts. It does not derive variability from BPM records.
- Heartbeat series displays start/end, source, and recorded beat count. The overview does not query individual beat timings or gap flags. Build 6 offers a separate conditional inspector only when an eligible record is observed; see [Experiment 007](007-cardiac-internal-timing.md).

Each source summary groups by source bundle identifier and source name. This is app/source attribution, not a guarantee of one physical device per group. It shows record count, grouped quantity record count where applicable, earliest start, latest end, and the longest interval outside record spans. That calculation merges overlapping spans, clips them to the query window, and includes leading and trailing gaps. It is not a measurement of continuous physiological coverage: a record span can contain intermittent measurements, missing beats, or a summary value. No fraction of valid sensing time or physiological sampling rate is inferred.

**Show records** expands the source-preserving interval list without leaving the reader screen. Refresh replaces the snapshot. Navigating away or backgrounding cancels all outstanding queries and clears records and summaries. A pending permission request may finish, but its old request identifier cannot start queries after clearing. Inactivity for a permission sheet alone does not clear the reader. There is no persistence, export, or logging of health records.

Data flow: screen action → read authorization → three bounded HealthKit queries → Sendable record snapshots → MainActor state → source-specific summaries and UI. The reader owns cancellation and rejects late callbacks. The primary risk is interpreting historical, incomplete record spans as continuous or timely input. The alternative is inspecting heart rate alone first, with less information about potential beat-based inputs.

## Documented behavior

Apple documents quantity sample counts and quantity-series queries, heartbeat-series samples, and SDNN as different representations. A grouped quantity's internal entries require a quantity-series query; individual beats require a heartbeat-series query. These APIs do not promise readable continuous overnight inputs on this particular Watch.

Sources, checked with Context7 and the installed Watch SDK on 2026-10-06:

- [Quantity counts](https://developer.apple.com/documentation/healthkit/hkquantitysample/count)
- [Quantity-series queries](https://developer.apple.com/documentation/healthkit/hkquantityseriessamplequerydescriptor)
- [SDNN](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilitysdnn)
- [Heartbeat series](https://developer.apple.com/documentation/healthkit/hkheartbeatseriessample)
- [Beat-timing queries](https://developer.apple.com/documentation/healthkit/hkheartbeatseriesquery)
- [Authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)

## Physical procedure

1. Install the updated app, detach the debugger, and launch from the Watch. Finish any pending session. Keep an independent alarm for real wake requirements.
2. Record Watch model, watchOS, app build, time zone, and whether the preceding 24 hours include an overnight period. Record relevant collection conditions you know; leave others unrecorded.
3. Open Cardiac history and request read access as intended. Record each type's outcome separately: records, empty, error, or unavailable. Check truncation and skipped-record warnings. Keep personal records and screenshots outside Git.
4. For each readable type, privately inspect several records and their sources, start/end, values, and counts. Compare the same records with available Apple Health details. Do not compare a combined Health dashboard count with a source-specific count without checking filters and dates.
5. Inspect heart-rate spans around the overnight period. Record whether grouped quantities exist and whether their spans explain apparent spacing. For series, record whether any series are readable; do not claim beat continuity from the beat count alone.
6. Read the source gap summaries and inspect representative boundaries. Include a source with one record or overlapping spans if available. Note that the gap calculation includes the window edges and does not establish true sensing coverage.
7. Refresh and confirm replacement rather than duplication. Expand/hide records; then leave and return, confirming that another read is required. Repeat backgrounding. Where practical, leave during a pending query and confirm late callbacks do not repopulate the screen.
8. Check scrolling, long source identifiers, dates, Show/Hide controls, and error/truncation messages on the Watch. Record any UI defect separately from data availability.

## Decision criteria

- **Historical availability demonstrated per type:** readable records retain intelligible dates, sources, values/counts; sampled comparisons and boundaries are explainable; refresh and clear behavior work. State access/device conditions and all partial-result limits. A type with no records remains inconclusive even if another succeeds.
- **Availability inconclusive:** empty records, errors, unexplained discrepancies, or missing observations prevent a conclusion. Identify the next specific check. Do not infer permission status from emptiness.
- **Software defect:** incorrect units/counts/dates/source attribution, gaps calculated across sources, unmarked truncation, duplicate refresh rows, or stale results after clearing. Fix and repeat the affected checks.

None of these outcomes establishes signal suitability for sleep staging or a live alarm. If grouped quantities or beat series are available, propose their internal timing/gap inspection separately. Overnight recording is outside this cardiac reader's scope; the separate [Experiment 006](006-overnight-motion.md) implements that investigation.

## Software verification

Verified on 2026-10-06:

- `./scripts/check-cardiac-history.sh` passed: source-specific gap merging, overlap/window boundaries, grouped quantities, unit conversion requests, all result caps, per-type errors and partial completion, invalid records, read-only authorization, cancellation, and late authorization/query callbacks.
- Existing background-motion and sleep-history synthetic suites passed.
- Signing-free Debug builds passed for generic watchOS and watchOS Simulator with Xcode 27 and the existing watchOS 26.6 minimum. Only the skipped AppIntents metadata-extraction warning was reported.
- Project/permission property lists, local documentation links, and whitespace checks passed.
- Codex has not independently verified interactive Cardiac history navigation, large-text layout, VoiceOver, permission UI, or physical availability. The owner subsequently reported an overall experiment pass. No real HealthKit records were used in these software checks.

The synthetic suite compiles the actual reader and summary calculations against platform doubles. Builds establish SDK integration; neither establishes device delivery or continuous measurement.

## Result

On 2026-10-06, the owner reported: “experiment 5 has succeeded all tests passed.” Record this as an **owner-reported experiment pass under the tested conditions**. The statement establishes the reported overall result; it does not supply individual data-type observations or captured measurements.

| Observation | Recorded evidence |
| --- | --- |
| Cardiac physical trial performed | Owner reports Experiment 005 succeeded. |
| Overall procedure/check outcome | Owner reports all tests passed. |
| Readable heart-rate and SDNN results | **Unknown** individually; no per-type observations supplied. |
| Grouped heart-rate records with quantity count greater than one | **Unknown**. |
| Readable heartbeat series | **Unknown**. |
| Counts, source spans/gaps, units, dates, and Health comparisons | Exact observations **Unknown**. |
| Errors, invalid-record/truncation warnings, refresh, and clearing | All checks reported passed; individual observations **Unknown**. |
| Watch model, watchOS, build, time zone, settings, and trial times | **Unknown**. October 6 is the report date, not a captured trial timestamp. |
| Independent inspection of physical records | Not performed by Codex. |

Preserve the reported pass without inventing counts, settings, or per-type availability. Type-specific availability cannot yet be classified from captured observations; grouped-quantity and heartbeat-series presence still require a nonpersonal confirmation to decide the next timing reader. No personal values or raw records need to enter Git. This result does not establish continuous overnight cardiac sensing, timely alarm inputs, or sleep-stage accuracy.

### Conditional internal-timing follow-up

- If grouped heart-rate records are confirmed, consider a focused quantity-series reader to inspect contained value timestamps, boundaries, and gaps. A grouped count alone does not establish continuous sensing.
- If heartbeat series are confirmed, consider a focused beat-timing reader that preserves gap flags and excludes intervals crossing missing beats.
- If neither appears in the observed window, do not add either reader solely because the API exists. Record the window and sources. Broader inspection needs a specific reason, such as a known source or night expected to contain series.
- Earlier documentation deferred implementation while historical outcomes were unknown. Build 6 now provides a runtime-gated [focused inspector](007-cardiac-internal-timing.md): no query/action appears unless a fresh read observes an eligible record. The historical outcomes remain unknown, and physical behavior is untested.

[Experiment 006](006-overnight-motion.md) has a recording screen and bounded timing/battery diagnostics. The original pilot retains leading-gap and ordering failures with early visibility unknown. The inspected October 8 build-6 pilot meets early visibility but still has five date-only ordering failures; build 8 adds bounded diagnostic detail, with physical results unrecorded. The inspected eight-hour comparison is inconclusive because charging/interruption and timing uncertainty prevent a valid battery baseline. Overnight feasibility is unresolved, independently of the reported cardiac procedure pass.

## Learning exercise

One heart-rate record spans five minutes and has a quantity count of ten. Explain why counting it as one instantaneous sample underestimates the stored quantities, and why treating its whole span as continuous measurement also overstates what this screen establishes. Then distinguish that count from a heartbeat-series beat count and an SDNN value.
