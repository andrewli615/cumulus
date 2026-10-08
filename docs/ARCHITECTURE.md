# Current architecture and open decisions

Cumulus uses one native watch-only SwiftUI target. Six experiments share a chooser; there is no companion app, sleep-stage model, or production wake-decision rule. Xcode navigator groups organize responsibilities without moving source files or adding modules.

## Ownership and data flow

| Boundary | Current implementation |
| --- | --- |
| App lifetime | `CumulusApp` installs `WatchAppDelegate`, which owns the scheduled coordinators, overnight coordinator, `ExperimentSessionOwner`, and shared `TestArchiveStore`. |
| Navigation | `ExperimentChooserView` exposes six experiments and Saved tests. Pending or unresolved session ownership disables the foreground probe, sleep-history and cardiac-history entries. |
| Foreground measurement | `ContentView` owns `MotionMonitor` and `HeartRateReader`. Core Motion callbacks copy numeric values before MainActor display updates. HealthKit queries read stored heart records with their age. Leaving the screen or backgrounding stops the probe. |
| Scheduled alert | Screen action → `ScheduledAlertCoordinator` → WatchKit session → lifecycle callbacks → diagnostic history and UI state. The coordinator outlives the screen. |
| Background motion | Screen setup → `BackgroundMotionCoordinator` → running session → dedicated motion queue → locked accumulator → bounded summaries and UI. `BackgroundMotionTrial` holds sample timing/count calculations. The 60-second collection stops before requesting a haptic. |
| Sleep history | Read / Refresh → `SleepStageReader` → read authorization → snapshot query → Sendable interval values → MainActor UI. Request identity rejects late results after clearing; no query survives screen exit or background entry as an active reader request. |
| Cardiac history | Read-only per-type snapshots → source-specific coverage calculations → in-memory UI; clearing and request identity reject late results. |
| Conditional cardiac timing | Observed eligible record → explicit foreground inspector → finite HealthKit series descriptor → bounded aggregate timing and count diagnostics. Individual values, dates, offsets and HealthKit IDs remain in memory; no HRV or stage estimate. |
| Overnight motion | Explicit fixed-duration request → Apple system recorder → foreground ten-minute retrieval chunks on a serial worker → timing/quality summaries → MainActor UI and local metadata. No extended-runtime or workout session, haptic, or raw-vector storage. |

Session callbacks hand off identity and event details to MainActor. Old-session callbacks are ignored. Collection stopping and session invalidation are separate events; stopping samples does not itself prove that a session has ended.

## Session ownership and relaunch

`ExperimentSessionOwner` records which experiment reserves sensor/session work. Scheduled trials share one WatchKit session; overnight/comparison trials reserve their fixed windows without creating a session. Scheduled coordinators claim ownership before scheduling and release it after confirmed invalidation. `WatchAppDelegate` routes a delivered session to the matching coordinator and attaches its delegate. Conflicting, missing, or unreadable ownership evidence is treated conservatively as unresolved; the background coordinator can attach an unverified session without starting collection.

A saved pending request alone is not proof of a live scheduled session. It blocks another schedule until lifecycle evidence resolves it. An interrupted background measurement window is not silently restarted after relaunch.

Overnight requests save a provisional window before calling the recorder. On return, new trials store the call-entry sample window and a small optional preparation/return timing record. Ownership is reserved through the full duration after call return. Legacy trials retain their dates and unknown call timing. Recovery never re-arms; interrupted preparation remains uncertain. Clock/reboot changes before the final observation preserve uncertainty; only a verified elapsed reserved window or explicit owner acknowledgement releases the reservation. Later reboot checks do not rewrite completed observations, and a new clock-uncertain read cannot replace a completed summary or establish visibility. Acknowledgement does not resolve sample evidence. Corrupt saved metadata blocks requests. Retrieval cancellation is independent of the system request, which has no explicit stop API. A SwiftUI timeline refreshes time-gated display controls; coordinator actions independently validate current time and app state.

## Storage boundaries

| Data | Retention |
| --- | --- |
| Foreground motion and heart readings | In-memory display state only. |
| Sleep intervals | In-memory snapshot, at most 500 displayed intervals; cleared on exit/background. |
| Alert diagnostics | Requested date, lifecycle bookkeeping, and latest 40 timestamped events in local UserDefaults. |
| Background diagnostics | Latest five trial summaries, twelve five-second buckets and at most 40 events per trial, plus lifecycle bookkeeping in local UserDefaults. No raw vectors. |
| Cardiac records | In-memory snapshots only, with per-type limits and clearing on exit/background. |
| Overnight diagnostics | Three trials, up to 960 thirty-second buckets, 40 events and 40 compact read observations per trial; pilot evidence contains only trial ID/OS/build. Raw vectors are discarded; system-managed retention is separate. |
| Saved test reports | One JSON file per run in Application Support/Cumulus/TestArchive, at most 200 reports or 32 MB. Full bounded alert/background/overnight diagnostic snapshots and health-query/foreground counts and statuses; no individual HealthKit records or raw vectors. |
| Shared session owner | Local UserDefaults routing state; reconciled with coordinator evidence on launch. |

