# Experiment log

Each note is the authoritative record of its procedure, observations, and limitations. Numbers are identifiers, not a required execution order. Simulator observations do not establish physical Watch alarm behavior.

| Experiment | Implementation | Evidence / remaining work |
| --- | --- | --- |
| [001: Scheduled alert](001-scheduled-alert.md) | Implemented | Original mixed results preserved; later owner-reported pass after changing haptics. Supported for tested conditions by report; overnight reliability unestablished. |
| [002: Live data](002-live-data.md) | Foreground probe implemented | One owner-reported motion run; heart freshness remains unresolved. Background evidence belongs to 003. |
| [003: Background motion](003-background-motion.md) | Implemented | Owner reports two short background trials and manual-stop check passed. Exact summaries were not independently inspected. |
| [004: Stored sleep records](004-sleep-stage-feasibility.md) | Reader and screen implemented | Owner reports procedure completion; readable records, comparisons, clearing, errors, and device details unknown. |
| [005: Cardiac-data coverage](005-cardiac-data-coverage.md) | Reader and screen implemented | Owner reports success and all tests passed; individual observations unknown. Internal timing remains conditional on grouped quantities/series. |
| [006: Overnight motion](006-overnight-motion.md) | Recorder, retrieval, ordering diagnostics and build-9 continuous elapsed clock implemented | Original pilot failures are preserved. The inspected October 8 build-6 pilot has 59,757 samples and timely block visibility; five date-only anomalies are its sole full-window timing failure. The charged comparison remains inconclusive. Build-8 read-back reproduces five within-query backward-date failures; a fresh build-8 recording reproduces four backward-date failures and flags trial clock uncertainty; the inspected build-9 pilot has no clock uncertainty but twenty backward-date failures and an incomplete fixed block. Overnight qualification remains unresolved. |
| [007: Cardiac internal timing](007-cardiac-internal-timing.md) | Conditional inspector implemented | Offered only for an eligible record observed by a fresh read; physical availability/behavior untested. |

Next: pause physical trials after the build-9 pilot reproduces ordering failures without clock uncertainty. Investigate wall-date/sensor-time mapping and input timing requirements before another recording. Preserve saved reports and unchanged criteria; qualify a current-build pilot before the matching comparison and two recording nights. Keep missing nonpersonal 004/005 observations unknown; use the implemented 007 inspector only after a fresh read finds an eligible record. Follow subsequent work in [the research roadmap](../SLEEP_RESEARCH_ROADMAP.md). Keep an independent alarm during development. Record only nonpersonal outcome summaries here; keep HealthKit records, screenshots, and raw device logs outside Git.

Template:

```markdown
# Experiment: [question]
Date: [YYYY-MM-DD]
Device / OS / Xcode: [versions]

## Prediction
If I do [action], I expect [observable result].

## Procedure
1. ...
2. ...

## Observations
Requested time, timing offsets, status, battery, and error summaries.
State missing details explicitly; do not embed personal records or raw device logs.

## Conclusion
Supported | contradicted | inconclusive. State limitations.

## Next step
What should be tested or changed?
```
