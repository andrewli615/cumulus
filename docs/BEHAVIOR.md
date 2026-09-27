# What the product promises

Define observable behavior before writing code. The initial goal is one next-occurrence alarm; recurring schedules can be evaluated later.

## Questions to settle

- What does “wake by 7:30” mean when motion data is absent?
- When does the app say an alarm is **set**? What OS state confirms that claim?
- If an early haptic fires, what happens to any separate backup?
- What can the person do to cancel, edit, or postpone the alarm?
- Which failures can be reported immediately, and which can only be discovered later?

## State sketch

`Unset → Requested → Confirmed scheduled → Running → Alerted`

Also define transitions to `Canceled`, `Needs attention`, and `Unverified after relaunch`. This is a discussion sketch; change it when the Watch experiments reveal real behavior.

## Failure cases to design explicitly

| Situation | Desired user-facing response | Evidence needed |
| --- | --- | --- |
| Scheduling denied or rejected | Clear, immediate “not set” state | API result and device test |
| Sensor missing | Use a conservative decision and preserve latest-time behavior | Sensor experiment |
| Session invalidated | Never claim an alert will still occur | Error callback experiment |
| Watch off wrist, out of charge, or powered off | Explain the limitation and recommend an independent backup | Product copy review |

## Quality bar

Timing, battery use, accessibility, and privacy are product requirements. Choose measurable targets after the first physical Watch experiments; avoid using the word *guaranteed* for an unvalidated third-party alarm.
