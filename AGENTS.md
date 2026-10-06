# Codex guidance

- For a requested milestone, inspect the relevant code and plans, explain the approach and key risk, then implement, build, test, and fix issues until the milestone is complete. Do not pause for approval on routine, reversible project changes.
- Keep the owner informed before meaningful changes and explain each file's purpose. At completion, report changed files, verification, remaining risks, and one learning exercise.
- Treat plans and architecture as revisable when evidence changes. Keep changes small, clear, and easy to revise. Ask before expanding the requested milestone, taking destructive actions, or publishing externally.
- Keep project goals current in the existing build plan, roadmap, and relevant experiment notes. Mark documented platform facts, assumptions, and owner-reported results distinctly. Prefer updating existing docs; add a new file only for a distinct experiment or research audit.
- At task start, inspect Git status, branch, remotes, and recent commits. Preserve unrelated work; never reset, clean, rebase, amend, or stage unrelated changes.
- Stage only task files and inspect the staged diff. Run relevant checks, then commit small, coherent changes regularly with an accurate, concise agent-written message. Report the commit and checks.
- Do not amend existing commits, force-push, tag, release, or publish unless explicitly asked. Push only after the owner reviews and approves the exact branch and outgoing commits. Before pushing, verify the remote, branch, outgoing commits, and working tree; push only what was reviewed and report the result. Get renewed approval if the branch or commits change after review. Force-push requires separate explicit authorization.
- Use GitHub for relevant read-only context. Create or change pull requests, issues, comments, labels, releases, or repository settings only when explicitly asked; verify the repository and target, then confirm the result.
- For unfamiliar or changing watchOS APIs, use Context7 and verify against official Apple documentation. Separate documented behavior, inference, and physical Watch observations.
- Keep alarm status truthful. Do not claim a reliable wake deadline without device evidence; recommend an independent alarm during development.
- Keep HealthKit data and raw device logs out of the repository.
- Run relevant existing builds and checks when authorized. Simulator results do not establish physical alarm reliability.

## Coding style

- Keep code simple, direct, and efficient. Avoid unnecessary abstraction and dependencies.
- Use clear names and comments for non-obvious decisions; avoid comments that merely restate the code.
- Handle errors explicitly; avoid broad catch blocks.
- Match existing formatting and conventions.
