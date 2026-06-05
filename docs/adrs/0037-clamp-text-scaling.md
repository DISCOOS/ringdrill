---
status: accepted            # proposed | accepted | deprecated | superseded by ADR-NNNN
date: 2026-06-04            # date of the decision
deciders: ["kengu"]        # who signed off
consulted: []               # who was asked for input
informed: []                # who was kept in the loop
---

# ADR-0037: Clamp the app-wide text scale factor to a maximum of 1.3

## Context and problem statement

iOS Dynamic Type (and the Android font-size setting) let users enlarge system
text far beyond the default, up to roughly 310% at the largest accessibility
sizes. Flutter surfaces this as `MediaQuery.textScaler`, and Material text
styles honour it automatically. RingDrill never bounds it.

A Dynamic Type review found the app carries tight fixed-height chrome that
cannot survive extreme scales without a heavy refactor: AppBar toolbars at 56
and 72, the two-line `SheetTitle` inside 72, the live-drill timeline rows
(`phase_tile`, `phase_widget`, `phase_headers`, `mini_round_row`) fixed at 24
and 32, and the drill mini-player bar. Supporting the full accessibility range
everywhere would mean rebuilding this chrome to be fully intrinsic, which is
exactly the kind of broad, complexity-spreading change we want to avoid.

A decision is needed on how much text growth to support before the first iOS
submission.

## Decision drivers

* Respect Dynamic Type as an accessibility feature, not disable it.
* Keep the solution central and low-complexity. No per-widget scale overrides.
* Bound the layout-fix surface to a small, testable set of screens.
* Avoid a broad refactor of fixed-height chrome for an audience that is rare in
  practice for this app.

## Considered options

* **A. No clamp, support the full range.** Requires making all fixed-height
  chrome intrinsic.
* **B. Clamp the maximum scale to 1.3 at the app root, leave the lower bound at
  the system value.**
* **C. Disable text scaling entirely.**

## Decision outcome

Chosen option: **B**, clamp the upper bound to 1.3 app-wide via a single root
override, because it honours Dynamic Type up to a level the existing chrome can
absorb while keeping the change to one central, reversible line.

Implementation is one `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)`
wrapper at the app root (the `MaterialApp.router` builder in `lib/main.dart`).
Only the maximum is capped. Users who set smaller text keep it.

1.3 is a starting point, chosen to clear the tightest chrome (the 56px toolbar)
with margin. We will re-measure at 1.3 and revisit the cap if the live-drill
timeline or mini-player still need work, or if 1.3 proves too restrictive.

### Consequences

* Good: one central, reversible change. No scattered per-widget logic.
* Good: Dynamic Type is honoured up to 1.3 on every screen automatically.
* Good: bounds the layout-fix work to the live-drill timeline and mini-player,
  which are verified with tests at 1.3 rather than refactored blindly.
* Bad: users at the largest accessibility sizes get text capped at 1.3, below
  the full iOS range. Accepted for now and flagged for revisit.
* Bad: the cap hides, rather than fixes, overflow above 1.3. The fixed-height
  chrome stays fixed.

## Pros and cons of the options

### Option A — no clamp, support the full range
* Good: maximal accessibility.
* Bad: forces a broad refactor of fixed-height chrome across the app, the
  complexity spread we set out to avoid.

### Option B — clamp the maximum to 1.3 (chosen)
* Good: central, low-complexity, reversible, keeps accessibility up to 1.3.
* Bad: caps the largest accessibility sizes.

### Option C — disable text scaling
* Good: zero layout risk.
* Bad: ignores Dynamic Type, an accessibility regression. Discarded.

## Links

* Related ADRs: [ADR-0033](./0033-platform-adaptive-ui-on-ios.md) (the iOS
  adaptation work this continues)
* Related code: `lib/main.dart`, `lib/theme.dart`, `lib/views/phase_tile.dart`,
  `lib/views/phase_widget.dart`, `lib/views/phase_headers.dart`,
  `lib/views/drill_player/mini_round_row.dart`,
  `lib/views/drill_player/drill_mini_player.dart`
* External references: Flutter `MediaQuery.withClampedTextScaling`, [Apple — Dynamic Type](https://developer.apple.com/design/human-interface-guidelines/typography)
