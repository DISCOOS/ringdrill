---
status: accepted            # proposed | accepted | deprecated | superseded by ADR-NNNN
date: 2026-06-04            # date of the decision
deciders: ["kengu"]        # who signed off
consulted: []               # who was asked for input
informed: []                # who was kept in the loop
---

# ADR-0037: Size text for legibility on iOS — tighten the baseline type scale and clamp scaling at 1.3

## Context and problem statement

A first run of the iOS app in the simulator showed text reading too large
**at the default system text size** (`textScaler` 1.0), before any Dynamic Type
enlargement. So there are two distinct problems on one axis, text sizing:

1. **Baseline size at 1.0.** About 58 hardcoded `fontSize:` values (mostly 18,
   20 and 24) are scattered across the views, bypassing the theme type scale,
   and `GoogleFonts.robotoFlexTextTheme()` has a large optical size that reads
   heavy against iOS's SF Pro. Long Norwegian compound words on a narrow phone
   amplify it.
2. **Growth above 1.0.** iOS Dynamic Type (and the Android font-size setting)
   let users enlarge text up to roughly 310%. Flutter surfaces this as
   `MediaQuery.textScaler` and Material honours it automatically. The app
   carries tight fixed-height chrome that cannot survive extreme scales without
   a heavy refactor: AppBar toolbars at 56 and 72, the two-line `SheetTitle`
   inside 72, the live-drill timeline rows (`phase_tile`, `phase_widget`,
   `phase_headers`, `mini_round_row`) fixed at 24 and 32, and the drill
   mini-player bar.

Both must be settled before the first iOS submission. They are two facets of
one decision (how text is sized), so this ADR owns both rather than splitting
them. A clamp alone is necessary but not sufficient: it does nothing for the
default-size problem, which is what the user actually sees first.

## Decision drivers

* Text must be legible and feel native on iOS, starting at the default size.
* Keep typography central and low-complexity. No scattered magic numbers, no
  per-platform type branching.
* Respect Dynamic Type as an accessibility feature, do not disable it.
* Bound the layout-fix surface to a small, testable set of screens.
* Low risk for Android, the primary distribution channel.

## Considered options

For the baseline (part 1):

* **A1. Leave hardcoded sizes, tune individually.** Spreads more magic numbers.
* **A2. Centralise: migrate hardcoded sizes to named `textTheme` styles and
  tighten that one theme.** One place controls density.

For scaling (part 2):

* **B1. No clamp, support the full accessibility range.** Forces the
  fixed-height chrome to be rebuilt intrinsic.
* **B2. Clamp the maximum scale to 1.3 at the app root.**
* **B3. Disable text scaling entirely.**

## Decision outcome

**Part 1 — tighten and centralise the baseline.** Choose **A2**. Migrate the
in-scope hardcoded `fontSize:` values to named `textTheme` styles and define one
slightly tightened `textTheme` in `lib/theme.dart`, so density is controlled
from a single file. The exact sizes and the font choice (keep RobotoFlex versus
a tighter alternative) are confirmed by on-device measurement / A/B during
implementation. The accepted direction is "centralise and tighten", the precise
numbers are tuning, not a re-decision.

Scope of the migration is in the appendix. Excluded on purpose: the `BriefTheme`
token set and its use in the brief view ([ADR-0023](./0023-brief-theme-tokens.md)
owns brief typography); the `FittedBox`-wrapped number badges (their `fontSize`
is nominal before scale-down); and the low-priority map overlay chips.

**Part 2 — clamp scaling.** Choose **B2**. One
`MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)` wrapper at the app root
(the `MaterialApp.router` builder in `lib/main.dart`). Only the maximum is
capped, users who set smaller text keep it.

**Ordering.** Do part 1 first, then part 2, then re-check whether 1.3 is still
the right cap against the tightened baseline. A smaller base means 1.3× clears
the tight chrome with even more margin, so the cap may be relaxable later. No
change to the cap is made now.

### Consequences

* Good: text is sized for legibility from the default up, not just bounded
  against extreme growth.
