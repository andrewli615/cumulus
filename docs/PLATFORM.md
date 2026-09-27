# Platform investigation

For each API, record **Apple's documented behavior**, **our inference**, and **what a physical Watch actually does**. Include the date and Watch/watchOS version for experiments.

| Topic | Starting source | Documented constraint | Open question |
| --- | --- | --- | --- |
| Smart alarm session | [Extended runtime sessions](https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions) | Apple documents background operation, a 30-minute session limit, scheduling within 36 hours while the app is active, and one scheduled session at a time. The scheduled session can continue if the app is suspended or terminated. | Does it start at the requested time across app exit, termination, lock, low battery, and overnight conditions on our device? |
| Alert | [Session haptic](https://developer.apple.com/documentation/watchkit/wkextendedruntimesession/notifyuser(haptictype:repeathandler:)) | Apple documents `notifyUser` for a running schedulable session. It repeats until the app or system alert invalidates the session; when the app is inactive, the system also displays an alarm alert. | Does the wearer perceive it in the tested conditions? How does stop/dismissal behave? |
| Relaunch and errors | [Session delegate](https://developer.apple.com/documentation/watchkit/wkextendedruntimesessiondelegate) | Apple documents expiry and invalidation delegate callbacks and relaunch handling through `handleExtendedRuntimeSession:`; the app must set the delegate on the relaunched session. | Which errors occur in practice? Are callbacks and persisted event records sufficient to explain interruption? |
| Motion | [Core Motion](https://developer.apple.com/documentation/coremotion/) | Watch sensors expose motion data. | Can a useful signal be sampled in the wake window at acceptable battery cost? |
| Heart and sleep | [HealthKit](https://developer.apple.com/documentation/healthkit) | Historical sleep and heart data are accessible with appropriate permission. | Is live heart data timely enough without misusing workout APIs? |
| Companion fallback | [AlarmKit](https://developer.apple.com/documentation/alarmkit) | iPhone app alarms can be presented on a paired Watch. | How reliable is coordination and cancellation when devices disconnect? |

## Evidence boundary

The statements above describe documented API behavior, not observed Cumulus behavior. The exact app lifecycle, timing, haptic perception, and cancellation outcome remain unverified on a physical Watch. Simulator results cannot establish alarm reliability.

## First experiment

**Hypothesis:** A smart-alarm session scheduled while the app is active starts after the person leaves the app, and its haptic alerts on a physical Watch.

See [`experiments/001-scheduled-alert.md`](experiments/001-scheduled-alert.md) for the procedure and evidence fields. Do not infer alarm reliability from simulator behavior.
