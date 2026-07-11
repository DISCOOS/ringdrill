# Implement DESIGN-010 — Prompt 3f: coordinator team-detail schedule → shared card

You are working in the RingDrill repository, on `design-010`. A tiny follow-up finishing the schedule unification: `coordinator_screen.dart`'s `_buildTeamDetail` (the team-detail rows in the coordinator's team list) still renders its per-round schedule as `ScheduleRow`s wrapped in per-round `Card`s — the last `ScheduleRow`-in-`Card` occurrence, left out of 3e (which named only `team_screen.dart` and `team_exercise_screen.dart`). Migrate it to the shared `ScheduleCard`. `docs/design/010-inline-preview-and-resolve-scope.md` is authoritative. Read `AGENTS.md` rule 9.

**No model, renderer, or schema change.** One migration, mirroring 3e.

## What to change

Replace `_buildTeamDetail`'s `PhaseHeaders`/`ScheduleRow`-in-`Card` schedule with the shared `ScheduleCard` (`CardSectionHeader` + bordered `ScheduleTable`), exactly as `team_exercise_screen.dart` was migrated in 3e: build `ScheduleTableRow`s from the same data it computes now (round index, station label via the rotation helpers, muted rounds, existing `onTap`), pick the same width mode the other team surfaces use. Behaviour-preserving.

This is **not** the coordinator "Rekkefølge" chip — that compact per-post team-order chip stays out of scope, as before. Only `_buildTeamDetail`'s round schedule changes.

After this, a repo-wide grep confirms no `ScheduleRow`-wrapped-in-`Card` schedule rendering remains anywhere.

## Scope

Two commits.

### Commit 1. Migrate `_buildTeamDetail`

Files: `lib/views/coordinator_screen.dart`. `flutter analyze` + `flutter test test/views/`. Commit: `refactor(views): render the coordinator team-detail schedule via the shared card`.

### Commit 2. Test

The coordinator team-detail renders its schedule via `ScheduleCard`/`ScheduleTable` (no `ScheduleRow`-in-`Card`, no standalone `PhaseHeaders`); rows, muted rounds and tap targets unchanged. A grep-style assertion or a check that the team-detail schedule uses the shared card.

Files: test files under `test/views/`. `flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Commit: `test(views): cover the coordinator team-detail shared card`.

## Ground rules

* Reuse `ScheduleCard`/`ScheduleTable`; no parallel table, no bespoke schedule styling left in the coordinator team-detail.
* Views + test only. No model, renderer, ARB, or schema change.
* Behaviour-preserving; if the migration changes rows or tap behaviour, stop and report.
* Leave the coordinator "Rekkefølge" chip untouched.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `dart build cli` succeeds.
3. Manual smoke: the coordinator's team-detail schedule now looks like the other schedule surfaces (shared card), not per-round cards; the "Rekkefølge" chip is unchanged.
4. `git diff --stat` touches `lib/views/…`, `test/…` only.
5. Clean tree.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes the coordinator team-detail schedule now renders via the shared `ScheduleCard`, removing the last `ScheduleRow`-in-`Card` schedule; the "Rekkefølge" chip stays as the deliberate exception.

DESIGN-010 is authoritative. If `_buildTeamDetail`'s data does not map cleanly onto `ScheduleTableRow`, stop and report.
