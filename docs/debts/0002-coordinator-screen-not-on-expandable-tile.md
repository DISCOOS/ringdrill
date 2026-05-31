---
status: resolved
severity: medium
discovered: 2026-05-31
resolved: 2026-05-31
related_adrs: []
---

# DEBT-0002: Coordinator screen has not adopted `ExpandableTile` + `LiveAccent`

## What

The app has a canonical abstraction for "card row that expands with a live accent": `ExpandableTile` plus the design-token class `LiveAccent`. `program_view`, `station_list_view`, `team_screen`, and `drill_mini_player` all use it. `coordinator_screen.dart` is the holdout and still hand-rolls the old `ExpansionTile` + manual live-styling pattern, leaving a partial migration in the largest file in the project (1375 lines).

## Where

* `lib/views/coordinator_screen.dart`:
  * `_buildStationList` (line 906) and `_buildTeamList` (line 1116) are two near-identical `ExpansionTile` blocks of ~150 lines each; the only real difference is which columns appear in the title row.
  * Manual live styling with raw `isLive ? colorScheme.primaryContainer : null` at lines 934, 970–975, 1150–1156. The comments at lines 925–926 and 1144 state "Mirrors the live styling used in TeamScreen._ExerciseSection".
  * `ExpansibleController` pool with `_handleExpansionChange` (lines 78–115) plus the `dispose` cleanup at lines 1326–1339, to enforce one-row-open-at-a-time.
* Canonical pattern: `lib/views/widgets/expandable_tile.dart`, `lib/views/widgets/live_accent.dart`, used cleanly by `lib/views/team_screen.dart` (`_ExerciseSection`, line 114).

## Why it is debt

This is a partial migration. The live appearance is now defined in two places, so a future tweak to the "blue live" treatment must be applied to both `LiveAccent` and the coordinator's hand-rolled copy, and the copy is easy to miss. The duplicated `ExpansionTile` blocks and the controller pool add roughly 250–350 lines that the shared widget already handles, which inflates the hardest-to-read file in the codebase.

## Suggested fix

Replace both blocks with `ExpandableTile` and `LiveAccent.of(context, isLive: ...)`, following `team_screen._ExerciseSection`. Move the per-round column layout into the `title:`/`trailing:` slots. Retire the `ExpansibleController` pool in favour of parent-owned `expanded` state. `test/views/widgets/expandable_tile_test.dart` already provides regression coverage for the shared widget.

## Links

* Related ADRs: none
* Related code: `lib/views/coordinator_screen.dart`, `lib/views/widgets/expandable_tile.dart`, `lib/views/widgets/live_accent.dart`, `lib/views/team_screen.dart`
