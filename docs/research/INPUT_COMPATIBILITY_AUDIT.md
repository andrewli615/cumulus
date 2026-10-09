# Research input compatibility audit

Reviewed: 2026-10-06. Scope: the candidates already listed in the [sleep research roadmap](../SLEEP_RESEARCH_ROADMAP.md), public paper text, dataset descriptions, licenses, and author code. No recordings, datasets, weights, or external code were downloaded to the repository or executed. This is a documentation milestone; benchmark implementation remains gated.

Implementation/evidence status aligned: 2026-10-08. This update aligns the app and experiment gates; it does not re-review the October 6 paper, dataset, artifact or licensing findings.

## Recommendation

**No listed stage model is currently demonstrated compatible with sufficiently available and timely Cumulus inputs.** Keep the first release Watch-only and personal, but do not add a stage classifier yet.

SLAMSS-IFS with BIDSleep is the closest **conditional offline** candidate because it uses Apple Watch acceleration and heart-rate quantities. Pair it with a simple feature classifier only after matching input coverage is confirmed and its reproduction blockers below are resolved. Public source code alone does not make it a ready-to-run or causal baseline. If only motion qualifies, consider a separately specified sleep/wake study before a four-stage study; quiet movement is not a validated stage.

## What Cumulus has established

| Input | Current evidence | Consequence |
| --- | --- | --- |
| Wrist acceleration | The original pilot retains its failed 5.42 s leading gap and 11 saved order anomalies. The inspected October 8 build-6 pilot has 59,757 samples, 49.95 Hz, 39/40 qualifying buckets, timely block visibility and passing gap checks; five date-only ordering failures remain. | Preserve both outcomes. Build-8 read-back reproduces five within-query backward-date comparisons; a fresh build-8 pilot reproduces four failures and flags trial clock uncertainty. Build 9 corrects the awake-only elapsed-clock choice; the inspected physical build-9 pilot has no clock-uncertainty flag but twenty backward-date failures and an incomplete fixed block. Further trials are paused for timestamp investigation. No qualifying current-build pilot, matching battery baseline or two recording nights is established. Passing timing alone would not supply the discarded feature values. |
| Motion feature values | The retrieval worker checks finite acceleration values, then keeps only timing/count/quality metadata. | Existing summaries cannot reconstruct magnitude, variability, or respiratory motion. A private feature/input pipeline would require a later reviewed milestone; no export is added here. |
| Heart-rate quantities | Experiment 005 was reported passed; actual sampling density, overnight coverage, freshness, and grouped-record presence are unknown. | Do not assume a five-second heart-rate stream or infer continuity from record spans. |
| Beat intervals | Heartbeat-series presence is unknown; individual beat timestamps and gap flags have not been queried. SDNN is a summary. | Use the implemented runtime-gated Experiment 007 inspector only when a fresh read observes an eligible series; physical coverage and timing remain unestablished. Neither sparse BPM nor an SDNN value supplies the beat sequence required by an IBI model. |
| Other channels | Cumulus has not demonstrated raw PPG, continuous ECG, epoch-level temperature, or a respiratory waveform. | Models requiring these channels are blocked. Apple sleep categories are historical comparison records, not model inputs or independent ground truth. |

These are owner reports and code observations, not independently inspected physiological recordings. See [Experiment 005](../experiments/005-cardiac-data-coverage.md), [Experiment 006](../experiments/006-overnight-motion.md), and [the retrieval worker](../../Cumulus%20Watch%20App/OvernightMotionRecorder.swift). A late successful read does not measure publication delay.

## Closest published candidate: SLAMSS-IFS / BIDSleep

