# Codex guidance

- For a requested milestone, inspect the relevant code and plans, explain the approach and key risk, then implement, build, test, and fix issues until the milestone is complete. Do not pause for approval on routine, reversible project changes.
- Keep the owner informed before meaningful changes and explain each file's purpose. At completion, report changed files, verification, remaining risks, and one learning exercise.
- Treat plans and architecture as revisable when evidence changes. Keep changes small, clear, and easy to revise. Ask before expanding the requested milestone, taking destructive actions, or publishing externally.
- Commit small, coherent changes regularly after their relevant checks pass; do not accumulate unrelated work. Write a concise commit message and report the commit. Do not amend, push, or publish unless asked.
- For unfamiliar or changing watchOS APIs, use Context7 and verify against official Apple documentation. Separate documented behavior, inference, and physical Watch observations.
- Keep alarm status truthful. Do not claim a reliable wake deadline without device evidence; recommend an independent alarm during development.
- Keep HealthKit data and raw device logs out of the repository.
- Run relevant existing builds and checks when authorized. Simulator results do not establish physical alarm reliability.

## Coding style

- Keep code simple, direct, and efficient. Avoid unnecessary abstraction and dependencies.
- Use clear names and comments for non-obvious decisions; avoid comments that merely restate the code.
- Handle errors explicitly; avoid broad catch blocks.
- Match existing formatting and conventions.
