# Experiment log

Each note is the authoritative record of its procedure, observations, and limitations. Numbers are identifiers, not a required execution order. Simulator observations do not establish physical Watch alarm behavior.

| Experiment | Implementation | Evidence / remaining work |
| --- | --- | --- |
| [001: Scheduled alert](001-scheduled-alert.md) | Implemented | Original mixed results preserved; later owner-reported pass after changing haptics. Supported for tested conditions by report; overnight reliability unestablished. |
| [002: Live data](002-live-data.md) | Foreground probe and in-memory movement features implemented | Build-21 optional saved windows and review/export implemented; synthetic checks pass, physical capture/storage behavior untested. One earlier owner-reported motion run; heart freshness unresolved. Background evidence belongs to 003. |
| [003: Background motion](003-background-motion.md) | Implemented | Owner reports two short background trials and manual-stop check passed. Exact summaries were not independently inspected. |
| [004: Stored sleep records](004-sleep-stage-feasibility.md) | Reader and screen implemented | Owner reports procedure completion; readable records, comparisons, clearing, errors, and device details unknown. |
| [005: Cardiac-data coverage](005-cardiac-data-coverage.md) | Reader and screen implemented | Owner reports success and all tests passed; individual observations unknown. Internal timing remains conditional on grouped quantities/series. |
| [006: Overnight motion](006-overnight-motion.md) | Implemented; paused for fixed-alarm MVP | Original pilot failures are preserved. The inspected October 8 build-6 pilot has 59,757 samples and timely block visibility; five date-only anomalies are its sole full-window timing failure. The charged comparison remains inconclusive. Build-8 read-back reproduces five within-query backward-date failures; a fresh build-8 recording reproduces four backward-date failures and flags trial clock uncertainty; the inspected build-9 pilot has no clock uncertainty but twenty backward-date failures and an incomplete fixed block. The first build-12 pilot passes timing with late visibility. The subsequent pilot has 59,758 samples and 40/40 buckets but fails the two-second gap limit (2.001904 s); its only block read was at minute 19:40. The repeat full-window read reproduces the identical gap and counts. The build-14 re-read of the subsequent pilot recovers 99 samples and passes timing (59,857 samples, 40/40 buckets, 0.020021 s gap). Neither pilot qualifies; early visibility and overnight feasibility remain unresolved. |
| [007: Cardiac internal timing](007-cardiac-internal-timing.md) | Conditional inspector implemented | Offered only for an eligible record observed by a fresh read; physical availability/behavior untested. |
| [008: Fixed-alarm acceptance](008-fixed-alarm.md) | Product flow implemented; overnight validation deferred | Ten configurations across preserved snapshots: seven haptic requests, two edit transitions, standalone cancellation and session attachment, without recorded errors. Cancellation passed by owner confirmation; one overnight run performed by owner report, with its qualification incomplete. Two qualifying nights and remaining edit/perception, recovery UI/process and usability pending. |

Next: use [build 21's optional saved movement windows](002-live-data.md#optional-saved-movement-windows--build-21-october-15) in Research → Motion probe for a short awake comparison, then review/export its Saved tests report. Saving is off by default; duration/rows and retention/deletion are bounded. No classifier or overnight-input qualification is inferred. Alarm validation stays deferred and Experiment 006 unresolved; the October 15 additional-run report below retains its unknowns.


## Additional overnight report — October 15

**Owner report:** "I ran another overnight experiment." The experiment type (fixed alarm versus motion recorder), trial date/build, alert perception, timing, battery, charging and errors were not specified. Keep this as an **additional reported run, outcome unclassified**; do not assign it to Experiment 006 or 008 or count a qualifying night without evidence. This report does not establish completion of the separate foreground-feature walkthrough.

**Read-only inspection:** the research archive was retrieved and preserved privately: nine readable reports (one alert, one background and seven overnight-mode reports). The seven consist of six older pilots and the earlier nonrecording comparison; their recorded starts are October 6–8 and latest capture dates October 14. There is no saved eight-hour recording report or build-20 feature report in this export. That is an archive observation, not proof the reported run did not happen; foreground features are not persisted by build 20. The separate fixed-alarm file and current installed-app metadata could not be read because device services failed, including developer disk-image metadata and connection errors. Those are retrieval failures, not demonstrated alarm or sensor errors during the run. Exact records and device diagnostics remain outside Git. No app was installed, launched, scheduled or asked to collect data during inspection.

**Direction:** continue [build 20's foreground feature work](002-live-data.md#foreground-movement-features--build-20-october-14), then define intended-state signal coverage/availability and private retention/deletion before extending capture or choosing a model. Fixed-alarm validation stays deferred and Experiment 006 unresolved; existing results and criteria are unchanged. Preserve and identify the newly reported run when its history is readable; this review does not call for an automatic repeat overnight trial.


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