`TestReport` defines the report schema; `TestArchiveStore` performs bounded atomic file writes and imports existing retained session trials. `TestArchiveView` presents summaries and lifecycle events. Existing small UserDefaults histories remain recovery state; new per-run files preserve reports independently of those rolling histories. Already discarded readings and trimmed history cannot be reconstructed. The capture build/OS are separate from the original trial configuration. Save boundaries are lifecycle checkpoints and completed queries/retrievals, never individual sensor callbacks.

Files remain local until deletion or uninstall, with no automatic expiry, upload, or phone transfer. They are excluded from backup and use watchOS protection until first user authentication. The 200-report/32-MB ceiling refuses an overflowing write without evicting older reports; failures remain visible until inspection/reload. Unreadable files are preserved and count toward capacity. Each file is at most 512,000 bytes, including a diagnostic payload of at most 350,000 bytes. JSON dates use fractional Unix seconds; diagnostic snapshots are base64-encoded JSON, decoded by the private retrieval script. Summary lists omit the payload from memory.

Delete completed test data confirms removal and independently checks all coordinators for pending, unresolved, or retrieving work. It removes reports and completed recovery histories, including pilot qualification. A deletion watermark precedes file removal so older recovery records cannot be reimported after interrupted deletion. Deletion does not stop Apple's recorder or remove HealthKit records. Leaving history screens still clears individual records in memory without erasing completed diagnostic reports.

HealthKit records and raw device logs do not belong in Git. `scripts/retrieve-test-archive.py` copies reports through Xcode device tools to a new private directory outside any Git checkout and produces a decoded evaluation JSON; it does not launch the app or start a sensor/query. Private copies have independent retention: app deletion does not erase them. Actual sample delivery, locked-device access, on-Watch deletion/layout and battery overhead still require physical checks. Raw-value recording remains a separate feature requiring a retention/deletion design.

Foundation's [atomic write option](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/atomic), [file protection option](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/completefileprotectionuntilfirstuserauthentication), and [backup exclusion guidance](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup) were checked through Context7 and official Apple documentation. Atomic replacement does not establish recorder delivery or eliminate possible storage failure.

## Verification boundary

[The synthetic suites](../Tests/README.md) compile actual implementation files against platform doubles. They check calculations, bounded storage, ownership, and cancellation/error paths. Device and simulator builds check integration with the real SDK. Neither establishes sensor delivery, haptic perception, battery behavior, or overnight reliability. See [experiment records](experiments/README.md) for physical evidence and its limits.

## Open product decisions

- Which signals have sufficient overnight coverage and timely availability for a wake decision?
- What should happen when those signals are missing or stale?
- What evidence would justify an independent recording path or an iPhone companion?
- Which private data, if any, should be retained after waking?
- What waking benefit and alert reliability must be measured before release?

Keep these questions separate from the implemented experiments. Follow [the build plan](BUILD_PLAN.md) and record future choices in [decisions](decisions/README.md) when evidence supports them.

## Guided evidence inspection

`PilotGuide` computes manual targets from the recorded trial start; clock uncertainty removes its countdown. No timer fires a sensor/query or background notification. Existing controls remain explicit. `SavedReportAssessment` validates a typed archived overnight snapshot and presents failed criteria, late visibility, charging and unknown conditions without rewriting saved observations or declaring model readiness.

`CardiacTimingSelection` is an in-memory copy of an observed record's ID, declared count and boundaries. Cardiac history offers at most five recent eligible candidates and keeps selection navigation independent of the overview list so clearing the list does not erase a pushed inspector. `CardiacTimingReader` owns request identity, cancellation, 60-second timeout and partial checkpoints; `HealthKitCardiacTimingQuery` implements finite quantity/heartbeat descriptors scoped to that ID. A 20,000-entry cap and spacing rules preserve partial results and gaps. No individual HealthKit record or value is encoded in the saved timing report. See [Experiment 007](experiments/007-cardiac-internal-timing.md).

Archive readiness now requires no unresolved storage error, fewer than 200 report files, and at least 512,000 bytes of reserve before a new test. Backend checks cover session scheduling and history/timing reads as well as UI controls. This prevents predictable limit failures, not every possible I/O failure; unexpected failures remain explicit. Clearing completed data still refuses pending sessions and does not delete system-managed recordings or independent private copies.

`SimulatorPreviewScreen` provides synthetic initial-screen fixtures behind `DEBUG && targetEnvironment(simulator)` and the explicit `CUMULUS_UI_PREVIEW` environment variable. Optional `CUMULUS_UI_TEXT=larger` applies a SwiftUI text-size override for layout inspection because watchOS simctl does not support its global text-size command. This code and environment route are excluded from physical and Release builds. Fixtures cannot establish physical usability, sensor behavior, or successful deletion; the archive preview's deletion callback intentionally performs no deletion.
