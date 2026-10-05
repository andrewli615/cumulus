# Experiment 003: Background motion feasibility

Date planned: 2026-10-05

Status: plan only; implementation and physical trials pending

## Question and evidence boundary

Can Cumulus receive sufficiently fresh motion samples throughout a short measurement window in a scheduled extended runtime session after the owner leaves the app?

Experiment 001's October 5 alert result remains **inconclusive**. Do not repeat or rescore those trials as part of this experiment. Success here supports background measurement only under the tested conditions, not reliable alert delivery, sleep interpretation, or a wake deadline. Keep an independent alarm available.

## Documented behavior

Reviewed using Context7 and official Apple documentation on 2026-10-05:

- Smart-alarm extended runtime sessions support background execution, have a 30-minute limit, and must be scheduled while the app is active. Only one session can be scheduled at a time. Attach the delegate to a session delivered on relaunch.
- Apple requires a haptic request during the running smart-alarm session. Request it after motion collection stops, so it cannot contaminate the measurement window. This is required session behavior, not another alert-delivery assessment.
- A session scheduled using `start(at:)` can be invalidated by the app only while active. The system alarm's Stop action can also end it. Stopping motion collection is distinct from invalidating the session.
- The requested accelerometer interval is not proof of actual sampling frequency; calculate intervals from delivered sample timestamps.

