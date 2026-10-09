# Experiment 008: Fixed-alarm MVP acceptance

Status: build **0.1 (19)** implemented and software-verified on October 9. **Physical trials pending.** No installation, alarm scheduling, haptic perception or battery outcome on the physical Watch is claimed by this milestone. Experiment 006 remains paused and unresolved; its results and criteria are unchanged.

## Question and limits

Can the integrated, Watch-only fixed alarm schedule one absolute time, request a haptic, support edit/cancel/stop and recover truthfully under the owner's tested conditions? This version has no sensor collection, HealthKit query, early-wake rule, snooze or repeating schedule. It does not promise a wake deadline or reduced sleep inertia. Keep an independent alarm for any real wake requirement.

**Documented platform behavior:** [Apple's runtime guide](https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions) permits one smart-alarm session at a time, scheduled within the next 36 hours while the app is active. The scheduled session has a 30-minute runtime limit, not an eight-hour runtime. The system can relaunch the app and deliver its session; the app must attach the delegate. [notifyUser](https://developer.apple.com/documentation/watchkit/wkextendedruntimesession/notifyuser%28haptictype%3Arepeathandler%3A%29) requires a running scheduled session and uses a three-second default repeat interval. Scheduled sessions can be invalidated only while the app is active. Context7 and official Apple documentation were checked on October 9. These are API behaviors, not device outcomes.

**Implementation:** the session starts at the selected fixed alarm time and requests the notification haptic. It is not kept running overnight. Configuration and the latest 40 lifecycle events are stored separately from research reports. A saved pending request is Unverified until a session is attached. Edits cancel first and replace only after confirmed non-error invalidation; replacement failure is visible and does not restore the old alarm. Recovery never re-arms automatically. A previously saved haptic request is not repeated on a recovered session; process failure between a platform call and its disk write is not an atomic transaction and cannot establish exactly-once physical delivery.

## Prewritten physical procedure

1. Preserve outstanding Research requests and saved reports. Finish any active/reserved Research session before scheduling an alarm. Install build 19 through Xcode without deleting Cumulus or clearing app data. Stop the Xcode run, then open Cumulus from the Watch icon. An app update does not qualify old alarm tests for the new build.
2. Record Watch model, watchOS, app build, local time zone, haptic/sound settings, Sleep Focus, Low Power Mode, wrist/unlocked state and any interruptions. Leave unrecorded details unknown. Use an independent backup distinguishable from Cumulus's alert; do not attribute the backup's alert to Cumulus.
3. **Short delivery:** set an alarm at least three minutes ahead. Review the full date/time zone and tap Schedule alarm. Confirm Scheduled; leave via the Digital Crown. At the requested time, record perceived haptic and visible system alert separately. Stop via the system Stop button or Cumulus's Stop alert. Inspect Alarm history for schedule state, start callback, haptic request and invalidation. A running-state observation is not a missing start callback.
4. **Edit:** schedule three minutes ahead, then change it to about six minutes ahead. Confirm the old time was cancelled before the replacement became Scheduled and that the home shows the replacement date. Leave the app. No Cumulus alert should occur at the old time or during the following minute; the replacement must request a haptic and produce a perceived alert. Stop it. If replacement fails, record that the old alarm ended and the new one is not set; do not treat saving the edit as success.
5. **Cancellation:** schedule three minutes ahead and cancel at least one minute before it. Confirm Cancelled after invalidation. Leave the app and wait until five minutes beyond the requested time. No Cumulus alert or haptic request for that cancelled alarm should occur.
6. **Recovery/status:** leave and reopen Cumulus during a pending short trial. If the process actually relaunches without a supplied session, expect Unverified rather than Scheduled. Do not schedule another request to bypass it. At delivery, record any Relaunch received session event. A mere return to the app does not establish process relaunch; mark it unknown unless recorded. Preserve errors and unexpected ownership outcomes.
7. **Two separate overnight deliveries:** use the current build, intended Sleep Focus/haptic settings and detached debugger. Schedule the one-time morning alarm, record start battery/time before leaving, then wear the Watch without charging. On one night, open another ordinary app after leaving Cumulus; record which app. Do not run research experiments during either night. Record perception and stop result, then return battery/time promptly, before browsing history. Preserve missing observations, charging, power-off/reboot or other interruptions rather than inferring success.
8. **Usability/deletion:** check normal and larger text, hour/minute selection and return, full date confirmation, Crown scrolling, edit/cancel/stop and VoiceOver. Essential states/actions must be understandable; the cloud must not be announced. Once no alarm or research session is pending, clear Alarm history and verify it stays empty after reopening while Saved tests are preserved. Clearing Saved tests must not clear alarm history.

## Acceptance criteria

- Short delivery and replacement each produce a perceived Cumulus haptic or visible Cumulus system alert, with truthful scheduling and stop states. The old edited time and cancelled time produce no alert. Cancellation/edit history agrees with the observed result.
- Both overnight haptic requests occur **0–60 seconds after** their requested time, and an alert is perceived. No unexplained duplicate alerts, automatic re-arm, missing callback/error concealed as success or recovery state mislabeled Scheduled.
- Each overnight wear interval has **no charging**, battery loss **at most 25 percentage points**, and **at least 20%** remaining on return. Report actual duration; substantially different/missing start/end observations or interruptions make battery evidence inconclusive. No separate recorder comparison night is required for this fixed-alarm version.
- Normal/larger text, scrolling, choice/return and VoiceOver checks pass without clipped essential controls or inaccessible actions. Completed alarm history deletion works independently of research data and cannot clear a pending request.
- Passing supports the fixed alarm **only under the recorded conditions**. A failed adequately observed dimension is contradicted; missing perception, late/missing observations, configuration or unresolved errors are inconclusive. Do not substitute software requests for physical delivery or awakening.

## Private evaluation

Alarm history keeps at most 40 events across the latest configurations; retrieve it before later runs displace earlier events. It excludes health samples and motion vectors, but timing metadata remains private. Keep raw exports, screenshots and device logs outside Git. App history deletion does not remove exported copies.

Use a new private directory:

```sh
python3 scripts/retrieve-test-archive.py --alarm-only --output /tmp/cumulus-private-alarm-trial
```

The read-only tool copies `Library/Application Support/Cumulus/Alarm/record.json`, verifies its bounded structure and emits `alarm-evaluation.json`. It does not launch Cumulus, attach a debugger or schedule an alarm. Dates use Foundation's default seconds from **2001-01-01 UTC**, explicitly distinct from the research archive's Unix date encoding. The evaluation reports haptic-request offsets per alarm; it cannot confirm perception, wearing, battery or clock accuracy. Exact schema validation remains the Swift model's responsibility.

## Software checks and result

- All seven suites passed on build 17; build 18 repeats the alarm suite after the visual-only change: alarm, background motion/shared delegate, overnight motion, sleep history, cardiac history, cardiac timing, and saved archive. The Python retrieval checks cover the separate alarm record, fractional request offsets, date encoding, bounds and malformed input.
- Signing-free Debug builds pass for generic Watch and Watch Simulator with Xcode 27; both report build 19. Project parsing, whitespace and local documentation links pass.
- Eight build-16 initial-viewport screenshots on an isolated 40 mm simulator cover synthetic home, setup, unverified and history at `.large` and `.xxxLarge`. An oversized heading and wrapping history title were corrected. Interactive selection/return, lower-page confirmation, scrolling, VoiceOver and physical layout remain unverified. Simulator rendering is not alarm evidence.
- **Physical result: pending.** No integrated short/overnight trial, perceived alert, battery result or physical deletion check has been supplied for build 19.

Learning exercise: identify the evidence behind Saved, Scheduled, Haptic requested and Perceived alert. Explain why only the last requires an observation from the wearer.

## Debug review — build 17, October 9

A synthetic process-relaunch test reproduced a lost-edit explanation: the old alarm's cancellation was recovered, but the replacement existed only in memory, so its loss was not reported. Build 17 persists an optional pending replacement date (older records without it still decode), displays the interrupted-edit failure, resumes the old cancellation only when permitted, and never automatically schedules the lost replacement after relaunch. Confirmed completion clears the pending replacement metadata. This does not make the WatchKit call and file write atomic.

The coordinator also checks the session's current state before edit/cancel/stop, rather than trusting a stale UI flag; a session that already ended cannot receive another invalidation request. A WatchKit error without supplied error details now has a visible explanation and a saved event. Additional synthetic checks cover these paths and cancellation while storage is failing. The private evaluation tool validates pending replacement dates. All seven suites, four Python retrieval tests, signing-free Watch/Simulator Debug builds, project parsing and whitespace checks pass. No sensor or HealthKit behavior changed.

Physical delivery, overnight battery, interactive UI/VoiceOver and process-relaunch behavior remain pending for build 19. No device alarm was requested during this review. Use the procedure above on the current build; earlier screenshots are layout evidence only.

Build 18 adds only the SVG cloud assets, license resource and visual layout changes documented in [the experience note](../EXPERIENCE.md#cloud-identity-and-visual-pass--build-18-october-9). Scheduling/recovery implementation is unchanged; physical acceptance must use the current installed build.

Build 19 adds an original nightcap to the SVG artwork and preserves its full colors in the decorative heading. Watch/Simulator builds and the alarm suite pass; scheduling and research code are unchanged. Physical acceptance is still pending on the current build.
