# Experiment 004: Inspect stored sleep-stage records

Status: reader and screen implemented; software checks passed; physical record availability and interactive UI checks pending.

## Question

Which sleep-analysis intervals can Cumulus read on the Watch, from which sources, and how do those individual records compare with the sleep history shown in Apple Health for the same dates?

This is reference-data inspection. It does not detect sleep, request new sensor measurements, validate Apple's stages, or establish timely availability for an alarm.

## Implemented behavior

Open **Sleep history** from the chooser and tap **Read / Refresh**. The app requests read access only to HealthKit sleep analysis, with no write types. It queries intervals overlapping the preceding seven calendar days ending at the tap time. It keeps original interval boundaries, including intervals crossing the query boundary, and sorts by start date, newest first.

Each row displays category, start/end date and time, source name, and source bundle identifier. Categories include In bed, Awake, Asleep (unspecified), Core, Deep, REM, and an explicit unknown-value fallback. Sources are not assumed to be Apple. Overlapping records remain separate; the app computes no sleep totals and fills no gaps with inferred stages.

The query requests up to 501 records to detect overflow, shows at most 500, and explicitly marks a truncated snapshot. The window and successful read time are visible. A completed snapshot does not observe later store updates: tap Refresh to query again. Times use the Watch's current time zone, identified on screen.

Records remain in memory. Leaving the screen or backgrounding the app cancels any query, clears displayed records, and invalidates outstanding results. A pending authorization request is allowed to finish, but cannot start a query after cancellation. Becoming inactive for a permission sheet does not itself clear the reader. Entry is disabled while a scheduled experiment owns a session.

Data flow: user action → read authorization → HealthKit snapshot query → value snapshots copied in the callback → MainActor UI. `SleepInterval` is outside the main-actor reader; the callback passes only its Sendable values to the UI task. A request identifier rejects late results after clearing or a later request.

Main risk: treating incomplete, overlapping, or delayed records as a live and complete sleep timeline. Alternative: inspect Health on the iPhone manually, which is simpler but does not establish which records the Watch app can read.

## Documented behavior and evidence limits

Apple represents sleep analysis as categorized intervals. In-bed intervals may overlap sleep stages, and detailed stage samples may not cover their entire beginning/end. Read authorization completion does not establish permission to read every requested type; empty results cannot distinguish denied access from absent readable records.

Sources: [Sleep categories](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis), [sample queries](https://developer.apple.com/documentation/healthkit/hksamplequery), [source revision](https://developer.apple.com/documentation/healthkit/hksourcerevision), [authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data). Reviewed using Context7 and official Apple documentation during this milestone's proposal.

Apple Health may combine or present records differently from this source-preserving interval list. A mismatch needs investigation of dates, sources, availability, and presentation; it is not automatically a Cumulus error or evidence of a false sleep stage. Apple's classifications are a comparison reference, not independent ground truth.

## Physical procedure

1. Finish any scheduled experiment. Install the updated app, stop debugging, and launch it from the Watch icon. Keep an independent alarm for real wake requirements.
2. Record Watch model, watchOS, app build, time zone, and whether Apple Health displays recent sleep data. Keep personal records and screenshots outside the repository.
3. Open Sleep history and tap Read / Refresh. Respond to the read-access request as intended. Record whether the result is readable intervals, empty, unavailable, or an explicit error. Do not interpret an empty result as confirmed denial.
4. For readable records, privately compare several intervals against the same dates and sources in Apple Health, including a night crossing midnight and any overlapping in-bed/stage intervals available. Record category, boundaries, source, query window, and read time. Note truncation and unknown category values rather than hiding them.
5. Refresh and confirm records are replaced rather than appended. Navigate away and return: the list should be cleared until another read. Repeat by backgrounding the app. Where practical, leave while a query is pending and verify old results do not reappear.
6. Inspect the screen on the Watch, especially long source identifiers, dates, scrolling, and error/truncation messages. Check navigation among all four destinations. Simulator layout checks may also help, but cannot establish physical HealthKit availability.
7. Record missing stages and discrepancies without inventing missing data. An optional later read can establish when a record was first observed by Cumulus; a single historical query cannot reveal its original availability time.

## Decision criteria

- **Readable reference data demonstrated:** actual intervals appear with intelligible categories, dates, and source attribution; sampled comparisons are explainable; refresh/clear behavior is correct; no unexpected persistence or writing occurs. State the device and access conditions and any truncation.
- **Availability inconclusive:** no readable records, unexplained source/date discrepancies, errors, or incomplete observations prevent that conclusion. Identify one next check rather than assuming permission denial or no sleep.
- **Software defect:** displayed categories/dates/sources disagree with the queried records, stale requests repopulate cleared state, refresh duplicates records, or the UI incorrectly claims live sensing or complete coverage. Fix and retest the affected behavior.

No outcome establishes sleep-stage accuracy or suitability for a live alarm. After this inspection, propose cardiac/other record coverage work separately. Overnight motion and algorithm evaluation remain later reviewed chunks in [the research roadmap](../SLEEP_RESEARCH_ROADMAP.md).

## Software verification

- Signing-free Debug builds passed for generic watchOS and watchOS Simulator with Xcode 27 and the existing watchOS 26.6 minimum. Only the skipped AppIntents metadata-extraction warning was reported.
- A temporary macOS harness compiled the actual reader against synthetic HealthKit doubles. It checked read-only authorization, unavailable/empty/error states, every category and unknown fallback, source/date preservation, truncation, query cancellation, and late authorization/query callbacks. The harness is outside the repository at `/tmp/cumulus-sleep-checks`; it contains no personal records and is not a permanent test target.
- Interactive navigation/layout remains unverified; Computer Use permission was unavailable during this project. No physical sleep records were queried in these software checks.

## Result

Pending owner-run physical inspection. No sleep records, screenshots, or raw device logs are stored here. Experiments 001 and 003 retain their existing owner-reported results and evidence limits.

## Learning exercise

If an In bed interval overlaps a Core interval from another source, explain why adding their durations would overcount sleep. Then explain why the time Cumulus reads an interval is not necessarily the time it first became available.
