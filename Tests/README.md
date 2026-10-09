# Synthetic checks

Run from the repository root on macOS with Xcode installed:

```sh
./scripts/check-background-motion.sh
./scripts/check-sleep-history.sh
./scripts/check-cardiac-history.sh
./scripts/check-overnight-motion.sh
./scripts/check-test-archive.sh
./scripts/check-cardiac-timing.sh
PYTHONDONTWRITEBYTECODE=1 python3 Tests/TestArchiveRetrievalChecks.py
```

All runners default `DEVELOPER_DIR` to `/Applications/Xcode.app/Contents/Developer`; override it for another installation. Each creates a temporary build directory and removes it on exit. No personal records or raw device logs are used.

| Suite | Coverage |
| --- | --- |
| `CardiacTimingChecks.swift` / `CardiacTimingProviderChecks.swift` | Aggregate spacing without bridging flagged gaps or rejected entries; count/privacy/eligibility, timeout/cancellation and late results. The actual HealthKit adapter compiles against platform doubles to check object predicates, interval/offset conversion, mismatched lookup, errors and entry caps. No physical availability is inferred. |
| `TestArchiveChecks.swift` | Real file persistence/relaunch, fractional dates, stable-ID updates, payload retrieval, report/byte ceilings, corrupt files and symlinks, invalid IDs/schema, deletion and suppression of deleted legacy imports, capacity readiness and typed archived evidence review. All fixtures are synthetic. |
| `TestArchiveRetrievalChecks.py` | Private output guard including ignored Git directories, bounded JSON/base64 decoding, missing input, identity mismatches and corrupt files. No device is contacted. |
| `BackgroundMotionChecks.swift` | Sample bucket boundaries, gaps/delays, stale samples, stopping and late callbacks, error handling, archive bounds, session ownership, cancellation, expiry, and relaunch routing. Compiles the actual trial, owner, coordinators, and app delegate. |
| `CardiacHistoryChecks.swift` | Source-specific gap merging and window edges, grouped counts, units, per-type result limits/errors, partial completion, read-only authorization, invalid records, cancellation, and late callbacks. Compiles the actual cardiac reader and coverage calculations. |
| `OvernightMotionChecks.swift` | Manual pilot target/deadline/uncertainty guidance and actual streaming worker, bucket/chunk boundaries, gaps and failed-criterion explanations, order-anomaly categories with expected overlap excluded, bounded subtype counts and legacy summaries with unknown breakdowns, finite values, clocks, bounded archives/enumeration, nil/empty results, authorization, fixed requests, slow preparation and recorder-call reservations, time-driven eligibility, pilot gate including rejection of another build/watchOS, qualification revoked by an incomplete latest probe and restored by a usable retry, preservation of history across revocation/relaunch/cancellation/clock-uncertain probes, legacy recovery, completed evidence across later reboot/read uncertainty, cancellation, summary replacement, and battery comparisons. `OvernightPlatformDoubles.swift` is also used by the background suite to compile the updated app delegate. |
| `SleepHistoryChecks.swift` | Read-only authorization, unavailable/empty/error states, category mapping, source/date preservation, 500-row truncation, cancellation, and late authorization/query callbacks. Compiles the actual sleep reader. |

Coordinator and history-reader suites also assert that actual implementations write diagnostic reports, HealthKit records are not encoded as payloads, and clearing preserves completed reports. The background suite verifies deletion is blocked by pending ownership/coordinator state and removes completed recovery data without reimport after relaunch.

The scripts remove platform imports only from temporary source copies and supply platform doubles. Repository app sources are not rewritten. The sleep suite makes the previously temporary reader harness repeatable; it uses short waits to let MainActor tasks complete and does not simulate HealthKit delivery timing.

A successful run prints a PASS summary and exits zero; a failed precondition or compiler error exits nonzero. These are standalone Swift executables, not Xcode test targets. Run each in its own process because each suite defines its own platform doubles and entry point.

## What these checks cannot establish

Platform doubles test app logic, not real WatchKit or HealthKit behavior. Run signing-free device and simulator builds separately using [the README instructions](../README.md). Interactive navigation, permission sheets, physical data availability, haptic perception, and battery behavior need their own checks. The manual-stop screen count must still be observed on the Watch; accumulator checks alone do not prove displayed behavior.

