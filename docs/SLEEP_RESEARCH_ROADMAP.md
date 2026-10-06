# Sleep research roadmap

Research reviewed: 2026-10-05

Status: sleep-history reader implemented; physical inspection pending. Later implementation chunks require separate owner review. No production staging algorithm is selected.

## Evidence we have

- Experiment 001 preserves the original mixed alert results and a subsequent owner-reported pass of three alerts plus cancellation after changing Watch haptics. Exact setting changes and retest timings are unspecified.
- Experiment 003 records owner-reported passes for two 60-second background motion runs and the manual-stop check. The owner confirmed the sample/freshness thresholds and that the displayed count remained fixed for five seconds after stop.
- Exact trial measurements and device/setup details were not supplied; summaries were not independently inspected. These are reports of support under tested conditions, not evidence of overnight reliability or validated sleep staging.
- Signing-free device and simulator builds and synthetic checks passed. Interactive simulator navigation/layout remains unverified because Computer Use permission was not granted. This is distinct from the earlier environment's simulator-service failures.

See [Experiment 001](experiments/001-scheduled-alert.md), [Experiment 003](experiments/003-background-motion.md), and [platform evidence](PLATFORM.md). Preserve failed runs alongside successful retests.

## Next steps and decision criteria

| Step | Proposed work | Evidence needed before building on it |
| --- | --- | --- |
| 1. Align documentation | Preserve results, qualify evidence, and record this sequence. | Consistent status summaries and source links. Implemented; keep summaries aligned as evidence changes. |
| 2. Inspect available records | Read-only sleep history implemented, awaiting physical inspection; then separately reviewed queries for heart rate, heartbeat series, respiratory rate, and wrist temperature. | Categories, source attribution, measurement dates, coverage/gaps, and first observed availability. Empty records are not proof of denied permission. |
| 3. Test overnight motion | A separate `CMSensorRecorder` feasibility experiment, starting with a short availability check before an overnight trial. | Predefined criteria for continuity, sample rate, retrieval lag, battery, and storage; record actual configuration. Decide separately whether data suits offline research and timely decisions. |
| 4. Reproduce offline baselines | Audit BIDSleep/SLAMSS-IFS code, dataset version, license, labels, preprocessing, and acquisition requirements; compare with an explainable feature model. | Reproducible participant-separated evaluation, per-class errors, and compatible signal coverage. Do not mix one participant's nights between train and test. |
| 5. Evaluate an alarm-window estimator | Use only data available by the decision time, with explicit missing-data and uncertain outputs. | Causal replay, measured latency, calibration, useful coverage, and performance under missing/stale inputs. Define acceptance thresholds before testing. |
| 6. Evaluate the alarm experience | Separate alert-reliability testing from testing whether the timing rule improves waking outcomes. | A prewritten comparison protocol and outcome measures. Stage agreement alone does not establish an improved waking experience. |

The next action is the physical inspection in [Experiment 004](experiments/004-sleep-stage-feasibility.md). The sleep-history reader is implemented; additional record queries require a separate proposal. No personal-data recording, dataset download, model training, SensorKit application, or later code change is authorized by this plan. The owner reviews and commits each chunk.

## Signal access determines model choice

| Signal / path | Documented capability | Research implication and remaining uncertainty |
| --- | --- | --- |
| Live accelerometer | Core Motion callbacks provide motion while execution is available. | Existing short tests support delivery by owner report; they do not validate a stage feature, higher rate, or all-night execution. |
| System-recorded accelerometer | `CMSensorRecorder` documents 50 Hz recording for up to 12 hours even while suspended or terminated. Retrieval can lag up to three minutes; retention is up to three days. | A new overnight candidate, not a tested Cumulus capability. Check `isAccelerometerRecordingAvailable()` and actual device behavior. The 30-minute smart-alarm limit is a session limit, not a universal recording limit. |
| Heart rate | Background intervals vary; HealthKit returns stored values. | Measure coverage and freshness. Querying more often does not force more measurements; interpolating sparse BPM does not recover missing beat timing. |
| Heartbeat series / HRV | Stored beat series include gap indicators; an HRV quantity is a summary. | Determine whether enough real beat intervals exist for a beat-based model. Do not equate BPM samples, SDNN summaries, and beat sequences. |
| Respiratory rate | HealthKit exposes derived rate records. | Inspect sampling and availability; a rate is not a continuous respiratory waveform. |
| Sleeping wrist temperature | HealthKit exposes a nightly aggregate, despite more frequent internal measurements. | Candidate night-level context, not an assumed epoch-level temperature stream. |
| SensorKit PPG | Requires approved research access and entitlement; newly recorded data has a 24-hour holding period. | An offline research branch, not an immediate alarm input or ordinary HealthKit access. |
| Apple sleep categories | Categorized intervals can overlap and may not cover every in-bed interval. | Useful comparison records; neither raw inputs nor independent ground truth for Cumulus staging. |

