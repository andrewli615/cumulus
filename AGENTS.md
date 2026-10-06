# Codex guidance

- Before editing files, show the proposed changes and wait for the owner's review. Explain each file's purpose and use case. Commit only when the owner explicitly asks Codex to commit; otherwise leave changes uncommitted. Codex may write a concise commit message describing the approved changes.
- Read only documents relevant to the task. Treat plans and architecture as revisable when evidence changes.
- Implement only the approved milestone. Before coding, explain the user behavior, technical risk, data flow, and one alternative.
- For unfamiliar or changing watchOS APIs, use Context7 and verify against official Apple documentation. Separate documented behavior, inference, and physical Watch observations.
- Keep alarm status truthful. Do not claim a reliable wake deadline without device evidence; recommend an independent alarm during development.
- Keep HealthKit data and raw device logs out of the repository.
- Run relevant builds and tests when available. A simulator does not establish alarm reliability.
- At completion, summarize changed files, verification, remaining uncertainty, and one learning exercise.

# Coding Style Guidelines

- Keep code simple, flat, and direct. Avoid unnecessary abstraction.
- Use clear, descriptive variable and function names.
- Do not add broad try/catch blocks; let errors propagate explicitly.
- Write self-explanatory code with minimal comments.
- Match existing file formatting and conventions.
