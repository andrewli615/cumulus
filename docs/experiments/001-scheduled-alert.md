# Experiment 001: Scheduled Watch alert feasibility

Date drafted: 2026-09-26  
Device / OS / Xcode: record exact values before each run

Implementation: scheduled-alert screen and coordinator implemented; subsequent haptics-setting retest supported for the tested conditions, based on owner report. Original October 5 mixed results preserved below.

## Hypothesis

If Cumulus schedules a WatchKit smart alarm extended runtime session while the Watch app is active, then the session will begin near its requested time after the wearer lowers their wrist or leaves the app, and a haptic requested during that running session will be perceptible. The app will report only the state it can observe.

## Documented behavior

Apple documents that a smart alarm session can be scheduled with `start(at:)` up to 36 hours ahead while the app is active; only one such session can be scheduled; the session is background-capable and limited to 30 minutes; and the system can relaunch the app to handle a scheduled session. Apple documents calling `notifyUser(hapticType:repeatHandler:)` on a running schedulable session; if the app is inactive, the system also displays an alarm alert. These points describe the platform contract, not a measured result for Cumulus or a guarantee that a person will perceive the alert.

Sources: [Using extended runtime sessions](https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions), [notifyUser(hapticType:repeatHandler:)](https://developer.apple.com/documentation/watchkit/wkextendedruntimesession/notifyuser(haptictype:repeathandler:)).

## Procedure

Use a physical Apple Watch paired to an iPhone. Record Watch model, watchOS version, Cumulus build, Xcode version, battery percentage, and whether the Watch is on wrist. Keep a separate reliable alarm for any real wake requirement.

1. Install Cumulus on the physical Watch. Stop the Xcode debugging session, then launch Cumulus from its Watch app icon. Choose **Scheduled alert test**. Confirm there is no unresolved session before beginning. If it says **Unverified after relaunch**, do not treat that as canceled or schedule another trial; wait for WatchKit's delivered session and record the uncertainty.
2. Tap **Schedule test alert**. The app should schedule a smart alarm session for three minutes ahead. Record the displayed requested time and the time the tap was made.
3. Confirm the screen reports **Session scheduled** only when the session state is `.scheduled`. The scheduling method does not return a success result; errors can arrive through invalidation callbacks. Record the observed state and any error. Do not count this state as proof of the future alert.
4. Leave Cumulus by pressing the Digital Crown, lower your wrist, and do not reopen it before the requested start time. In the other-app condition, open another app before lowering your wrist instead.
5. At the requested time, note whether you perceive haptic feedback and/or see the system alarm alert. Record the observed wall-clock time and whether Cumulus had to relaunch. Do not dismiss the alert until recording what is visible; then stop it using the available system/app action.
6. Reopen Cumulus and record its status and event timestamps. Check whether they include schedule request, session start, haptic request, and invalidation/expiry. Note any gap or mismatch.
7. Repeat steps 1–6 three times. On one run, leave the app via the Digital Crown; on another, leave it in the background by opening another app. Do not change multiple conditions in a single run.
8. Cancellation check: schedule another test three minutes ahead, verify the scheduled state, return to Cumulus while it is active, tap **Cancel**, and confirm a cancellation/invalidation event is recorded. Wait past the requested time and note whether an alert nevertheless occurs.

While a session is running, the app's **Stop alert** action invalidates it. The system alert also provides its own Stop action. Do not run the motion probe during these trials; entry is disabled while an alert session is attached or unresolved.

## Implemented evidence and limitations

The screen displays the last 40 lifecycle events, newest first, with timestamps and the requested start associated with each event. Events cover scheduling request, observed scheduled state, start callback or observed running state, haptic request, relaunch delivery, cancel/stop request, will-expire, expiry, invalidation reason, and error domain/code. Copy observations to private notes before older events roll off; do not commit raw logs.

The default haptic is `.notification`, requested with `repeatHandler: nil` (Apple documents a three-second interval). The coordinator suppresses duplicate requests for an attached session and restores the saved request flag on recovery. A crash between calling the API and saving the flag remains an evidence gap; persistence is not an exactly-once delivery guarantee.

On reopening, a saved pending date alone produces **Unverified after relaunch**. The app cannot inspect or cancel an unattached session. It will not infer cancellation from a past deadline or a process restart. A will-expire callback is distinct from confirmed expiry in an invalidation callback. Cancellation is initially a request, not a confirmed outcome.

## Private trial worksheet

Keep this worksheet's filled values outside Git. Use one row for each of three alert runs and one cancellation run:

| Run / exit method | Requested time | Start callback time / offset | Haptic request time / offset | Perceived haptic / visible alert / observed time | Relaunch event | Cancel and invalidation times | Error / outcome |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 / Digital Crown | Pending | Pending | Pending | Pending | Pending | N/A | Pending |
| 2 / another app | Pending | Pending | Pending | Pending | Pending | N/A | Pending |
| 3 / recorded condition | Pending | Pending | Pending | Pending | Pending | N/A | Pending |
| Cancellation | Pending | Record if any | Record if any | Observe past requested time | Record if any | Pending | Pending |

Calculate each start/haptic offset as event timestamp minus requested timestamp. A recovered running-state observation is not a measured start callback; mark the original start time unknown if it was not recorded.

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

**2026-10-05 — Inconclusive (owner-reported physical Watch results)**

Three scheduled trials and one cancellation trial were completed.

- **Run 1:** A session-start callback and haptic-request event were recorded, but no haptic or system alert was observed. The owner later tapped **Stop alert**; invalidation reason was 0.
- **Run 2:** The Cumulus **Open / Stop** alert appeared, and the owner felt a haptic and heard sound. The owner stopped the alert; invalidation reason was 0.
- **Run 3:** The Cumulus **Open / Stop** alert appeared, and the owner felt a haptic. The owner stopped the alert.
- **Cancellation:** No alert appeared after cancellation. The app recorded **Cancellation requested** and **Session invalidated (reason 0)**.

Results were mixed and do not meet the three-run pass criteria. Watch model, watchOS version, battery level, and exact timing offsets were not recorded. Missing details are not inferred; no raw logs are included. These results do not establish reliable wake delivery.

### Subsequent retest after changing Watch haptics

**Supported for the tested conditions — owner-reported, not independently verified.** The owner reported changing the Watch's haptics setting and confirmed repeating all three scheduled alerts plus the cancellation trial, with all four passing. The three scheduled alerts worked, and no alert occurred after cancellation.

The exact haptics setting and its before/after values, retest date, device/setup details, lifecycle timestamps, and timing offsets were not supplied. Trial summaries were not independently inspected. Do not infer these details or claim that the setting change proves the cause of the earlier failure. No raw logs are included.

This records successful alert/cancellation behavior after the reported setting change. It does not independently verify every lifecycle/timing criterion or establish overnight reliability, perception under other settings, or a reliable wake deadline. The original mixed results above remain part of the evidence.

### Software verification, 2026-10-02

- The signing-free Debug build passed with Xcode 27.0 and the watchOS 27 simulator SDK, retaining a watchOS 26.6 minimum. The built app's `WKBackgroundModes` contains only `alarm`.
- The final build installed and launched on the 40 mm Apple Watch SE 3 simulator. Interactive navigation and visual layout checks remain pending because Computer Use permission was not granted; launch success does not establish either check.
- A temporary Swift harness exercised the actual coordinator source against fake WatchKit types. It passed active-only scheduling, delayed scheduled-state observation, the three-minute request, duplicate start handling, persisted haptic-request recovery, stop/invalidation, cancellation racing with start, stale-session callback rejection, expiry, errors, the 40-event bound, and unreadable-storage handling. This checks coordinator logic, not WatchKit behavior. Harness files are outside the repository in `/tmp` and are not a permanent test target.
- Project/permission property lists and whitespace checks passed. The build's App Intents metadata warning reflects the absence of an App Intents dependency.

Physical outcomes above distinguish the original October 5 inconclusive trials from the subsequent owner-reported successful retest after changing Watch haptics.

## Next step

Preserve both the original mixed results and the subsequent owner-reported pass with its setting-dependent conditions and evidence limits. Background measurement is recorded separately in [Experiment 003](003-background-motion.md). The next action is physical inspection of the implemented sleep-history reader in [Experiment 004](004-sleep-stage-feasibility.md); subsequent signal-coverage and model work follows [the research roadmap](../SLEEP_RESEARCH_ROADMAP.md). Neither short experiment establishes overnight alert reliability or a wake-deadline guarantee.
