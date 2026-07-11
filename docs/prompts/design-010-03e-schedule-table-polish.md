# Implement DESIGN-010 — Prompt 3e: schedule-table polish

You are working in the RingDrill repository, on `design-010` (3c/3d landed: the shared `ScheduleTable`/`ScheduleRow`/`PhaseHeaders`, with the coordinator/team-exercise/post/spill tables migrated and the width mode). This gathers the remaining schedule-table polish found in review. `docs/design/010-inline-preview-and-resolve-scope.md` is authoritative. Read `AGENTS.md` rule 9.

**No model, renderer, or schema change.** Views + test only.

## Fixes

### Fix 1. Center the column labels over their time columns

`PhaseHeaders` renders `ØVE`/`EVAL`/`RULL` centered within fixed `cellSize` cells, but `ScheduleRow` lays out its phase cells with the `PhasesWidget` dividers (a leading "|" between the label and phase 0, and "|" between phases). The header has no matching divider spacing, so its cells drift left of the row's time cells and the labels no longer sit above their column. Mirror the row's leading/inter-phase divider spacing in `PhaseHeaders` — at the same widths, taken from the same source `ScheduleRow`/`PhasesWidget`/`VerticalDividerWidget` uses (no hard-coded guess) — so each of `ØVE`/`EVAL`/`RULL` is centered over its time value (09:45 / 10:00 / 10:10). Must hold in both width modes (3d).

### Fix 2. Uppercase the first-column title

`PhaseHeaders` renders `title` as-is ("Plan", "Lag"). Uppercase it (`title.toUpperCase()`) → "PLAN" / "LAG", matching the already-uppercase `ØVE`/`EVAL`/`RULL` and the app's uppercase card headers. Applies to every caller. Done in the widget, not by editing ARB values.

### Fix 3. Team schedules use the Post viewer's schedule **card**

Two team surfaces render the schedule differently from the Post viewer's Tidsplan card:

* `team_screen.dart` (the team view that lists **expandable exercise tiles**) still renders it as `PhaseHeaders` + a `List.generate` of `Card`-wrapped `ScheduleRow`s (around lines 226–250) — the old per-round-card presentation.
* `team_exercise_screen.dart` (migrated in 3d) renders a bare bordered `ScheduleTable`, without the card/title.

Both should look like the Post viewer's schedule card: a `Card` with a `CardSectionHeader` titled "Tidsplan" wrapping the bordered `ScheduleTable`. Extract/reuse a shared **schedule card** (the `CardSectionHeader("Tidsplan")` + bordered `ScheduleTable` combination the Post/Spill viewers already build) so the Post viewer, the Spill viewer and both team surfaces render the exact same card — one definition, not four.

For `team_screen`, build `ScheduleTableRow`s from the same data it computes now (`roundIndex`, station label via `exercise.stationIndex(teamIndex, roundIndex)`, muted when no station that round, the existing `onTap`); drop the standalone `PhaseHeaders`. Behaviour-preserving. After this, `ScheduleRow`-in-`Card` schedule rendering should exist nowhere (grep to confirm), and every schedule table is inside the same shared card.

## Scope

Three commits.

### Commit 1. Header alignment + uppercase title

Add the matching divider/leading spacing to `PhaseHeaders` and uppercase the title.

Files: `lib/views/phase_headers.dart` (and `schedule_row.dart`/`phase_widget.dart` only if the divider width must be exposed to share). `flutter analyze` + `flutter test test/views/`. Commit: `fix(views): center schedule column headers over their times and uppercase the title`.

### Commit 2. Shared schedule card on the team surfaces

Extract/reuse a shared schedule card (`CardSectionHeader("Tidsplan")` + bordered `ScheduleTable`) and render it in `team_screen.dart` (replacing the `PhaseHeaders` + `Card(ScheduleRow)` list) and `team_exercise_screen.dart` (replacing its bare bordered table), so both team surfaces match the Post/Spill viewers' schedule card.

Files: a small shared schedule-card widget (or the Post viewer's existing one, lifted to a shared widget), `lib/views/team_screen.dart`, `lib/views/team_exercise_screen.dart`, `station_screen.dart`/`roleplay_screen.dart` if they adopt the lifted card. `flutter analyze` + `flutter test test/views/`. Commit: `refactor(views): render the team schedules in the shared schedule card`.

### Commit 3. Tests

* A width/offset assertion that a phase header cell's centre lines up with the corresponding time cell's centre, in both fill and shrink-wrap modes; the title renders uppercase.
* The team surfaces render their schedule in the shared schedule card (a "Tidsplan" `CardSectionHeader` + bordered `ScheduleTable`); no per-round `Card(ScheduleRow)` and no standalone `PhaseHeaders` remain; rows, muted rounds and tap targets unchanged.

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Files: test files under `test/views/`. Commit: `test(views): cover header alignment, uppercase title and the team-screen table`.

## Ground rules

* Reuse the row's actual divider width and `ScheduleTable`; do not duplicate a magic number or keep a parallel table.
* Header and rows stay in agreement in both width modes.
* Views + test only. No model, renderer, ARB, or schema change.
* Behaviour-preserving for the migrated team schedule; if it changes rows or tap behaviour, stop and report.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `dart build cli` succeeds.
3. Manual smoke: `ØVE`/`EVAL`/`RULL` sit centered above their time columns in every schedule table; the first column reads "PLAN"/"LAG"; both team surfaces show the shared schedule card (Card + "Tidsplan" title) like the Post/Spill viewers, not per-round cards or a bare table; header and rows agree on width in both modes.
4. `git diff --stat` touches `lib/views/…`, `test/…` only.
5. Clean tree.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes the schedule header now centers its phase labels over the time columns and uppercases the first-column title, and the team-screen schedule renders via the shared table — removing the last per-round-card schedule and completing the schedule-table unification.

DESIGN-010 is authoritative. The "|" separator evaluation and leaf fields (stage 4) are separate. If matching the row's divider spacing needs a larger change to `ScheduleRow`/`PhasesWidget`, stop and report.