Physical procedures and evidence belong in [the experiment notes](../docs/experiments/README.md). Keep their original failures, retests, and evidence limits intact.

Build-8 overnight checks distinguish date/sensor equality from reversal, compare with the last accepted sample, and exercise within-query and cross-query positions through the actual worker. Fixtures cover inclusive endpoints and the SDK's open-start interpretation without changing acceptance. Tests check the twelve-example cap, totals after truncation, malformed metadata, build-6/older decoding, per-read retention after summary replacement, and a 960-bucket/40-read payload against the existing 350,000-byte ceiling. These checks do not resolve the physical date-only anomaly cause.

`CUMULUS_UI_PREVIEW=order` selects a synthetic ordering screen with fourteen failures and twelve retained examples. It uses the existing normal/larger-text override and does not start recording or read physical data.

Build-6 visual checks used `SimulatorPreviewScreen` in an isolated 40 mm Watch simulator. `CUMULUS_UI_PREVIEW` selects `guide`, `archive`, `report`, or `timing`; `CUMULUS_UI_TEXT=larger` forces `.xxxLarge` instead of `.large`. These Debug Simulator-only fixtures use synthetic summaries and do not automatically query HealthKit or start recording. Initial-view screenshots are outside Git; they do not verify scrolling, VoiceOver, deletion or physical sensor behavior. The isolated simulator was removed after verification.

Build-7 trial previews use `CUMULUS_UI_PREVIEW=trial-selector` or `trial-choices`; `CUMULUS_UI_TRIAL=pilot`, `overnight`, or `comparison` seeds the selected mode without recording. The existing `CUMULUS_UI_TEXT=larger` override checks wrapping at `.xxxLarge`. Native Crown/touch navigation and VoiceOver require separate interaction checks.

`CUMULUS_UI_PREVIEW=trial-setup` shows the actual setup screen with synthetic Unknown values and no recording request. Its Watch model and Other app labels remain visible while populated; `CUMULUS_UI_TEXT=larger` checks the same screen at `.xxxLarge`.

The setup-label correction passed signing-free generic Watch and Watch Simulator Debug builds. Initial-screen snapshots on an isolated 40 mm watchOS 27 simulator were inspected at `.large` and `.xxxLarge`; larger text pushes the editable rows further down the scrolling form. Full-form scrolling, the offscreen Other app row, and VoiceOver were not interactively verified. No physical Watch installation or recording was performed for this check.

The overnight suite also exercises build 11’s versioned sensor-elapsed timing over eight hours (48 queries), with both endpoint interpretations, bounded wall-date steps, true sensor repeats, missing samples and large clock-mapping changes. Historical trials retain legacy wall-date timing. These are software checks, not physical sensor evidence.

Build 12 checks eight-hour setup/battery preflight, fresh battery recheck at Start, matching baseline identity, uncertainty and duration rejection, relaunch without rearming, deadline guidance, missing/empty/unexpected results and cancellation. No synthetic outcome establishes physical overnight recording or battery cost.

Build 13 largest-gap checks use the actual streaming worker to distinguish missing sensor rows from query-excluded returned rows, including identical accepted counts/gaps across those cases. The largest record has query/typed-row positions, signed clock deltas, a batch-change flag and bounded skipped-row counts/ranges; acceptance and thresholds are unchanged. Checks cover within-query gaps, cross-query gaps, optional legacy metadata, persistence, inconsistent maxima, per-read coordinator retention and the existing eight-hour/forty-read payload bound. `CUMULUS_UI_PREVIEW=gap` opens a synthetic gap screen without sensor access; `CUMULUS_UI_TEXT=larger` checks its initial viewport at `.xxxLarge`. Private historical reports remain outside Git.

Build 13's overnight/archive suites and signing-free Watch/Simulator Debug builds passed. Synthetic initial-viewport screenshots on an isolated 40 mm watchOS 27 simulator were inspected at `.large` and `.xxxLarge`; the gap value is readable and the larger heading wraps. Full scrolling, offscreen diagnostic rows and VoiceOver remain unverified. All seven privately retained overnight snapshots validate with the current model, preserving the latest failed timing/qualification.
