# Experiment log

Each note is the authoritative record of its procedure, observations, and limitations. Numbers are identifiers, not a required execution order. Simulator observations do not establish physical Watch alarm behavior.

| Experiment | Implementation | Evidence / remaining work |
| --- | --- | --- |
| [001: Scheduled alert](001-scheduled-alert.md) | Implemented | Original mixed results preserved; later owner-reported pass after changing haptics. Supported for tested conditions by report; overnight reliability unestablished. |
| [002: Live data](002-live-data.md) | Foreground probe implemented | One owner-reported motion run; heart freshness remains unresolved. Background evidence belongs to 003. |
| [003: Background motion](003-background-motion.md) | Implemented | Owner reports two short background trials and manual-stop check passed. Exact summaries were not independently inspected. |
| [004: Stored sleep records](004-sleep-stage-feasibility.md) | Reader and screen implemented | Owner reports procedure completion; readable records, comparisons, clearing, errors, and device details unknown. |
| [005: Cardiac-data coverage](005-cardiac-data-coverage.md) | Reader and screen implemented | Physical outcomes, grouped quantities, and heartbeat-series availability unknown; internal timing work deferred. |
| [006: Overnight motion](006-overnight-motion.md) | Plan only; no recorder in the app | Availability pilot, two eight-hour trials, and battery comparison specified; no device result. |

Next: supply nonpersonal 004/005 observations and review the 006 plan before proposing its implementation; follow subsequent work in [the research roadmap](../SLEEP_RESEARCH_ROADMAP.md). Keep an independent alarm during development. Record only nonpersonal outcome summaries here; keep HealthKit records, screenshots, and raw device logs outside Git.

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
