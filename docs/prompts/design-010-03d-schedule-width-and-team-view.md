# Implement DESIGN-010 — Prompt 3d: schedule-table width mode + team-view migration

You are working in the RingDrill repository, on `design-010` (3c landed: the shared `ScheduleRow`/`ScheduleTable`, with the Post/Spill and exercise schedules migrated). Three issues surfaced in review. Fix them. `docs/design/010-inline-preview-and-resolve-scope.md` is authoritative. Read `AGENTS.md` rule 9.

**No model, renderer, or schema change.** Widget sizing + one migration.

## Issues

1. **The table always expands rows to full parent width.** The Coordinator round table needs to shrink-wrap to its content width, the way it did before 3c. It must be able to minimize.
2. **Header and rows disagree on width.** `PhaseHeaders` (the header bar) renders at content width while `ScheduleRow` fills the parent, so the dark header bar is narrower than the rows. **Both** the header and the rows must follow the **same** width behaviour, driven by one table-level parameter.
3. **The team (Lag) view still uses the old presentation.** It renders `ScheduleRow`s wrapped in per-row `Card`s (`team_exercise_screen.dart`) rather than the shared `ScheduleTable`. Migrate it to `ScheduleTable`.

## What to change

* **Add a width mode to `ScheduleTable`** — a single parameter (e.g. `fillWidth: bool`, or a `WidthMode` enum) that controls whether the whole table shrink-wraps to content or expands to the parent width. `ScheduleRow` already supports both via `mainAxisSize` + a null/non-null `labelWidth`; `PhaseHeaders` must be taught to honour the **same** mode. `ScheduleTable` passes the one mode to both header and rows so they are always the same width.
* **Coordinator round table → minimized.** Pass the content-width (shrink-wrap) mode so it looks as it did before 3c.
* **Post/Spill bordered cards → full width** (fill the card), header included — so the header bar spans the same width as the rows there too, fixing issue 2 in that surface.
* **Migrate the team (Lag) view** (`team_exercise_screen.dart`) from `ScheduleRow`-in-`Card`s to the shared `ScheduleTable`, choosing the width mode that matches its surface (content-width like the coordinator, unless the card layout clearly needs full width). Its `PhaseHeaders` is then the table's header, not a separate one.

## Scope

Three commits.

### Commit 1. Width mode on the shared table, header and rows in agreement

Add the width-mode parameter to `ScheduleTable` and apply it to both `PhaseHeaders` and every `ScheduleRow`, so the header bar and the rows are always the same width in both modes. Teach `PhaseHeaders` the mode if it does not already shrink/expand to match.

Files: `lib/views/widgets/schedule_table.dart`, `lib/views/phase_headers.dart`, `lib/views/widgets/schedule_row.dart` (only if a hook is missing). `flutter analyze` + `flutter test test/views/`. Commit: `fix(views): give the schedule table a width mode applied to header and rows`.

### Commit 2. Coordinator round table minimized

Pass the shrink-wrap (content-width) mode at the coordinator round-table call site so it minimizes as before 3c.

Files: `lib/views/coordinator_screen.dart`. `flutter analyze` + `flutter test test/views/`. Commit: `fix(views): restore the coordinator round table's minimized width`.

### Commit 3. Migrate the team view to the shared table

Replace the team view's `ScheduleRow`-in-`Card` rendering with `ScheduleTable` (its `PhaseHeaders` becomes the table header), picking the width mode that suits the surface.

Files: `lib/views/team_exercise_screen.dart` (and `team_screen.dart` if it shares the code). `flutter analyze` + `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Commit: `refactor(views): render the team schedule via the shared table`.

## Tests

* The table in shrink-wrap mode sizes header **and** rows to content (the header bar is not narrower than the rows); in fill mode both span the parent — a width-parity assertion across the header and a row in each mode.
* The coordinator round table renders in shrink-wrap mode.
* The team view renders via `ScheduleTable` (no `ScheduleRow`-in-`Card`), behaviour-preserving for its content.

## Ground rules

* One width parameter drives header + rows together — do not leave two independent sizing paths. Reuse `ScheduleRow`'s existing `mainAxisSize`/`labelWidth` support.
* Views + test only. No model, renderer, ARB, or schema change.
* Behaviour-preserving for the live tables and the Post/Spill cards otherwise; if the team migration changes its content, stop and report.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `dart build cli` succeeds.
3. Manual smoke: the Coordinator round table is minimized (not stretched) and its header bar matches the row width; the Post/Spill cards fill the card with header and rows the same width; the team (Lag) view uses the shared table and looks consistent with the others.
4. `git diff --stat` touches `lib/views/…`, `test/…` only.
5. Clean tree.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes the schedule table now has one width mode applied to both the header and the rows (fixing the narrow-header mismatch), the coordinator round table minimizes as before, and the team view renders through the shared table.

DESIGN-010 is authoritative. The Coordinator "Rekkefølge" chip stays out; leaf fields are stage 4. If `PhaseHeaders` cannot honour the width mode without a larger change, stop and report.
