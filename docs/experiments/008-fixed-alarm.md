# Experiment 008: Fixed-alarm MVP acceptance

Status: build **0.1 (19)** implemented and software-verified on October 9. On October 13, the owner reported one short alert and then additional runs. Private read-back now contains six configurations: four recorded haptic requests, two cancel-before-replacement transitions and normal invalidations, without recorded errors. The installed app was confirmed as 0.1 (19) at the initial short-trial read-back. **Overall physical acceptance remains pending.** Standalone cancellation, physical edit/perception observations, recovery, overnight delivery, battery and accessibility remain unresolved. Experiment 006 stays paused with its results and criteria unchanged.

## Question and limits

Can the integrated, Watch-only fixed alarm schedule one absolute time, request a haptic, support edit/cancel/stop and recover truthfully under the owner's tested conditions? This version has no sensor collection, HealthKit query, early-wake rule, snooze or repeating schedule. It does not promise a wake deadline or reduced sleep inertia. Keep an independent alarm for any real wake requirement.

**Documented platform behavior:** [Apple's runtime guide](https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions) permits one smart-alarm session at a time, scheduled within the next 36 hours while the app is active. The scheduled session has a 30-minute runtime limit, not an eight-hour runtime. The system can relaunch the app and deliver its session; the app must attach the delegate. [notifyUser](https://developer.apple.com/documentation/watchkit/wkextendedruntimesession/notifyuser%28haptictype%3Arepeathandler%3A%29) requires a running scheduled session and uses a three-second default repeat interval. Scheduled sessions can be invalidated only while the app is active. Context7 and official Apple documentation were checked on October 9. These are API behaviors, not device outcomes.

**Implementation:** the session starts at the selected fixed alarm time and requests the notification haptic. It is not kept running overnight. Configuration and the latest 40 lifecycle events are stored separately from research reports. A saved pending request is Unverified until a session is attached. Edits cancel first and replace only after confirmed non-error invalidation; replacement failure is visible and does not restore the old alarm. Recovery never re-arms automatically. A previously saved haptic request is not repeated on a recovered session; process failure between a platform call and its disk write is not an atomic transaction and cannot establish exactly-once physical delivery.

## Prewritten physical procedure

### Start here: short-test checklist

Keep an independent backup alarm. Use build **0.1 (19)**; do not delete Cumulus, clear its data or run Research experiments during validation. Complete any pending Research session first. If ownership is unresolved or a saved alarm is Unverified, preserve the state and history for inspection rather than trying another schedule.

1. In Xcode, open `Cumulus.xcodeproj`, select **Cumulus Watch App** and your paired Watch, then Run. A signing-free build is a compile check, not an installable device app; Xcode must sign this installation with the configured team. Preserve the existing bundle identifier so saved data stays in the same app container.
2. When installation is complete, press the square **Stop** button in Xcode. Open Cumulus directly from the Watch app icon. Keep the debugger detached for the trial. Record the observed OS/build and intended Focus/haptic settings; leave uncaptured values unknown.
3. Tap **Set alarm**, choose a time at least three minutes ahead, then scroll to **Confirm next occurrence**. Review the full date and time zone, tap **Schedule alarm**, and confirm **Scheduled** on the home screen. A request, saved time or Unverified status is not that confirmation.
4. Leave via the Digital Crown. Observe whether you feel a Cumulus haptic and whether its system alert appears. Stop the alert, then open **Alarm history**. Preserve schedule, session-start, haptic-request and invalidation events, including errors. Do not manually transcribe every event; the private export below can evaluate their timing.
5. Run the Edit and Cancellation trials in the full procedure below as separate tests. Preserve the original/replacement times and whether an alert appears at either time. Export after this short-test group, before later trials can displace its history. Resolve failed or unexplained short-test results before starting the overnight trials.
6. Continue with two separate overnight deliveries using the procedure and unchanged acceptance criteria below. Export after each night. Record battery on the Watch just before leaving Cumulus and promptly after stopping the alert, plus charging and interruptions. Missing observations remain unknown.

The app stores software events, not perceived haptics, settings or battery measurements. Keep those observations in a private worksheet outside Git. For each trial, record its label/date, requested time (original and replacement for edits), perceived haptic, visible Cumulus alert, stop result, errors/duplicates, conditions and start/end battery/time. Use **not run** for a trial you have not performed and **unknown** for a detail you missed. Export before clearing completed history; keep Saved tests intact. Physical clearing remains a separate final check, after preserving the relevant records.

### Full trial procedure

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
- **Physical result: partial.** One short alert is owner-reported; additional-run software delivery/stop/edit lifecycles are inspected below. Standalone cancellation and explicit perception/old-time silence observations are missing. No overnight delivery, battery result or physical deletion check is recorded; full acceptance remains pending.

Learning exercise: identify the evidence behind Saved, Scheduled, Haptic requested and Perceived alert. Explain why only the last requires an observation from the wearer.

## Debug review — build 17, October 9

A synthetic process-relaunch test reproduced a lost-edit explanation: the old alarm's cancellation was recovered, but the replacement existed only in memory, so its loss was not reported. Build 17 persists an optional pending replacement date (older records without it still decode), displays the interrupted-edit failure, resumes the old cancellation only when permitted, and never automatically schedules the lost replacement after relaunch. Confirmed completion clears the pending replacement metadata. This does not make the WatchKit call and file write atomic.

The coordinator also checks the session's current state before edit/cancel/stop, rather than trusting a stale UI flag; a session that already ended cannot receive another invalidation request. A WatchKit error without supplied error details now has a visible explanation and a saved event. Additional synthetic checks cover these paths and cancellation while storage is failing. The private evaluation tool validates pending replacement dates. All seven suites, four Python retrieval tests, signing-free Watch/Simulator Debug builds, project parsing and whitespace checks pass. No sensor or HealthKit behavior changed.

Physical delivery, overnight battery, interactive UI/VoiceOver and process-relaunch behavior remain pending for build 19. No device alarm was requested during this review. Use the procedure above on the current build; earlier screenshots are layout evidence only.

Build 18 adds only the SVG cloud assets, license resource and visual layout changes documented in [the experience note](../EXPERIENCE.md#cloud-identity-and-visual-pass--build-18-october-9). Scheduling/recovery implementation is unchanged; physical acceptance must use the current installed build.

Build 19 adds an original nightcap to the SVG artwork and preserves its full colors in the decorative heading. Watch/Simulator builds and the alarm suite pass; scheduling and research code are unchanged. Physical acceptance is still pending on the current build.

## Test preparation — October 13

Build 19 remains unchanged for the physical trials. Fresh signing-free Debug builds pass for generic Watch and Watch Simulator with Xcode 27; both compiled app bundles identify version 0.1 (19). The alarm suite, background/shared-delegate suite and four private retrieval tests pass. Project parsing, whitespace and local documentation links pass. These are readiness checks, not physical acceptance, signed installation or a new interactive simulator check.

The short-test checklist above is ready, and a blank private worksheet was prepared outside Git. No Watch was installed, launched, read or scheduled during this preparation. No trial observations, HealthKit records or raw device logs were added. Existing physical results and all acceptance thresholds are preserved. The next action is Xcode installation with the existing app identity, then the short delivery trial from the Watch icon with the debugger detached.

## Short-delivery report and inspection — October 13

**Owner report:** "the 3 minute alarm went off." This establishes an owner-reported alert; the specific haptic, sound or visible system-alert observation and stop method were not supplied.

**Inspected diagnostic summary:** read-only export from the paired Watch retrieved one alarm with five retained events. The installed Cumulus app was separately confirmed as **0.1 (19)** at read-back; the alarm record itself does not embed its recording build. An initial disconnected-device lookup failed; explicitly addressing the paired Watch succeeded without launching, reinstalling or scheduling Cumulus. Raw exports, identities and exact timestamps remain private outside Git.

| Observation | Relative to requested time |
| --- | --- |
| Schedule request | 178.08 seconds before |
| Scheduled state observed | 177.97 seconds before |
| Session-start callback | +2.03 seconds |
| Haptic request | +2.05 seconds |
| Session invalidation, reason 0 | +7.95 seconds |

The saved phase is `ended`; events are ordered, with one recorded haptic request and no recorded error. Reason 0 alone does not establish which stop action the owner used. The request lead is approximately three minutes, slightly below the suggested 180-second preparation interval. Settings, wearing, debugger attachment, battery, actual trial time zone, explicit stop behavior and absence of physical duplicates remain unknown. This supports the software path for one reported alert under incompletely recorded conditions; it does not complete the short-test group or qualify overnight reliability. No criteria changed.

**Next — separate edit and cancellation tests, keeping build 19 and an independent alarm:**

1. Open the alarm home and verify the previous alert has ended and **Set alarm** is available. If a session is active, stop it first; preserve an Unverified or unresolved state for inspection instead of bypassing it.
2. **Edit:** set a time about four minutes ahead to allow setup time. While it is Scheduled, tap **Edit time** and replace it with a time about seven minutes ahead from now, reviewing the full date. Confirm the replacement becomes Scheduled. Leave the app. No alert should occur at the original time or during its following minute; the replacement should alert. Stop it and preserve history. Record alert perception and stop result; callbacks can be checked from the export.
3. **Cancellation:** create a separate alarm about four minutes ahead; cancel with at least one minute remaining. Confirm **Cancelled**, leave the app and wait through five minutes after its requested time. Record whether any Cumulus alert occurs. Preserve the events and export this short-test group before clearing or starting later trials.
4. Do not advance to the two overnight trials until edit/cancellation results and any unexplained errors or duplicates have been reviewed. Recovery, physical accessibility and independent clearing checks remain required.

## Additional-run inspection — October 13

**Owner report:** "I did a few more runs." Specific new alert perceptions, old-time silence, settings, debugger state and battery were not supplied; do not infer them from the events.

**Inspected diagnostic summary:** the private read-only export retains 30 ordered events across six alarm configurations, including all five original short-trial events and 25 new events. None of these retained lifecycles is truncated. The current record is `ended`; no error or repeated haptic request within one configuration is recorded. App code is unchanged on build 19; the records do not embed their trial build. Raw exports, identities and timestamps remain outside Git.

| Configuration in retained order | Software lifecycle | Haptic-request offset |
| --- | --- | --- |
| 1 (previously inspected) | Scheduled, started, requested haptic, normal invalidation | +2.05 s |
| 2 | Scheduled, started, requested haptic, Stop requested, normal invalidation | +2.03 s |
| 3 | Scheduled, started, requested haptic, Stop requested, normal invalidation | +0.46 s |
| 4 | Scheduled, cancellation requested before replacement, normal invalidation before its requested time; no start/haptic event | None recorded |
| 5 | Replacement scheduled, then cancellation requested before another replacement; normal invalidation before its requested time; no start/haptic event | None recorded |
| 6 | Final replacement scheduled, started, requested haptic, normal invalidation | +0.71 s |

Configuration 5's request follows configuration 4's invalidation by approximately 0.016 seconds; its fire date is 120 seconds later. Configuration 6's request follows configuration 5's invalidation by approximately 0.010 seconds; its fire date is another 180 seconds later. These corroborate **one edit chain with two changes**, ending in a recorded haptic request. They do not establish two independent completed edit trials. All four recorded haptic offsets fall within 0–60 seconds, but these are short software observations, not qualifying overnight deliveries. The two recorded Stop requests corroborate app stop actions; normal invalidation without such a request does not identify the stop method.

**No standalone cancellation** (`Cancellation requested` without replacement) appears in this retained history. Absence of a haptic event on an edited-away configuration is software evidence, not an observation that its old time was physically silent. Perception, absence of physical duplicates, wearing/Focus/debugger conditions, recovery and battery remain unknown. Overall acceptance remains pending; no criteria changed.

**Next:** run one standalone cancellation on build 19 with the debugger detached and an independent backup: schedule about four minutes ahead, cancel with at least one minute remaining, confirm **Cancelled**, leave the app and wait until five minutes beyond the requested time. Record whether any Cumulus alert occurs. Preserve history for another read-back. If old-time silence and replacement perception were not observed during the edit chain, repeat one focused edit trial with those observations before overnight testing. Review cancellation and the remaining physical edit evidence before advancing. The 30-event snapshot is already preserved privately; export again before later trials displace the 40-event history. Do not clear pending or saved tests.
