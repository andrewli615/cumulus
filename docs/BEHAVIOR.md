# What the product promises

These are requirements for the personal Watch-only MVP, not implemented alarm behavior. The initial scope is one next-occurrence alarm with a latest wake time and an earlier wake window. The six current screens remain experiments. [Input qualification](experiments/006-overnight-motion.md) precedes selecting a decision method or building the final wake flow.

## Fixed-alarm first release

The owner approved a reduced Watch-only version on October 9. One absolute fire date within the next 36 hours is scheduled while the app is active. The initial screen shows a next-occurrence time selector and full date confirmation. States are Not set, Scheduling requested, Scheduled (observed `.scheduled` only), Unverified after relaunch, Haptic requested, Cancellation requested, Cancelled, Stopped, Ended or Needs attention. Scheduled does not guarantee delivery.

Editing must invalidate the old session and wait for confirmed non-error cancellation before scheduling its replacement. Failed cancellation blocks replacement; a replacement scheduling failure means the old alarm is no longer set. Relaunch never automatically re-arms. Recovered running sessions request haptics only once per alarm record; the API request is distinct from perception. Persist alarm configuration and the latest 40 lifecycle events separately from research data; collect no sensors or HealthKit data.

Smart-waking requirements below are deferred, not satisfied. The fixed alarm has no early decision or independent automatic latest-wake fallback; keep an independent alarm. Build 16 implements this flow. Device validation remains pending. A passed fire date is rejected rather than silently shifted to another day at submission; skipped local times resolve forward preserving minutes and repeated times select the first occurrence. The full resolved date is shown before scheduling.

## Future smart-waking target actions

- Set and review the next latest wake time and earlier window in a few clear steps.
- Edit or cancel with a visible result. A saved edit is not confirmation that an old request was cancelled or a replacement was armed.
- Recover after relaunch or interruption without silently issuing another request. Reconcile saved intent with supported platform evidence; unresolved requests remain unverified.
- Stop an active alert and inspect a concise later account of the decision path, requests, errors, and uncertainty.

## Truthful target states

| Displayed state | Required evidence and meaning |
| --- | --- |
| Saved setup | Local preferences only; no armed-alarm claim. |
| Scheduling requested | A request was made; acceptance or failure is still unresolved. |
| Armed | The selected platform mechanism provides scheduling evidence and the separately tested fallback is in place. Describe the tested limits; this is not a guaranteed wake deadline. |
| Inputs insufficient | Required measurements are missing, stale, uncertain, or outside the validated coverage. Follow the tested latest-wake fallback rather than inventing an early decision. |
| Alert requested | The API request is recorded with its time and decision path. It does not establish perception or waking. |
| Cancelled | Cancellation is confirmed for the applicable pending requests. A tap alone is only cancellation requested. |
| Needs attention / unverified | An error, interruption, or insufficient platform evidence prevents a truthful armed or cancelled claim. Show what remains known and the useful next action. |

Final scheduling and fallback mechanisms are unselected. These state requirements must be mapped to their actual API evidence and physical tests before implementation. Do not reuse the experiment's session status as proof that a final latest-wake alarm is armed.

## Current scheduled-alert experiment

`Unset → Scheduling requested → Session scheduled → Session running → Haptic requested`

The experiment also has cancellation, invalidation, error, and unverified-after-relaunch states. **Haptic requested** means the app called the API; it does not claim the wearer felt it. **Session scheduled** is shown only when the session's observed state is `.scheduled`; it does not guarantee a later start. This existing short-session experiment is distinct from the final product state requirements above.

## Decision and fallback requirements

Select the research task from evidence: a wake opportunity, sleep/wake estimate, or stages may be appropriate. A larger stage model is not required merely because stage labels are readable. Define success criteria and compare the chosen method with a simple baseline on the same task before adopting it.

The user's required minimum sleep opportunity is a hard eligibility gate for an earlier wake. A cycle estimate or sensor signal cannot authorize waking before that gate is met. A planned sleep opportunity does not prove actual time asleep; claim measured sleep duration only after sleep-onset and sleep/wake estimation are validated. Cycle alignment is a candidate timing prior, not a fixed 90-minute rule or a validated sleep-stage detector. Evaluate the product benefit using waking outcomes, not stage agreement alone.

An early decision can use only qualified inputs available by that decision time. Preserve measurement time, first observed availability, missingness, and uncertainty. Future samples, historical labels used as inputs, and whole-night context cannot support an earlier live decision.

Missing or stale data must leave a separately tested latest-wake path. An early haptic request alone must not be treated as proof that the wearer woke or that a fallback can safely be cancelled. Decide and test how early alerts, stopping, edits, and cancellation affect all pending requests before the final flow is considered ready.

## Failure cases to design explicitly

| Situation | Desired user-facing response | Evidence needed |
| --- | --- | --- |
| Scheduling denied or rejected | Clear, immediate “not set” state | API result and device test |
| Sensor missing, stale, or uncertain | Show insufficient inputs and follow the separately tested latest-wake fallback | Availability/coverage evidence and insufficient-data trials |
| Alert mechanism invalidated | Identify the affected request; show a remaining fallback as armed only with independent scheduling evidence | Interruption/recovery and fallback trials |
| Relaunch with saved intent but no scheduling evidence | Show unverified; do not silently re-arm or claim successful cancellation | Physical relaunch trials and synthetic late-callback checks |
| Watch off wrist, out of charge, or powered off | Explain the limitation and recommend an independent backup | Product copy review |

## Quality bar

Write measurable battery, accessibility, privacy, retention/deletion, delivery, fallback, and waking-outcome criteria before final validation. Repeated physical results are needed for sensor and alert behavior; builds and synthetic checks establish software behavior only. Claims describe tested devices, software, settings, and conditions. Keep an independent alarm during development and make no medical or guaranteed-wake claim without suitable evidence. The [build plan](BUILD_PLAN.md#personal-mvp-exit-evidence) records the remaining exit evidence.