[BIDSleep v1.0.1](https://physionet.org/content/bidsleep-dataset/1.0.1/) contains 253 nights from 47 healthy adults, with wrist acceleration, approximately 0.2 Hz heart-rate quantities, and 30-second Dreem-2 EEG-headband labels. It includes both automated and single-expert-corrected labels; these are not full PSG or a multi-scorer consensus. The dataset uses **Open Data Commons Attribution 1.0**, separately from the code license. Preserve attribution and pin the version. Its description specifies timestamped three-axis motion but no fixed native acceleration rate. Label-start times stored in Eastern Time need explicit timezone/DST handling against Unix sensor times.

The [primary SLAMSS-IFS paper](https://pmc.ncbi.nlm.nih.gov/articles/PMC12931632/) used Apple Watch Series 6. It removes outliers and interpolates irregular heart rate and acceleration to 1 Hz, derives motion magnitude and epoch-level sampling/time information, and processes sequences of up to 1,200 thirty-second epochs. Four classes merge N1 and N2 into Light; Deep is N3, alongside Wake and REM. The reported split is 31 training, five validation, and 11 test participants, with additional cross-validation. These acquisition conditions do not prove that Cumulus's stored HealthKit quantities match the study.

Author code inspected at [commit 088e363](https://github.com/BIDSLabUMass/SLAMSS-IFS/tree/088e363873b4ac5b27bc23fb038abc052889698c):

- **BSD-3-Clause** code license. The tree contains model source and two notebooks, but no raw-CSV preprocessing pipeline or the local checkpoints referenced by testing. Expected preprocessed MAT fields include cardiac, activity, time, frequency, and corrected-label arrays. Their exact construction must be resolved before reproduction.
- Night-wide normalization, full-sequence encoder initialization, and unmasked attention use information unavailable at earlier decisions. Interpolation can also require a later measurement. Bidirectional processing within a completed epoch alone is not the whole-night issue.
- The testing notebook passes reference-label one-hot arrays to the decoder; its initial input is the first reference label even with teacher forcing disabled. A fixed start token and a label-independence check are required for unbiased evaluation. This code observation does not establish how every published evaluation was run.

Primary code: [model](https://github.com/BIDSLabUMass/SLAMSS-IFS/blob/088e363873b4ac5b27bc23fb038abc052889698c/model/SLAMSS_IFS_Model.py), [testing notebook](https://github.com/BIDSLabUMass/SLAMSS-IFS/blob/088e363873b4ac5b27bc23fb038abc052889698c/SLAMSS_IFS_Testing.ipynb), [license](https://github.com/BIDSLabUMass/SLAMSS-IFS/blob/088e363873b4ac5b27bc23fb038abc052889698c/LICENSE).

Reproduction and a causal adaptation are different experiments. Replacing normalization, attention, interpolation, or decoder initialization requires retraining/evaluation; it cannot inherit the paper's results. Similar nominal motion rates do not establish matching hardware calibration, units, placement, preprocessing, or heart-rate availability.

## Other candidates

| Candidate | Required signals, placement, rates, and labels | Compatibility decision |
| --- | --- | --- |
| [Apple October 2025 report](https://www.apple.com/health/pdf/Estimating_Sleep_Stages_from_Apple_Watch_Oct_2025.pdf) | Wrist accelerometer staging, including respiration-related motion; four states, with PSG and reviewed home EEG references. The 2025 update uses foundation models. The report does not specify a reproducible input rate/context contract or provide model artifacts. | Useful motion-only research rationale; no reusable published baseline established. Apple's private sensing/model performance does not validate Cumulus's summaries or decision-time availability. |
| [WatchSleepNet](https://proceedings.mlr.press/v287/wang25a.html) | Three-class Wake/NREM/REM model using waveform-derived inter-beat intervals. Pretraining uses clinical ECG/PPG; fine-tuning uses wrist PPG from Empatica E4 in DREAMT, with technician PSG labels. | Blocked by unconfirmed beat timing/coverage and sensor shift. Occasional BPM quantities cannot substitute for its IBI stream. |
| [SleepPPG-Net2](https://cris.technion.ac.il/en/publications/sleepppg-net2-deep-learning-generalization-for-sleep-staging-from/) | Raw PPG four-class model. The [author preprint v1](https://arxiv.org/html/2404.06869v1) describes predominantly fingertip oximeters across six PSG cohorts: native rates 25–256 Hz, harmonized to 34.13 Hz after zero-phase filtering. | Raw PPG is not demonstrated. Zero-phase filtering uses future signal; full temporal context and normalization must be audited in the selected journal implementation. The older preprint is not confirmation of every final implementation detail. |
| [Mamba multimodal study](https://pubmed.ncbi.nlm.nih.gov/41649157/) | ANNE One chest ECG at 512 Hz and acceleration at 210 Hz, finger PPG at 128 Hz, chest/finger temperatures at 1 Hz; high-rate channels processed at 100 Hz. Manual PSG labels support three/four/five classes. | Blocked by channels and placement. The [full article](https://pmc.ncbi.nlm.nih.gov/articles/PMC13089490/) specifies a bidirectional Mamba block; predictions use future context. Its chest-motion ablations do not demonstrate wrist-motion equivalence. |
| [Short-window PPG, September 2026](https://www.nature.com/articles/s41598-026-72556-1) | Accepted early article describes three-class PPG staging with 3.5–50.5-minute windows, using MESA and CAP. Its accessible HTML lacks full methods; PDF text was unavailable in this audit. | Raw PPG blocked; exact required rate, label mapping, centered versus trailing windows, and preprocessing remain unverified. A short window does not establish causal inference. |
| [Transition-focused preprint v1](https://arxiv.org/html/2608.00943v1) | Finger-PPG study describes MESA at 64 Hz and supplementary CFS evaluation. Four-class primary task; coarse PSG labels constrain second-level pseudo-labels, with separate expert review. | Raw PPG blocked. Label expansion uses adjacent future context and reference labels; it is offline supervision, not deployable alarm input. The paper's 64 Hz description differs from the native MESA rate reported above; establish the resampling/version contract before reuse. Fine-resolution labels do not create independent physiological truth. |

### Reuse and temporal-context checks

- **WatchSleepNet:** inspected [author code at e1a5d85](https://github.com/WillKeWang/WatchSleepNet_public/tree/e1a5d8552d0f10b3730130ce2f3c35891a786fa5). Its README displays an MIT badge, but the inspected tree has no license file and GitHub's license metadata is empty; obtain explicit terms before adopting code. The [model](https://github.com/WillKeWang/WatchSleepNet_public/blob/e1a5d8552d0f10b3730130ce2f3c35891a786fa5/modeling/models/watchsleepnet.py) uses bidirectional LSTM and attention with a padding mask, not a causal mask. Preprocessing represents waveform-derived IBIs at 25 Hz; that is a model grid, not 25 independent beats per second. Label-based trimming/epoch selection also needs separation from deployment inputs.
- **DREAMT v2.0.0**, the version linked by that repository, has [restricted data access and a 1.5.0 data-use agreement](https://physionet.org/content/dreamt/2.0.0/). E4 BVP is natively 64 Hz and acceleration 32 Hz, with resampled 100 Hz files available. Newer DREAMT versions exist; pin one rather than silently mixing preprocessing or labels. MESA/SHHS access requires [NSRR dataset-specific approval](https://sleepdata.org/about/data-security), not just public paper access.
- **SleepPPG-Net2:** the preprint article is CC BY 4.0; a verified Net2 code/checkpoint license was not established. MESA/CFS/ABC/HomePAP/SHHS require their access terms; [CAP v1.0.0](https://physionet.org/content/capslpdb/1.0.0/) uses ODC Attribution 1.0. SLEEPAI access/reuse terms remain unverified. An article license does not license all recordings or code.
- **Mamba:** the full article is CC BY-NC 4.0 and says data/code are shared on reasonable request; no downloadable, explicitly licensed reproduction package was established. Request-based access is a blocker, not permission already granted.
- **Short-window PPG:** article CC BY 4.0; code/weights and exact data version terms unverified. MESA and CAP access differ as above.
- **Transition preprint:** [arXiv's non-exclusive distribution license](https://arxiv.org/licenses/nonexclusive-distrib/1.0/) is not a code/model reuse grant. No author-linked licensed implementation or expanded-label release was established. MESA/CFS permissions must be checked separately.
- **Apple:** the report is copyrighted; no public model weights, training data license, or implementation contract was established by it.

Unknown means not verified here, not proof that an artifact or permission does not exist. No account access, data-use agreement, SensorKit application, or author contact is undertaken by this milestone.

## Proposed input contract for a later benchmark

Keep a versioned JSON manifest and separate UTF-8 CSV tables for timestamped signals, reference labels, and derived feature rows outside Git. Use UTC Unix seconds with fractional precision; preserve original units and timezone provenance. Synthetic examples and checks may enter the repository after the benchmark milestone is authorized. This format is proposed, not an implemented export.

| Record | Minimum fields and rules |
| --- | --- |
| Manifest | Pseudonymous participant/night IDs, dataset/version/license, source/device, wrist placement, units, timezone conversion, acquisition/preprocessing version, and observed or assumed availability provenance. |
| Motion | UTC measurement time, first observed readable time when actually captured, x/y/z in explicit units, validity/gap flags. Preserve native timestamps; do not turn missing intervals into quiet movement. |
| Heart-rate quantities, if qualified | Measurement time, first observed availability, bpm, source, and expanded internal timestamps only if confirmed/implemented. Keep quantities separate from beat intervals. |
| Beat series, only if qualified | Beat times, explicit gap flags, source and availability; exclude intervals spanning missing beats. No fabricated beats from BPM interpolation. |
| Labels | Separate reference table: epoch start/end, category, reference device/scorer and version. For BIDSleep, preserve both label types, select expert-corrected labels for the main comparison, merge N1/N2 explicitly, and mask Unknown. Fix alignment without using labels to locate inputs. |
| Feature row | Completed 30-second epoch, feature-window bounds, calculation version, valid sample counts/coverage, latest required availability time, and missingness. Recording start may be known; future sleep onset/end must not enter features. |

Published datasets generally provide measurement times, not original first-read times. Their causal replay must distinguish measured Cumulus availability from explicitly assumed delay scenarios. Leave unobserved availability unknown; an assumed zero-delay replay cannot establish live feasibility.

## Evaluation proposal, not implementation

If paired motion/HR qualifies, compare the repaired published architecture with an explainable multinomial logistic baseline on the **same four-class task and epochs**. Proposed features are motion-magnitude variability, trailing quiet-bout duration, cardiac mean/variation, and explicit missingness. Cardiac variation here is not beat-based HRV. Fit scaling and feature choices on training data only. Fix quiet thresholds, trailing windows, and abstention policy before inspecting held-out results. If only motion qualifies, a binary sleep/wake study is an alternative, not a four-stage substitute.

Use five participant-grouped outer folds with participant-grouped validation/model selection inside each training fold. Every night from a person stays together. If published split identities become available, also report the paper's fixed participant split as a separate reproduction. Record split IDs, random seeds, preprocessing, code/version pins, and any adaptations. Personal nights provide availability and transfer observations; one wearer cannot establish population generalization.

Report macro-F1, each class's precision/recall/F1 and confusion matrix, balanced accuracy and kappa, participant-level variability and participant-bootstrap intervals. Report calibration/uncertainty, abstention, eligible epoch coverage, exclusions and missing/stale-input performance, including errors on rejected epochs where references exist. Coverage must accompany performance so filtering cannot hide difficult periods. Sleep summaries need separate duration/onset errors; stage agreement does not prove waking benefit.

No model-performance or alarm-benefit acceptance threshold is selected by this audit. Predefine those thresholds and the missing-data/latency policy in the benchmark proposal before testing.

Keep retrospective reproduction separate from causal replay. At decision time, every input and feature must already be readable; audit interpolation, filters, normalization, sequence attention, trimming, and label dependence. Test that changing future samples or any reference label cannot change an earlier prediction. A delayed decision may use completed past epochs, but must report their age and observation latency. Unknown availability prevents a validated causal claim.

## Next gates

1. **Investigate the preserved Experiment 006 failure:** the exploratory comparison is complete and inconclusive because it involved charging/interruption; the October 8 pilot still fails ordering. Build-8 retained-pilot read-back reproduces five within-query backward-date comparisons with advancing sensor timestamps. The fresh build-8 pilot reproduces four backward-date failures and flags trial clock uncertainty. Build 9 corrects the awake-only elapsed clock for new trials; its physical pilot has no clock uncertainty but twenty backward-date failures and an incomplete block. Pause trials and investigate timestamp mapping/input requirements under unchanged criteria before overnight trials. Follow [the diagnostic procedure](../experiments/006-overnight-motion.md#build-8-ordering-diagnostic-procedure).
2. **Qualify physical inputs:** run a fresh current-build pilot if needed using unchanged timing/visibility criteria, then the matching comparison and two recording nights only if it qualifies. Confirm Experiment 005's actual cardiac type presence and coverage; the existing conditional inspector must not query a type until a fresh read observes an eligible record.
3. **Review compatibility and private data handling:** confirm sufficiently available inputs and whether they can support offline research, live decisions, or neither. Resolve preprocessing, start-token, artifact/license, label-alignment, and retention/export blockers. Current summaries alone are insufficient.
4. **Authorize a bounded offline benchmark:** keep it outside the Watch target and use the preregistered split/metrics/causal checks above. If no candidate qualifies, record the mismatch and stop before implementing a classifier.
5. **Only then consider the personal Watch MVP:** explicit data readiness/uncertainty, a separately verified fixed latest-wake fallback, alert-delivery trials, and repeated battery/accessibility/interruption and waking-benefit checks. Keep an independent alarm during development. No wake-deadline guarantee follows from this audit.

Learning exercise: explain why a well-populated 30-second motion bucket cannot supply a motion-variability feature, and why a later measurement used by interpolation can change an earlier prediction.
