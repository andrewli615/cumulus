# Step-by-step build

Each stage produces something reviewable. Advance when the exit question has an evidence-based answer.

| Stage | Deliverable | Exit question |
| --- | --- | --- |
| 1. Experience | One-night story and three status sketches | Can a person understand the app at a glance? |
| 2. Behavior | Alarm states and failure responses | Are the product promises honest and testable? |
| 3. Feasibility | Minimal watch-only test screen, Apple API notes, and physical Watch experiment | Does the scheduled session start and alert on the device, and can the app report its state honestly? |
| 4. Design choice | Watch-only vs companion decision record, informed by experiment evidence | Which design best serves the observed behavior? |
| 5. First product slice | Alarm flow beyond the disposable experiment | Can the person set, see, and experience a real next-occurrence alarm? |
| 6. Smart decision | Motion experiment and replayable rule | Does it improve the experience without weakening reliability? |
| 7. Refinement | Accessibility, battery, privacy, repeated nights | What evidence supports a portfolio release? |

Avoid building an analytics dashboard, HealthKit integration, or ML model until a measured need appears. Stage 3 should start from Xcode's standard watchOS App template and keep its standard project structure initially. A simulator build can check code and layout, but cannot establish physical Watch alarm reliability.
