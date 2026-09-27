# Step-by-step build

Each stage produces something reviewable. Advance when the exit question has an evidence-based answer.

| Stage | Deliverable | Exit question |
| --- | --- | --- |
| 1. Experience | One-night story and three status sketches | Can a person understand the app at a glance? |
| 2. Behavior | Alarm states and failure responses | Are the product promises honest and testable? |
| 3. Feasibility | Apple API notes and short Watch experiment | Does scheduled background haptic behavior work on the device? |
| 4. Design choice | Watch-only vs companion decision record | Which design best serves the verified behavior? |
| 5. First Xcode slice | Native Watch App with one short alarm flow | Can the person set, see, and experience one alarm? |
| 6. Smart decision | Motion experiment and replayable rule | Does it improve the experience without weakening reliability? |
| 7. Refinement | Accessibility, battery, privacy, repeated nights | What evidence supports a portfolio release? |

Avoid building an analytics dashboard, HealthKit integration, or ML model until a measured need appears. When stage 5 starts, create a watchOS App with Xcode's template and keep its standard project structure initially.
