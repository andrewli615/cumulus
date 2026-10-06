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

The table describes documented API behavior, not Cumulus guarantees. Limited physical observations are summarized below; the alert retest and short background-motion trials are supported under their tested conditions based on owner reports, not independently inspected trial summaries. Overnight collection and reliable wake delivery remain unestablished. Simulator results cannot establish alarm reliability.

## Data access investigation

Documentation reviewed for this scope on 2026-09-26 using Context7 and official Apple documentation. Record exact Xcode, watchOS, and hardware versions when running; "latest" is not a reproducible device configuration.

The first measurement experiment is [Experiment 002: Live data](experiments/002-live-data.md). Its initial implementation is a foreground probe. [Experiment 003: Background motion](experiments/003-background-motion.md) is implemented and records owner-reported successful short trials. The separate [scheduled-alert experiment](experiments/001-scheduled-alert.md) preserves the original mixed results and a subsequent successful retest after a Watch haptics setting change. Stored sleep/cardiac readers and [Experiment 006: Overnight motion](experiments/006-overnight-motion.md) are implemented. The reported pilot has a failed leading-gap criterion and unknown early visibility; overnight feasibility remains unresolved. See [the sleep research roadmap](SLEEP_RESEARCH_ROADMAP.md).

Background-motion constraints were rechecked with Context7 and Apple documentation on 2026-10-05: [extended runtime sessions](https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions), [invalidation](https://developer.apple.com/documentation/watchkit/wkextendedruntimesession/invalidate()), and [accelerometer interval](https://developer.apple.com/documentation/coremotion/cmmotionmanager/accelerometerupdateinterval).

### Documented behavior

- Motion APIs expose numerical motion measurements; availability and runtime execution are separate concerns.
- HealthKit stores measurements and derived records. Observing a store change does not instruct the Watch to take a new heart-rate measurement.
- Smart-alarm extended runtime sessions are background-capable and limited to 30 minutes. They are not an unrestricted overnight execution mode.
- Calling a haptic API does not establish that the wearer perceived it.
- A running smart-alarm session must request a haptic. The implemented sensor trial requests it after measurement stops; haptic perception is not a measurement pass criterion.
- App-initiated invalidation of a session scheduled with `start(at:)` requires the app to be active. Stopping the motion subscription does not terminate the runtime session.
- Actual accelerometer frequency must be calculated from sample timestamps rather than assumed from the requested interval.

### Working inference to test

Motion is a candidate for a live feature during a permitted wake window. Heart rate and heartbeat timing may provide additional context if observed freshness and coverage are adequate. Historical sleep classifications may help compare patterns afterward. None of these hypotheses establishes sleep-stage accuracy or an improved waking experience.

Do not assume access to a continuous raw optical (PPG) waveform from a heart-rate query. Raw acceleration, calculated heart rate, beat timing, and sleep categories must remain distinct in the data model. Do not start a fictitious workout to obtain sleep-time sensing.

### Physical Watch observations

The owner reported one successful foreground motion run: readings responded to wrist movement and stopped on request. Its device model, OS, exact sample counts, and timing were unrecorded. See Experiment 002.

The October 5 alert trials are **inconclusive**: two of three produced an observed alert and haptic, one did not despite start and haptic-request events, and no alert appeared after cancellation. The owner subsequently reported changing the Watch’s haptics setting and repeating all three scheduled alerts plus cancellation, with all four passing. Experiment 001 therefore records a subsequent result supported for the tested conditions based on owner report, while preserving the original failures. The exact setting, retest timings, and configuration details were not supplied; summaries were not independently inspected. These observations do not establish overnight reliability or a guaranteed wake deadline.

The owner reported that both background runs in Experiment 003 met the sample/freshness thresholds, that the manual-stop count stayed fixed for at least five seconds, and that alerts/cancellation worked with no observed errors. This supports short background collection under the tested conditions based on owner confirmation. Exact counts, timings, device/setup details, and battery measurements were not supplied; summaries were not independently inspected. Overnight continuity and battery costs remain unestablished. The experiment's 60-second window and acceptance thresholds are engineering choices, not platform guarantees.

## Collection paths to investigate

The research review distinguishes four paths; availability is not evidence that Cumulus has tested them:

| Path | Documented access | Cumulus implication / unknown |
| --- | --- | --- |
| Live Core Motion callbacks | Samples delivered while the app has execution time; the requested interval does not establish actual timing. | Short background collection has owner-reported support. Longer continuity and higher rates require new trials. |
| `CMSensorRecorder` | [Recording](https://developer.apple.com/documentation/coremotion/cmsensorrecorder/recordaccelerometer%28forduration%3A%29) at 50 Hz for up to 12 hours can continue while the app is suspended or terminated. [Retrieval](https://developer.apple.com/documentation/coremotion/cmsensorrecorder/accelerometerdata%28from%3Ato%3A%29) can lag by up to three minutes; data remains available for up to three days. | Implemented in Experiment 006. Owner reports pilot samples, but the 5.42 s leading gap fails and early visibility is unknown. Earlier preparation timing confounds startup attribution; new trials separate call timing. An eight-hour test was reported in progress at approximately 10% battery with outcome pending. No overnight feasibility pass. |
| Stored HealthKit records | Heart rate, heartbeat series, sleep categories, and other authorized records can be queried. [Background heart-rate intervals vary](https://support.apple.com/en-mide/120277); query completion does not guarantee fresh sensing. | Inspect per-type coverage and first observed availability before selecting model inputs. |
| SensorKit research access | [PPG](https://developer.apple.com/documentation/sensorkit/srsensor/photoplethysmogram) requires an [approved research entitlement](https://developer.apple.com/documentation/sensorkit/configuring-your-project-for-sensor-reading). [Fetches](https://developer.apple.com/documentation/sensorkit/srfetchrequest) have a 24-hour holding period. | Potential offline research branch; not an immediate alarm input or ordinary HealthKit capability. |

These paths were investigated using Context7, official Apple documentation, and the installed Watch SDK during the research review. Hardware behavior remains a separate question. Apple also documents that [sleeping wrist temperature](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/applesleepingwristtemperature) is aggregated into one nightly HealthKit value; it must not be treated as a continuous temperature stream for epoch-level staging.

## Measurement contract

Retain the signal name, unit, source, measurement timestamp, receipt timestamp, and any gap/error indicator. HealthKit samples may span an interval, so retain both start and end dates. Track sample spacing separately from delivery delay; a batch arriving now may contain old samples.

For motion, use its monotonic timestamp for sample intervals and explicitly map clock domains before comparing with wall-clock HealthKit dates. Record the mapping per run; do not subtract device-uptime values directly from calendar dates.

The live screen must show data age. Missing, stale, unavailable, and stopped are not valid zero measurements. Keep HealthKit data and raw device logs outside Git; commit only synthetic examples and nonpersonal procedure changes.
