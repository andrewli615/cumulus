# Platform investigation

For each API, record **Apple's documented behavior**, **our inference**, and **what a physical Watch actually does**. Include the date and Watch/watchOS version for experiments.

| Topic | Starting source | Documented constraint | Open question |
| --- | --- | --- | --- |
| Smart alarm session | [Extended runtime sessions](https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions) | Background-capable; up to 30 minutes; schedule within 36 hours while app is active; one session at a time. | What happens after termination, rescheduling, or low battery on our devices? |
| Alert | [Session haptic](https://developer.apple.com/documentation/watchkit/wkextendedruntimesession/notifyuser(haptictype:repeathandler:)) | Call while a scheduled session is running. | Timing, visibility, and dismissal behavior? |
| Relaunch and errors | [Session delegate](https://developer.apple.com/documentation/watchkit/wkextendedruntimesessiondelegate) | Session start, expiry, and invalidation callbacks exist. | Which errors occur in practice and what can be recovered? |
| Motion | [Core Motion](https://developer.apple.com/documentation/coremotion/) | Watch sensors expose motion data. | Can a useful signal be sampled in the wake window at acceptable battery cost? |
| Heart and sleep | [HealthKit](https://developer.apple.com/documentation/healthkit) | Historical sleep and heart data are accessible with appropriate permission. | Is live heart data timely enough without misusing workout APIs? |
| Companion fallback | [AlarmKit](https://developer.apple.com/documentation/alarmkit) | iPhone app alarms can be presented on a paired Watch. | How reliable is coordination and cancellation when devices disconnect? |

## First experiment to plan

**Hypothesis:** A smart-alarm session scheduled while the app is active starts after the person leaves the app, and its haptic alerts on a physical Watch.

Define a two-minute procedure, record actual timestamps, test with the screen lowered, and repeat. Do not build the complete alarm UI to answer this one question. Record the result in `experiments/`.
