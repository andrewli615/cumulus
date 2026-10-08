# Experiment 007 — conditional cardiac internal timing

Status: implemented for build **0.1 (6)**; physical availability and inspector behavior remain untested. Earlier overall Experiment 005 passes do not establish grouped quantities or heartbeat-series presence.

## Question and entry gate

When a fresh Cardiac history read actually finds a grouped heart-rate quantity (count greater than one) or a nonempty heartbeat series, can Cumulus inspect that one record's internal timing, compare returned counts with its declared count, and preserve missingness honestly?

This is a retrospective input-inspection experiment. It does not establish continuous overnight sensing, original publication time, usable live alarm inputs, HRV accuracy, sleep stages, or a wake decision. If neither type is present, no internal series query is offered or run. Do not manufacture a positive availability result by interpolating BPM or interpreting SDNN as beat intervals.

## Implementation and data boundaries

Cardiac history offers timing actions for at most the newest five eligible records per relevant type. Selecting one copies only its ID, category, declared count and boundaries into memory; leaving the overview still clears its individual records. The inspector is an explicit foreground action, blocked during another pending experiment or when the local archive cannot accept a report. It reuses read permission; no write authorization, workout, or continuous heart sensing is requested.

`HealthKitCardiacTimingQuery` uses the current quantity/heartbeat series descriptors, scoped by the observed object's ID. Quantity results contain date intervals and values; values are checked for finiteness and discarded. A heartbeat sample is looked up by that same ID before reading offsets and preceded-by-gap flags. No other record is substituted if it cannot be found. Both descriptors expose finite sequences; current SDK declarations and Context7/official Apple documentation were checked. Cancellation and prompt cessation on this Watch remain physical checks.

Records declaring more than 20,000 entries are rejected before a series query, rather than relying solely on a loop break after the SDK may have buffered a large series. Each eligible read inspects at most 20,000 entries and has a 60-second foreground timeout. Either bound gives a partial result, not a completed enumeration. Cancellation, leaving, backgrounding, or conflicting ownership stops the task; request identity rejects late results. UI checkpoints occur every 250 entries. A cancellation/timeout report contains the latest checkpoint, which may omit entries processed since it; it never claims a complete count. Errors are shown in memory, while the archive saves a generic failure state.

Diagnostics distinguish received and accepted counts, invalid values/times, nonincreasing offsets, gap flags, adjacent-valid spacing-pair count, minimum/maximum contiguous spacing, observed offset span, completion and bounds. Spacing pairs do not bridge invalid/order-rejected entries or preceded-by-gap flags. The quantity API does not supply heartbeat gap flags, so the corresponding field is **Not provided**, not zero missing beats. Quantity measurement spacing and heartbeat spacing are different signals; neither is converted into a sleep or HRV estimate here.

Only these bounded aggregate diagnostics, declared count, generic status and query request/update times enter Saved tests. Individual BPM values, individual sample/beat dates or offsets, selected HealthKit IDs and source identifiers are not stored. Counts and aggregate timing can still be sensitive: use the [local archive retention/deletion design](../ARCHITECTURE.md#storage-boundaries), keep private retrieved copies outside Git, and delete those copies separately when no longer needed. This is not a raw feature dataset.

## Physical procedure and criteria written before trials

1. Finish any pending experiment, install the current build, launch from the Watch icon without a debugger, and keep an independent alarm. Record model, watchOS, build, battery and relevant settings; missing details remain unknown.
2. Open Cardiac history and Read / Refresh. Preserve its saved counts, window, truncation and error status. If no eligible record appears, record **not observed in this window** and stop this experiment; that does not prove no such data exists anywhere.
3. If a grouped heart-rate record appears, select one timing action and tap **Inspect internal timing**. Record completion, declared/received/accepted counts, invalid/order counts, spacing diagnostics, errors and any cap/timeout. Verify quantity spacing is presented as measurement spacing, not beat intervals.
4. If a heartbeat series appears, inspect one in the same way. Preserve gap flags and verify adjacent spacing excludes flagged gaps. Gap-free results from one record do not establish night-wide coverage.
5. Run a separate cancellation/exit check when a read lasts long enough: cancel or background the app during inspection, return, and verify no late callback repopulates cleared timing state. If every query finishes too quickly, mark this check **not exercised**, not passed.
6. Open Saved tests and confirm completed or partial reports are readable after relaunch. Retrieve privately when connected; add only nonpersonal outcome summaries here. Check normal/larger text, scrolling and VoiceOver without placing personal screenshots or raw logs in Git.

- **Internal enumeration supported under tested conditions:** an observed eligible record returns a completed enumeration within the bounds; received and accepted counts equal the declared count; no unexplained invalid/order anomalies or query failure remains. Report results separately for quantity and heartbeat kinds.
- **Partial/inconclusive:** empty/missing lookup, truncation/cap/timeout/cancellation, unavailable conditions, unexplained count mismatch or ordering, or unexercised checks prevent the relevant conclusion. A reported API error is not proof of permission denial.
- **Timing/gaps observed:** report them descriptively. There is no preselected biological spacing threshold, stage classifier or all-night coverage criterion in this experiment. Any model input contract requires additional coverage, causal availability and reuse evidence.

## Software verification and next decision

Synthetic checks exercise real summary/controller logic and the actual HealthKit adapter against platform doubles: predicate selection, interval/offset conversion, gap exclusions, invalid/order handling, record lookup mismatch, entry cap, timeout, errors, blocked reads, clearing and rejection of late results. SDK builds check real API integration. Neither substitutes for the physical procedure above.

On October 6, both timing executables passed and the Watch/Simulator SDK builds reported 0.1 (6). Synthetic initial-view snapshots were inspected at normal/larger SwiftUI sizes on an isolated 40 mm simulator. The physical Watch was disconnected; the inspector was not run on personal records, and availability/cancellation/gap behavior on the Watch remain untested.

Use the resulting observations to decide whether a more specific coverage/availability study has a reason. Preserve the unresolved motion, battery and live-decision gates; no model or final alarm flow is selected by this inspector.

Sources: [quantity series descriptor](https://developer.apple.com/documentation/healthkit/hkquantityseriessamplequerydescriptor), [heartbeat descriptor](https://developer.apple.com/documentation/healthkit/hkheartbeatseriesquerydescriptor), [heartbeat gap semantics](https://developer.apple.com/documentation/healthkit/hkheartbeatseriesquery/init%28heartbeatseries%3Adatahandler%3A%29), [Swift concurrency queries](https://developer.apple.com/documentation/healthkit/running-queries-with-swift-concurrency).

Learning exercise: compare two heart-rate measurement times with two heartbeat offsets. Explain why their intervals are not interchangeable, then explain why neither retrospective series reveals when it first became available to an alarm.
