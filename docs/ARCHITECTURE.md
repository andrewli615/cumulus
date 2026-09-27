# Architecture options

Architecture follows the desired experience and observed OS behavior. Leave module names provisional until the feasibility test.

## System boundary

- Which actions must work with the iPhone disconnected?
- Where is the next wake time stored?
- Which component owns the truth about a scheduled session?
- Which data, if any, must be retained after waking?

## Compare two starting options

| Option | Strength | Risk to investigate |
| --- | --- | --- |
| Watch-only | Short path to a wrist-first experience | Scheduling, cancellation, and backup behavior |
| Watch plus iPhone companion | More room for configuration and possible separate alarm | Synchronization and duplicate alerts |

## Separate concerns when code begins

- **Time and decision rules:** deterministic, independently testable.
- **Platform integration:** watchOS session, sensors, haptics, and lifecycle.
- **Experience:** a small number of clear UI states.
- **Diagnostics:** events sufficient to explain a missed or late alert, with minimal personal data.

Do not create these as folders yet. First draw the state transitions in `BEHAVIOR.md`, then record a concrete boundary decision in `decisions/`.
