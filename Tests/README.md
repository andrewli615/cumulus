# Synthetic checks

Run from the repository root on macOS with Xcode installed:

```sh
./scripts/check-background-motion.sh
./scripts/check-sleep-history.sh
```

Both runners default `DEVELOPER_DIR` to `/Applications/Xcode.app/Contents/Developer`; override it for another installation. Each creates a temporary build directory and removes it on exit. No personal records or raw device logs are used.

| Suite | Coverage |
| --- | --- |
| `BackgroundMotionChecks.swift` | Sample bucket boundaries, gaps/delays, stale samples, stopping and late callbacks, error handling, archive bounds, session ownership, cancellation, expiry, and relaunch routing. Compiles the actual trial, owner, coordinators, and app delegate. |
| `SleepHistoryChecks.swift` | Read-only authorization, unavailable/empty/error states, category mapping, source/date preservation, 500-row truncation, cancellation, and late authorization/query callbacks. Compiles the actual sleep reader. |

The scripts remove platform imports only from temporary source copies and supply platform doubles. Repository app sources are not rewritten. The sleep suite makes the previously temporary reader harness repeatable; it uses short waits to let MainActor tasks complete and does not simulate HealthKit delivery timing.

A successful run prints a PASS summary and exits zero; a failed precondition or compiler error exits nonzero. These are standalone Swift executables, not Xcode test targets. Run each in its own process because each suite defines its own platform doubles and entry point.

## What these checks cannot establish

Platform doubles test app logic, not real WatchKit or HealthKit behavior. Run signing-free device and simulator builds separately using [the README instructions](../README.md). Interactive navigation, permission sheets, physical data availability, haptic perception, and battery behavior need their own checks. The manual-stop screen count must still be observed on the Watch; accumulator checks alone do not prove displayed behavior.

Physical procedures and evidence belong in [the experiment notes](../docs/experiments/README.md). Keep their original failures, retests, and evidence limits intact.