Sources: [Extended runtime sessions](https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions), [invalidate()](https://developer.apple.com/documentation/watchkit/wkextendedruntimesession/invalidate()), [notifyUser](https://developer.apple.com/documentation/watchkit/wkextendedruntimesession/notifyuser(haptictype:repeathandler:)), [accelerometerUpdateInterval](https://developer.apple.com/documentation/coremotion/cmmotionmanager/accelerometerupdateinterval).

## Proposed implementation boundary

Keep the foreground Motion probe available between trials. A separate Background motion test will schedule a session three minutes ahead. Only one experiment may own motion collection or a scheduled session at a time. Preserve the existing alert experiment and its outcome.

Start collection only after observing the session running. Request 10 Hz acceleration for a 60-second window measured from collection start using a monotonic clock. The collector must be owned by the experiment/session rather than the screen, so navigation or background entry does not stop this trial. Continue stopping the existing foreground probe when its screen disappears.

Data flow: schedule action → session coordinator → running callback/relaunch → motion queue → bounded timestamp/count summaries → local diagnostics and UI. Copy sample metadata on the motion queue; publish UI state on MainActor. Do not send every raw sample to disk or retain acceleration vectors. Do not start HealthKit queries in this experiment.

At the window end, stop the sensor, reject further callbacks for that run, save the final summary, and request the required notification haptic if the session is still running. Record the actual stop time, including any overshoot; a timer target does not prove exact execution. The owner then uses the system Stop action or reopens the app to invalidate the session while active. Do not claim that stopping samples ended the session.

Manual stop, sensor errors, will-expire, and invalidation must stop collection and record the reason. A recovered session after process interruption must not silently restart a fresh 60-second trial: mark the measurement interrupted and its missing interval unknown. A saved request alone remains unverified until WatchKit delivers a session. Late or old-run callbacks must not restart collection.

Main risk: delayed callbacks or UI updates can resemble live collection. Measure sample time and callback receipt time separately. Alternative: a foreground-only baseline is simpler and useful for debugging, but cannot establish background continuity.

Code changes require a separate file-level proposal and owner review before implementation.

## Bounded diagnostic metadata

Retain only the latest five trial summaries on the Watch, separate from the alert experiment's history. Each trial contains twelve five-second sample summaries and at most 40 lifecycle events. Record any truncation or overflow explicitly; missing required evidence makes the trial inconclusive. No raw acceleration vectors, HealthKit readings, or raw device logs belong in Git.

Per-trial metadata:

- Trial ID, Watch model, watchOS, app build, battery at start/end, power mode, wrist state, exit method, and debugger-detached confirmation. Unknown values stay unknown.
- Requested session time; session start callback or running-observation time; relaunch and app-state transition times; collection start and actual stop times; will-expire, invalidation, and error domain/code.
- First and last sample timestamps, count of accepted distinct samples, duplicate/out-of-order counts, longest sample gap, maximum receipt delay, and stop reason.
- For each five-second bucket: count, first/last sample timestamps, receipt-time bounds, and maximum gap/delay. Include gaps crossing bucket boundaries in the trial maximum. Empty buckets remain visible.
- Collection-stop and session-invalidation events are separate. Label the haptic event as a request only.

Assign buckets by measurement timestamp relative to collection start, not by callback arrival time. Use the same monotonic clock domain for interval and delay calculations; record its mapping to wall-clock time for comparison with session events. Do not subtract uptime directly from calendar dates. Clock discontinuities or unverifiable mappings invalidate timing conclusions.

## Truthful screen states

Show session and sensor states separately: **Session scheduled**, **Waiting for samples**, **Samples arriving**, **Samples stale**, **Collection stopped**, **Session expiring**, **Session expired**, **Interrupted**, or **Unverified after relaunch**. Show sample age, counts, and stop/error reason. More than two seconds without a fresh sample is stale, not zero movement. A will-expire callback is not confirmed expiry. No UI update while suspended proves nothing about sensor delivery; persisted metadata determines the result.

## Physical procedure

1. After the implementation passes its build checks, install it on the Watch. Stop debugging and launch from the Watch icon. Record the configuration above and keep an independent alarm available. Confirm no other experiment is active or unresolved.
2. Trial A: schedule the sensor session three minutes ahead, record the requested time, leave using the Digital Crown, and lower your wrist before the requested start. Keep Cumulus in the background for the entire collection window. Avoid deliberate movement; this tests sample delivery, not activity classification.
3. Reopen about five minutes after the requested start regardless of whether a haptic was perceived. The short sensor window should already have ended; record actual behavior if it has not. Stop any remaining session while active, inspect diagnostics, and preserve the summary privately. If collection never started or background state cannot be established, do not invent a window or count it as passing.
4. Trial B: repeat with the same settings, opening another app before lowering your wrist. Record that app and any interruption. Again keep Cumulus backgrounded throughout collection and reopen independently of haptic perception.
5. Manual-stop trial: schedule a separate sensor session, return to Cumulus after samples begin, and stop collection before its 60-second window ends. Record the stop and invalidation events. Wait at least five seconds in the app and verify accepted sample counts remain fixed. This is a stop-control check, not a full background-coverage run.
6. Record failures and unexpected interruptions without overwriting them. Do not repeat Experiment 001's alert/cancellation series. Any further sensor trials require a stated reason and one changed condition at a time.

## Predefined criteria

These are provisional engineering thresholds chosen for this experiment, not Apple guarantees or biological requirements. Fix them before collecting results; do not lower them afterward to manufacture a pass.

For both Trial A and Trial B:

- The session is observed running and the complete 60-second collection window occurs while the app is backgrounded, supported by recorded app-state transitions.
- Each of the twelve five-second measurement buckets contains at least 40 distinct, strictly increasing sample timestamps (at least 480 samples overall).
- Startup delay to the first sample, trailing gap from the last sample to the window end, maximum inter-sample gap, and maximum callback receipt delay are each no greater than two seconds.
- No unexplained interruption, premature expiry, sensor error, missing required metadata, or diagnostic overflow occurs. Record collection duration and any stop overshoot; a materially different window is not a completed trial under this protocol.
- Stop is recorded and no subsequent samples are accepted for that trial. Queued callbacks after stopping may be discarded but cannot resume the run.

The manual-stop trial must record explicit stop and session termination, with accepted sample counts unchanged afterward.

- **Supported under tested conditions:** both background trials and the manual-stop check satisfy their criteria. Report actual counts, gaps, delays, and conditions; do not generalize to overnight collection or wake reliability.
- **Contradicted:** complete evidence shows a repeatable failure of background collection or stop behavior under the recorded conditions. A lower actual rate can fail this protocol without proving all background motion collection impossible.
- **Inconclusive:** mixed results, missing metadata, uncertain app state or clocks, process interruption without sufficient evidence, or an isolated unexplained failure prevents a firm conclusion.

## Software verification before device trials

Build the Watch target and check navigation and layout in an available simulator. Test bounded storage, bucket boundaries, cross-bucket gaps, stale status, late callbacks after stopping, relaunch interruption, errors, and expiry cleanup using synthetic inputs. Simulator and synthetic results do not establish physical collection behavior.

Short trials do not test the natural 30-minute expiry. Record expiry callbacks if encountered, but keep physical expiry behavior unverified unless actually observed. Do not extend these trials just to wait for expiry.

## Result

Pending implementation and physical sensor trials. No background motion result is recorded. Experiment 001 remains inconclusive.

## Learning exercise

If 50 samples arrive together after a five-second pause, compare their measurement timestamps with receipt times. Explain why a high total sample count alone cannot establish fresh, continuous delivery.
