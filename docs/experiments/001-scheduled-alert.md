# Experiment 001: Scheduled Watch alert feasibility

Date drafted: 2026-09-26  
Device / OS / Xcode: record before each run; not available in this environment  
Implementation: pending Xcode and physical Watch

## Hypothesis

If Cumulus schedules a WatchKit smart alarm extended runtime session while the Watch app is active, then the session will begin near its requested time after the wearer lowers their wrist or leaves the app, and a haptic requested during that running session will be perceptible. The app will report only the state it can observe.

## Documented behavior

Apple documents that a smart alarm session can be scheduled with `start(at:)` up to 36 hours ahead while the app is active; only one such session can be scheduled; the session is background-capable and limited to 30 minutes; and the system can relaunch the app to handle a scheduled session. Apple documents calling `notifyUser(hapticType:repeatHandler:)` on a running schedulable session; if the app is inactive, the system also displays an alarm alert. These points describe the platform contract, not a measured result for Cumulus or a guarantee that a person will perceive the alert.

Sources: [Using extended runtime sessions](https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions), [notifyUser(hapticType:repeatHandler:)](https://developer.apple.com/documentation/watchkit/wkextendedruntimesession/notifyuser(haptictype:repeathandler:)).

## Procedure

Use a physical Apple Watch paired to an iPhone. Record Watch model, watchOS version, Cumulus build, Xcode version, battery percentage, and whether the Watch is on wrist. Keep a separate reliable alarm for any real wake requirement.

1. Install and open the watch-only Cumulus experiment app on the Watch. Confirm the screen says no session is scheduled.
2. Tap **Schedule test alert**. The app should schedule a smart alarm session for three minutes ahead. Record the displayed requested time and the time the tap was made.
3. Confirm the screen reports **Session scheduled** only after the scheduling call succeeds. Record any immediate error. Do not count this state as proof of the future alert.
4. Immediately lower your wrist, then leave Cumulus (press the Digital Crown) and do not reopen it before the requested start time.
5. At the requested time, note whether you perceive haptic feedback and/or see the system alarm alert. Record the observed wall-clock time and whether Cumulus had to relaunch. Do not dismiss the alert until recording what is visible; then stop it using the available system/app action.
6. Reopen Cumulus and record its status and event timestamps. Check whether they include schedule request, session start, haptic request, and invalidation/expiry. Note any gap or mismatch.
7. Repeat steps 1–6 three times. On one run, leave the app via the Digital Crown; on another, leave it in the background by opening another app. Do not change multiple conditions in a single run.
8. Cancellation check: schedule another test three minutes ahead, verify the scheduled state, return to Cumulus while it is active, tap **Cancel**, and confirm a cancellation/invalidation event is recorded. Wait past the requested time and note whether an alert nevertheless occurs.

## Observations to record

For every run, record:

- Run number, Watch model/watchOS, app build/Xcode, battery, wrist state, and exit method.
- Schedule tap timestamp, requested start timestamp, scheduling result, and any error details/code.
- Session start callback timestamp; app relaunch/activation timestamp if observable; haptic API call timestamp.
- Haptic perceived (yes/no/uncertain), system alert visible (yes/no), and alert first-observed timestamp.
- Cancel action timestamp and invalidation callback/reason, or expiry timestamp/reason.
- Final app status, event-log timestamps, and anything unexpected. Keep observed device behavior separate from the documented API behavior and inference.

## Pass / fail criteria

- **Supported for the tested conditions:** all three scheduled runs produce a session-start callback near the requested time, the app records a haptic request while the session is running, and the wearer perceives the alert or sees the documented system alarm presentation. Cancellation prevents the pending test alert in the cancellation check and is reflected in status. Report actual timing spread and limitations; this does not establish overnight reliability.
- **Contradicted:** a repeatable failure occurs under the stated setup, such as the scheduled session not starting, no haptic request being made despite a running session, or cancellation failing to stop a pending alert. Preserve logs and exact circumstances.
- **Inconclusive:** results vary, required lifecycle events cannot be observed, or alert perception cannot be determined. Repeat only after changing one recorded condition at a time.

Any simulator-only run is useful for build/UI checks but is not evidence for these criteria.

## Result

Pending physical Watch testing.

## Next step

Use the observed callback sequence and timing to decide whether to repeat with overnight/low-battery conditions or investigate another alert mechanism. Do not add motion sensing until this delivery path has been characterized.
