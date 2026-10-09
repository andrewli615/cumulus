# Experiment log

Each note is the authoritative record of its procedure, observations, and limitations. Numbers are identifiers, not a required execution order. Simulator observations do not establish physical Watch alarm behavior.

| Experiment | Implementation | Evidence / remaining work |
| --- | --- | --- |
| [001: Scheduled alert](001-scheduled-alert.md) | Implemented | Original mixed results preserved; later owner-reported pass after changing haptics. Supported for tested conditions by report; overnight reliability unestablished. |
| [002: Live data](002-live-data.md) | Foreground probe implemented | One owner-reported motion run; heart freshness remains unresolved. Background evidence belongs to 003. |
| [003: Background motion](003-background-motion.md) | Implemented | Owner reports two short background trials and manual-stop check passed. Exact summaries were not independently inspected. |
| [004: Stored sleep records](004-sleep-stage-feasibility.md) | Reader and screen implemented | Owner reports procedure completion; readable records, comparisons, clearing, errors, and device details unknown. |
| [005: Cardiac-data coverage](005-cardiac-data-coverage.md) | Reader and screen implemented | Owner reports success and all tests passed; individual observations unknown. Internal timing remains conditional on grouped quantities/series. |
| [006: Overnight motion](006-overnight-motion.md) | Implemented; paused for fixed-alarm MVP | Original pilot failures are preserved. The inspected October 8 build-6 pilot has 59,757 samples and timely block visibility; five date-only anomalies are its sole full-window timing failure. The charged comparison remains inconclusive. Build-8 read-back reproduces five within-query backward-date failures; a fresh build-8 recording reproduces four backward-date failures and flags trial clock uncertainty; the inspected build-9 pilot has no clock uncertainty but twenty backward-date failures and an incomplete fixed block. The first build-12 pilot passes timing with late visibility. The subsequent pilot has 59,758 samples and 40/40 buckets but fails the two-second gap limit (2.001904 s); its only block read was at minute 19:40. The repeat full-window read reproduces the identical gap and counts. The build-14 re-read of the subsequent pilot recovers 99 samples and passes timing (59,857 samples, 40/40 buckets, 0.020021 s gap). Neither pilot qualifies; early visibility and overnight feasibility remain unresolved. |
| [007: Cardiac internal timing](007-cardiac-internal-timing.md) | Conditional inspector implemented | Offered only for an eligible record observed by a fresh read; physical availability/behavior untested. |
| [008: Fixed-alarm acceptance](008-fixed-alarm.md) | Product flow implemented and software checked | Short/overnight delivery, battery, recovery, accessibility and physical clearing pending. |

Next: run [008: Fixed-alarm acceptance](008-fixed-alarm.md) on build 18. Product code and software checks are complete; short delivery/edit/cancel/recovery, two overnight deliveries, battery, physical accessibility and independent history clearing remain pending. Experiment 006 is paused with original results/criteria preserved; it is not passed and its fresh pilot is deferred. Keep an independent alarm and raw exports outside Git.


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
