# Current architecture and open decisions

Cumulus uses one native watch-only SwiftUI target. Four experiments share a chooser; there is no companion app, sleep-stage model, or production wake-decision rule. Xcode navigator groups organize responsibilities without moving source files or adding modules.

## Ownership and data flow

| Boundary | Current implementation |
| --- | --- |
| App lifetime | `CumulusApp` installs `WatchAppDelegate`, which owns both scheduled coordinators and `ExperimentSessionOwner`. |
| Navigation | `ExperimentChooserView` exposes all four screens. Pending or unresolved session ownership disables the foreground probe and sleep-history entry. |
| Foreground measurement | `ContentView` owns `MotionMonitor` and `HeartRateReader`. Core Motion callbacks copy numeric values before MainActor display updates. HealthKit queries read stored heart records with their age. Leaving the screen or backgrounding stops the probe. |
| Scheduled alert | Screen action → `ScheduledAlertCoordinator` → WatchKit session → lifecycle callbacks → diagnostic history and UI state. The coordinator outlives the screen. |
| Background motion | Screen setup → `BackgroundMotionCoordinator` → running session → dedicated motion queue → locked accumulator → bounded summaries and UI. `BackgroundMotionTrial` holds sample timing/count calculations. The 60-second collection stops before requesting a haptic. |
| Sleep history | Read / Refresh → `SleepStageReader` → read authorization → snapshot query → Sendable interval values → MainActor UI. Request identity rejects late results after clearing; no query survives screen exit or background entry as an active reader request. |

Session callbacks hand off identity and event details to MainActor. Old-session callbacks are ignored. Collection stopping and session invalidation are separate events; stopping samples does not itself prove that a session has ended.

## Session ownership and relaunch

`ExperimentSessionOwner` records which scheduled experiment owns the single session. Coordinators claim ownership before scheduling and release it after confirmed invalidation. `WatchAppDelegate` routes a delivered session to the matching coordinator and attaches its delegate. Conflicting, missing, or unreadable ownership evidence is treated conservatively as unresolved; the background coordinator can attach an unverified session without starting collection.

A saved pending request alone is not proof of a live scheduled session. It blocks another schedule until lifecycle evidence resolves it. An interrupted background measurement window is not silently restarted after relaunch.

## Storage boundaries

| Data | Retention |
| --- | --- |
| Foreground motion and heart readings | In-memory display state only. |
| Sleep intervals | In-memory snapshot, at most 500 displayed intervals; cleared on exit/background. |
| Alert diagnostics | Requested date, lifecycle bookkeeping, and latest 40 timestamped events in local UserDefaults. |
| Background diagnostics | Latest five trial summaries, twelve five-second buckets and at most 40 events per trial, plus lifecycle bookkeeping in local UserDefaults. No raw vectors. |
| Shared session owner | Local UserDefaults routing state; reconciled with coordinator evidence on launch. |

HealthKit records and raw device logs do not belong in Git. A future private recording feature requires its own retention and deletion design.

## Verification boundary

[The synthetic suites](../Tests/README.md) compile actual implementation files against platform doubles. They check calculations, bounded storage, ownership, and cancellation/error paths. Device and simulator builds check integration with the real SDK. Neither establishes sensor delivery, haptic perception, battery behavior, or overnight reliability. See [experiment records](experiments/README.md) for physical evidence and its limits.

## Open product decisions

- Which signals have sufficient overnight coverage and timely availability for a wake decision?
- What should happen when those signals are missing or stale?
- What evidence would justify an independent recording path or an iPhone companion?
- Which private data, if any, should be retained after waking?
- What waking benefit and alert reliability must be measured before release?

Keep these questions separate from the implemented experiments. Follow [the build plan](BUILD_PLAN.md) and record future choices in [decisions](decisions/README.md) when evidence supports them.
