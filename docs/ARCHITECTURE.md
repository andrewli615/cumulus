# Architecture options

Architecture follows the desired experience and observed OS behavior. For the first feasibility slice, keep the implementation in the standard watch-only Xcode app target; do not create modules or a companion app.

## System boundary

- Which actions must work with the iPhone disconnected?
- Where is the next wake time stored?
- Which component owns the truth about a scheduled session?
- Which data, if any, must be retained after waking?

## Compare two starting options

| Option | Strength | Risk to investigate |
| --- | --- | --- |
| Watch-only | Short path to a wrist-first experience | Scheduling, cancellation, and backup behavior |
| Watch plus iPhone companion | More room for configuration and possible separate alarm | Synchronization and duplicate alerts |

## Separate concerns when code begins

- **Time and decision rules:** deterministic, independently testable.
- **Platform integration:** watchOS session, sensors, haptics, and lifecycle.
- **Experience:** a small number of clear UI states.
- **Diagnostics:** events sufficient to explain a missed or late alert, with minimal personal data.

## Feasibility slice boundary

- **Screen:** one screen schedules a test alert a few minutes ahead, shows the latest known session state and timestamp, and offers cancellation while the app is active.
- **Session coordinator:** owns the `WKExtendedRuntimeSession`, sets its delegate before scheduling, receives the scheduled session through the WatchKit extension delegate on relaunch, and sends `notifyUser` only after the session is running.
- **State and diagnostics:** persist only the scheduled fire date and a short, bounded event history (requested, session started, haptic requested, expired, invalidated, error, canceled). Put timestamps in records so a process restart does not erase the experiment evidence. Never infer “alert delivered” from calling the haptic API.
- **View:** renders a plain-language state from the coordinator and invokes schedule/cancel actions; it does not own WatchKit session details. Keep the single screen glanceable, use system text styles so text can scale, and expose the state and actions clearly to VoiceOver, following [Apple's public watchOS design guidance](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos).

This boundary is an implementation proposal for the experiment. The session callbacks and haptic API are documented; relaunch timing, cancellation timing and actual haptic delivery must be observed on a physical Watch.

Do not create these as folders yet. First draw the state transitions in `BEHAVIOR.md`, then record a concrete boundary decision in `decisions/`.
