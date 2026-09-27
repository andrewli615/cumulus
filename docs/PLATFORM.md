# Platform investigation

For each API, record **Apple's documented behavior**, **our inference**, and **what a physical Watch actually does**. Include the date and Watch/watchOS version for experiments.

| Topic | Starting source | Documented constraint | Open question |
| --- | --- | --- | --- |
| Smart alarm session | [Extended runtime sessions](https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions) | Apple documents background operation, a 30-minute session limit, scheduling within 36 hours while the app is active, and one scheduled session at a time. The scheduled session can continue if the app is suspended or terminated. | Does it start at the requested time across app exit, termination, lock, low battery, and overnight conditions on our device? |
| Alert | [Session haptic](https://developer.apple.com/documentation/watchkit/wkextendedruntimesession/notifyuser(haptictype:repeathandler:)) | Apple documents `notifyUser` for a running schedulable session. It repeats until the app or system alert invalidates the session; when the app is inactive, the system also displays an alarm alert. | Does the wearer perceive it in the tested conditions? How does stop/dismissal behave? |
| Relaunch and errors | [Session delegate](https://developer.apple.com/documentation/watchkit/wkextendedruntimesessiondelegate) | Apple documents expiry and invalidation delegate callbacks and relaunch handling through `handleExtendedRuntimeSession:`; the app must set the delegate on the relaunched session. | Which errors occur in practice? Are callbacks and persisted event records sufficient to explain interruption? |
| Motion | [Core Motion](https://developer.apple.com/documentation/coremotion/) | Core Motion exposes raw acceleration and processed device motion; processed user acceleration removes gravity. Check hardware/API availability before collection. | What sample rate, gaps, and delivery delays do we observe in the intended wake window? |
| Heart rate updates | [Observer queries](https://developer.apple.com/documentation/healthkit/executing-observer-queries) | Observers report changes to the HealthKit store; another query retrieves the samples. Background delivery requires configuration and does not provide a continuous sensor stream. | How fresh are readable heart-rate samples while the app is open and during the smart-alarm session? |
| Heartbeat timing | [Heartbeat series query](https://developer.apple.com/documentation/healthkit/hkheartbeatseriesquery) | Stored heartbeat series can be queried when available. The query reports beat times and whether a beat follows a data gap. | Are readable series sufficiently complete and timely for our intended calculation? |
| Sleep classifications | [Sleep analysis](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis) | HealthKit represents sleep categories as samples. These categories are interpreted results, not raw sensor measurements. | When do samples become readable on each device, and are they useful only for later comparison? |
| Read permission | [HealthKit authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data) | Access is requested by data type. The app cannot directly distinguish denied read access from an absence of readable records. | Can the wearer understand an empty result without the app falsely labeling permission as denied? |
| Companion fallback | [AlarmKit](https://developer.apple.com/documentation/alarmkit) | iPhone app alarms can be presented on a paired Watch. | How reliable is coordination and cancellation when devices disconnect? |

## Evidence boundary

The statements above describe documented API behavior, not observed Cumulus behavior. The exact app lifecycle, timing, haptic perception, and cancellation outcome remain unverified on a physical Watch. Simulator results cannot establish alarm reliability.

## Data access investigation

Documentation reviewed for this scope on 2026-09-26 using Context7 and official Apple documentation. Record exact Xcode, watchOS, and hardware versions when running; "latest" is not a reproducible device configuration.

The first measurement experiment is [Experiment 002: Live data](experiments/002-live-data.md). Its initial implementation is a foreground probe. Background collection is a later step, using a correctly configured smart-alarm session and the separate [scheduled-alert experiment](experiments/001-scheduled-alert.md).

### Documented behavior

- Motion APIs expose numerical motion measurements; availability and runtime execution are separate concerns.
- HealthKit stores measurements and derived records. Observing a store change does not instruct the Watch to take a new heart-rate measurement.
- Smart-alarm extended runtime sessions are background-capable and limited to 30 minutes. They are not an unrestricted overnight execution mode.
- Calling a haptic API does not establish that the wearer perceived it.

### Working inference to test

Motion is a candidate for a live feature during a permitted wake window. Heart rate and heartbeat timing may provide additional context if observed freshness and coverage are adequate. Historical sleep classifications may help compare patterns afterward. None of these hypotheses establishes sleep-stage accuracy or an improved waking experience.

Do not assume access to a continuous raw optical (PPG) waveform from a heart-rate query. Raw acceleration, calculated heart rate, beat timing, and sleep categories must remain distinct in the data model. Do not start a fictitious workout to obtain sleep-time sensing.

### Physical Watch observations

None yet. All collection rates, freshness, background continuity, battery costs, and alert outcomes remain unverified for Cumulus.

## Measurement contract

Retain the signal name, unit, source, measurement timestamp, receipt timestamp, and any gap/error indicator. HealthKit samples may span an interval, so retain both start and end dates. Track sample spacing separately from delivery delay; a batch arriving now may contain old samples.

For motion, use its monotonic timestamp for sample intervals and explicitly map clock domains before comparing with wall-clock HealthKit dates. Record the mapping per run; do not subtract device-uptime values directly from calendar dates.

The live screen must show data age. Missing, stale, unavailable, and stopped are not valid zero measurements. Keep HealthKit data and raw device logs outside Git; commit only synthetic examples and nonpersonal procedure changes.
