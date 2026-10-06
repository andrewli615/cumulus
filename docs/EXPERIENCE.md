# The experience

## One sentence

How would we describe the value to someone who wears Apple Watch to sleep?

For this first experiment, the wearer opens Cumulus, schedules a test haptic a few minutes ahead, and sees the requested time with a status that says whether scheduling was accepted or failed. They may lower their wrist or leave the app while waiting. When the session starts, the app asks the system to play its alarm haptic; after returning to the app, the wearer can inspect the recorded event times or cancel a still-pending session. This tests the delivery mechanism only; it is not yet the full sleep-alarm experience.

## A single night

Write this as a short story in the person's words:

1. **Before sleep:** What time do they need to wake? How many actions should setting it take?
2. **A glance:** What is the single most useful status when they raise their wrist?
3. **During sleep:** What does the app need to do quietly, without interaction?
4. **Waking:** What should an early alert and a latest-time alert feel and look like?
5. **Something went wrong:** How will they know the app could not set or complete the alarm?

The product scenario remains undecided. The experiment uses a short relative delay (a few minutes) to make the session behavior observable without deciding the eventual wake-window interaction.

## Product goal

The first release is for personal use on Apple Watch alone. Cumulus remains a research app until its inputs and wake decision have evidence behind them. The eventual alarm should show whether it is set, whether data is usable, and what fixed latest-wake fallback is armed. The exact wake-window interaction is still open; a saved preference must never be presented as an armed system alarm.

## Experience principles

- **Glanceable:** show the next wake time and an honest set/unset/error state first.
- **Focused:** one clear action to set or edit; avoid a deep settings hierarchy.
- **Calm:** minimal interaction before bed and a clear, tactile wake experience.
- **Trustworthy:** never label a saved preference as an armed system alarm.
- **Private:** collect only data needed for the chosen wake behavior.
- **Accessible:** readable on small Watch displays and usable with VoiceOver.

These principles apply Apple's public advice for short, specialized Watch interactions to this product; they are not a claim about Apple's internal design process. See [Designing for watchOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos) and the [watchOS Pathway](https://developer.apple.com/watchos/get-started/).

## Visual direction

Use a quiet night-sky palette: the existing black background and charcoal cards, with restrained sky-blue actions and a small cloud accent. Lavender can be a secondary decorative accent, never the only way to communicate status. Keep the system typography, readable labels, and clear full-width actions.

Start with one compact cloud motif on the experiment chooser or a shared heading. Use a built-in SF Symbol for an in-app accent, verify it on the minimum supported watchOS version, and hide it from VoiceOver when decorative. Keep detailed records and trial diagnostics free of repeated decoration. If an app icon is designed later, create original artwork rather than using an SF Symbol as the icon or logo.

This visual pass is presentation-only: it must not change sensor collection, permissions, alert sessions, or experiment results. Check the physical Watch at normal and larger text sizes, scrolling, and VoiceOver before adopting the treatment across the app.

## First design exercise

Sketch just three states on paper or in Figma: **unset**, **set**, and **needs attention**. For each, write the one thing someone must understand within a few seconds. Leave color, typography, and widgets until these states are clear.