Apple sources: [recording](https://developer.apple.com/documentation/coremotion/cmsensorrecorder/recordaccelerometer%28forduration%3A%29), [retrieval](https://developer.apple.com/documentation/coremotion/cmsensorrecorder/accelerometerdata%28from%3Ato%3A%29), [background heart rate](https://support.apple.com/en-mide/120277), [heartbeat gaps](https://developer.apple.com/documentation/healthkit/hkheartbeatseriesquery/init%28heartbeatseries%3Adatahandler%3A%29), [respiratory rate](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/respiratoryrate), [wrist temperature](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/applesleepingwristtemperature), [SensorKit research access](https://developer.apple.com/documentation/sensorkit/configuring-your-project-for-sensor-reading), [PPG](https://developer.apple.com/documentation/sensorkit/srsensor/photoplethysmogram), [holding period](https://developer.apple.com/documentation/sensorkit/srfetchrequest), [sleep categories](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis).

## Candidate methods and evidence limits

These are research candidates, not a leaderboard: different stage definitions, cohorts, sensors, labels, and validation protocols prevent direct ranking by accuracy.

| Method / source | What is relevant | Limitation for Cumulus |
| --- | --- | --- |
| [Apple sleep staging, October 2025 report](https://www.apple.com/health/pdf/Estimating_Sleep_Stages_from_Apple_Watch_Oct_2025.pdf) | Accelerometer-based staging with foundation-model updates demonstrates that motion contains more than movement counts. | Apple's performance does not transfer to our probe or establish access to its model. |
| [SLAMSS-IFS, online 2025 / journal issue 2026](https://ieeexplore.ieee.org/document/11173983) | Convolutional/LSTM model using Apple Watch heart rate and acceleration; approximately 71% four-class accuracy in a 47-person study. [Code](https://github.com/BIDSLabUMass/SLAMSS-IFS) and [BIDSleep v1.0.1](https://physionet.org/content/bidsleep-dataset/1.0.1/) offer a reproducible starting point. | Data acquisition must match our obtainable signals. Dreem EEG-headband labels are automated reference labels, not full PSG. Audit temporal context before considering live inference. |
| [WatchSleepNet, 2025](https://proceedings.mlr.press/v287/wang25a.html) | Transfer learning uses beat intervals as a shared representation across clinical and wrist sensors for three-class staging. | Requires adequate beat timing; occasional heart-rate readings are not interchangeable inputs. |
| [SleepPPG-Net2, 2025](https://cris.technion.ac.il/en/publications/sleepppg-net2-deep-learning-generalization-for-sleep-staging-from/) | Multi-source training improves generalization of raw-PPG staging. | Raw waveform requirements and device/population shifts remain substantial; not a model for sparse BPM values. |
| [Mamba multimodal study, April 2026](https://pubmed.ncbi.nlm.nih.gov/41649157/) | Sequence modeling tested in 357 adults with chest ECG/motion/temperature and finger PPG. | Different sensors and placements; results do not validate a Watch-only implementation. |
| [Short-window PPG study, September 2026](https://www.nature.com/articles/s41598-026-72556-1) | Investigates context lengths relevant to a wake window; the abstract reports strongest three-class agreement with 25.5 minutes. | Not Apple Watch validation. Full implementation details and absence of future context were not verified in this review. |
| [Transition-focused training, August 2026 preprint](https://arxiv.org/abs/2608.00943) | Uses expanded temporal labels to improve staging around transitions. | Preprint; model-generated fine-grained labels do not independently establish second-level physiological truth. |
| Explainable baseline, proposed | Motion variability, quiet-bout duration, available cardiac trends, and explicit missingness could feed a simple classifier. | Features, thresholds, and model remain unselected. Never label an unvalidated movement feature as a sleep stage. |

The [July 2026 systematic-review preprint](https://www.preprints.org/manuscript/202607.1006) guided source discovery. It is not peer-reviewed. Original studies and official API documentation should drive implementation decisions; verify version changes when a candidate is selected.

## Evaluation rules

1. Separate sleep/wake detection, three- or four-stage classification, sleep-summary estimation, and alarm benefit. Define the task before comparing numbers.
2. Keep all nights from each participant within one data partition. Fit preprocessing and model selection on training/validation data, not the test set.
3. Report per-stage errors, macro F1, agreement, participant-level variability, missing-data coverage, and uncertainty alongside accuracy. For duration/timing summaries, report their own errors.
4. For a live decision, exclude future measurements, retrospective labels used as inputs, whole-night normalization, and any backward sequence context not available at that time. Measurement time and first observed availability are separate fields; a historical query cannot reconstruct original availability by itself.
5. Compare against a simple baseline before adopting a larger architecture. Evaluate transfer to the actual sensor and collection conditions instead of assuming clinical or other-device results carry over.
6. Treat Apple's stages as a comparison reference. Stronger stage-validation claims need an independent reference appropriate to the claim, such as PSG; agreement with Apple alone measures agreement with Apple.
7. Keep HealthKit records and raw device logs outside Git. Any future private recording needs a separately reviewed retention, storage, and deletion design. Store only synthetic examples and nonpersonal research notes here.

## First learning exercise

A heart-rate measurement occurred at 07:00 but Cumulus first read it at 07:03. Explain why an offline chart can include it at 07:00 while a replay of an alarm decision at 07:01 must exclude it. Then explain why a retrospective HealthKit query alone cannot prove when that record first became readable.
