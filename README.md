# Cumulus

A design workspace for a watchOS smart alarm. This repository contains **planning and research only**. We will create the Xcode project after the core experience and platform feasibility are clear.

## The idea

Set the latest time you need to wake. During a short window beforehand, Apple Watch may choose an earlier moment to alert you. If no suitable moment is found, it should attempt to alert at the latest time. The reliability of that last step must be measured on a real Watch; this is not yet a dependable replacement for Clock.

## Working approach

Apple's public watchOS guidance favors brief, focused interactions and information that is useful at a glance. We will use that guidance to make product decisions, while treating the design as our own. A person should be able to understand the next wake time and whether it is set without navigating through a dashboard.

1. **Experience:** describe one night and the one or two interactions that matter.
2. **Behavior:** define what the alarm promises, including uncertainty and failure.
3. **Platform:** verify watchOS limits from documentation and short device experiments.
4. **Architecture:** compare simple designs and record decisions.
5. **Build:** create the native Xcode Watch App and implement one vertical slice at a time.
6. **Refine:** test on the wrist, observe timing and clarity, then remove unnecessary complexity.

## Structure

```text
cumulus/
├── README.md
├── AGENTS.md
└── docs/
    ├── EXPERIENCE.md          User moment and Watch interaction
    ├── BEHAVIOR.md            States, promises, and failure cases
    ├── PLATFORM.md            Apple API evidence and open questions
    ├── ARCHITECTURE.md        Options and system boundaries
    ├── BUILD_PLAN.md          Thin slices and exit criteria
    ├── decisions/README.md    Why a design choice was made
    └── experiments/README.md Physical Watch experiment notes
```

Start with `docs/EXPERIENCE.md`. Write a short description of setting the alarm at night, checking it at a glance, and waking up. Then review the questions in `docs/PLATFORM.md`. Leave unanswered sections open rather than inventing certainty.

References: [Designing for watchOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos), [watchOS Pathway](https://developer.apple.com/watchos/get-started/).