* Good: typography lives in one theme, so future density changes are one edit
  and Dynamic Type behaves predictably.
* Good: the clamp is one central, reversible line, and Android plus the
  desktop/web targets are essentially untouched.
* Good: the layout-fix surface above 1.0 is bounded to the live-drill timeline
  and mini-player, verified with tests rather than refactored blindly.
* Bad: the migration touches many files. It is mechanical and net-reduces
  complexity, but it is broad, so it is staged with the most visible surfaces
  first.
* Bad: users at the largest accessibility sizes get text capped at 1.3, below
  the full iOS range. Accepted for now and flagged for revisit.
* Bad: the cap hides, rather than fixes, overflow above 1.3. The fixed-height
  chrome stays fixed.

## Pros and cons of the options

### A1 — tune hardcoded sizes individually
* Good: smallest immediate diff.
* Bad: leaves typography uncentralised and adds more magic numbers, the spread
  we want to avoid.

### A2 — centralise into a tightened textTheme (chosen)
* Good: one source of truth for density, also fixes Dynamic Type consistency.
* Bad: broad mechanical migration across many files.

### B1 — no clamp, full range
* Good: maximal accessibility.
* Bad: forces a broad refactor of fixed-height chrome.

### B2 — clamp the maximum to 1.3 (chosen)
* Good: central, low-complexity, reversible, keeps accessibility up to 1.3.
* Bad: caps the largest accessibility sizes.

### B3 — disable scaling
* Good: zero layout risk.
* Bad: ignores Dynamic Type, an accessibility regression. Discarded.

## Appendix — baseline migration inventory

Hardcoded `fontSize:` occurrences, grouped by role and mapped to a target. The
hardcoded values do not sit on the Material 3 steps (for example 20 mapped to
`titleLarge` would grow to 22), so the targets are a small set of tightened
named styles, not a blind 1:1 map.

| Role (current size)            | Sites                                                                 | Target style            |
|--------------------------------|-----------------------------------------------------------------------|-------------------------|
| Detail/screen header (24 bold) | `station_screen` ×2, `team_exercise_screen` ×2                        | `titleLarge` (~20)      |
| Section title (20 bold)        | `settings_page` ×3, `web/settings_page` ×1                            | `titleMedium`           |
| Sub-header (18 bold)           | `teams_view`, `team_screen`, `team_station_widget`, `main_screen` drawer | `titleMedium`/`titleSmall` |
| Live-drill accent (18)         | `coordinator_screen` ×6, `program_view:945`, `phase_tile:47`          | new `drillAccent` style |
| Inline body (16)               | `exercise_form_screen:206`, `expandable_tile:169`                     | `bodyLarge`             |
| Secondary/caption (14/13/12)   | `mini_round_row` ×5, `roster_view:214`, `cast_roster_sheet`, `cast_picker_sheet`, `expandable_tile:178` | `bodyMedium`/`bodySmall` |

Proposed starting scale in `lib/theme.dart` (confirm on device): `titleLarge`
22→20, `titleMedium` 16, `titleSmall` 14, `bodyLarge` 16→15, `bodyMedium` 14,
`bodySmall` 12, plus one `drillAccent` style replacing the `fontSize: 18` +
`accent.foreground` pattern in the player.

## Links

* Related ADRs: [ADR-0023](./0023-brief-theme-tokens.md) (BriefTheme owns brief
  typography, excluded from this migration), [ADR-0033](./0033-platform-adaptive-ui-on-ios.md)
  (the iOS adaptation work this continues)
* Related code: `lib/theme.dart`, `lib/main.dart`, `lib/views/coordinator_screen.dart`,
  `lib/views/settings_page.dart`, `lib/views/station_screen.dart`,
  `lib/views/team_exercise_screen.dart`, `lib/views/drill_player/mini_round_row.dart`,
  `lib/views/phase_tile.dart`
* External references: Flutter `MediaQuery.withClampedTextScaling`, [Apple — Dynamic Type](https://developer.apple.com/design/human-interface-guidelines/typography)
