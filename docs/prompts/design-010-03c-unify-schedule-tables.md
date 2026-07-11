# Implement DESIGN-010 — Prompt 3c: unify the schedule tables

You are working in the RingDrill repository, on `design-010` (3b landed: the Post/Spill viewers). This is a **design follow-up** on 3b's schedule card (labelled "Tidsplan"), widened to a consistency pass over the app's round/phase-time tables. Several variants exist with divergent styling; the new `TeamScheduleTable` (3b) is the clearest departure — it uses `colorScheme.primary` text for the active row and lacks the house progress marking. Unify them on one shared design. `docs/design/010-inline-preview-and-resolve-scope.md` is authoritative. Read `AGENTS.md` rule 9.

**No model, renderer, or schema change.** Widget consolidation + styling.

## The variants (what must share the design)

The full phase-time tables are the same shape — N rows × (label + the three phase columns, `drill`/`eval`/`roll`), one row "current" — differing only in the row label and whether they are live or static:

1. **Exercise round table** — rows = rounds ("Runde N"), live (`ExerciseEvent`, progress fill), current round house-highlighted. Coordinator/exercise view.
2. **Team schedule** — rows = the posts a team visits (label = post name), live. Team view.
3. **Post schedule card** (labelled "Tidsplan") — rows = rounds at this post (label = team; muted + struck through when the post is not in use that round), static. `TeamScheduleTable`.
4. **Spill active-rounds card** (labelled "Når aktiv") — as 3, filtered to the rounds the marker is active. `TeamScheduleTable`.
5. **`MiniRoundRow`** — single current row, live. Mini-player.

**Out of scope (held for now):** the Coordinator "Rekkefølge" compact per-post team-order chip — a different, dense representation, left as-is.

## The house treatment

The current round is marked with a **background** (light/`blueAccent`), a blue **progress** fill on the phase cells (via `PhaseWidget`), and **white** time text — the treatment `MiniRoundRow`/`PhaseWidget`/`PhaseTile` already use. Not accent-coloured text.

## Settled decisions

* **Shared row widget, built on `PhaseWidget`.** Extract one schedule-**row** widget that both `MiniRoundRow` and the new schedule-**table** widget use (per your call: share the row design, don't fold the mini-player into the table). `PhaseWidget` is the building block for the phase cells and progress fill.
* **Active row only when running.** Highlight the current round only when the exercise is actually running (a live `ExerciseEvent`); no highlight otherwise. In the read views (Post/Spill), when running, the active round shows the house progress fill — this is the progress indicator `TeamScheduleTable` lacks today.
* **Muted + strikethrough** stays for rounds where a given post is not in use (Post/Spill only); other tables have no such rows.
* **"|" separator — deferred.** The shared row is `PhaseWidget`-based, which carries the dividers ("|") already seen on the live tables. Land it that way; do **not** gate this stage on the separator. It is to be evaluated once the progress fill is visible in the Post table — if it reads poorly there, making the divider optional is a small later change.
* **Coordinator "Rekkefølge" chip** untouched.

## Scope

Five commits.

### Commit 1. Shared schedule-row widget

Extract a schedule-row widget (built on `PhaseWidget`/`PhaseTile`): a label cell (house active fill: `blueAccent` bg, white bold text when current) + three phase cells (dividers + progress fill when live) + optional muted/struck-through state. Parameters: label, phase times, `current`, a live `ExerciseEvent` (progress) or static (a current flag, no animation), `muted`/`struckThrough`, optional `onTap`. Refactor `MiniRoundRow` to render via this row — behaviour-preserving for the mini-player.

Files: a new row widget (e.g. `lib/views/widgets/schedule_row.dart`), `mini_round_row.dart`, `phase_tile.dart`/`phase_widget.dart` if a small hook is needed. `flutter analyze` + `flutter test test/views/`. Commit: `refactor(views): extract a shared schedule row from MiniRoundRow/PhaseWidget`.

### Commit 2. Shared schedule-table widget

A table composing the shared row: a header (label column + the three phase columns) then one row per entry. Parameters: rows (label + times + per-row `current`/`muted`+`struck`/`onTap`), the header's first-column label (rounds vs team, resolved to the right ARB string by the caller), and the live-or-static feed.

Files: a new table widget (e.g. `lib/views/widgets/schedule_table.dart`). `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): add a shared schedule table built on the shared row`.

### Commit 3. Migrate the Post/Spill read views

Replace `TeamScheduleTable` in the Post schedule and Spill active-rounds cards with the shared table: the active round gets the house highlight + progress fill when running (none otherwise), post-not-in-use rounds stay muted + struck through. Retire `TeamScheduleTable`'s bespoke `_TableRow` styling.

Files: `station_screen.dart`, `roleplay_screen.dart`, remove/replace `team_schedule_table.dart`. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): render the Post/Spill schedule via the shared table`.

### Commit 4. Migrate the live exercise/team tables

Point the exercise round table and the team-view table at the shared table (live mode, reusing the shared row). If they are already one widget, fold that widget's rendering onto the shared row/table; if two, migrate both. Leave the Coordinator "Rekkefølge" chip untouched.

Files: the exercise/team schedule call sites (`coordinator_screen.dart` round table, `team_exercise_screen.dart`, `team_screen.dart` as applicable). `flutter analyze` + `flutter test test/views/`. Commit: `refactor(views): render the exercise and team schedules via the shared table`.

### Commit 5. Tests + cleanup

Cover: the active row highlights (bg + white text + progress) only when running and is plain otherwise; a muted+struck row renders in the read views; the live exercise/team tables and the mini-player row are unchanged in behaviour; no bespoke schedule styling remains outside the shared widgets.

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Files: test files under `test/views/`. Commit: `test(views): cover the shared schedule row and table`.

## Ground rules

* One row, one table — reuse over re-implement; no surface keeps a bespoke schedule style after this (except the excepted Coordinator chip).
* Views + test only. No model, renderer, ARB, or schema change (`make i18n` not needed unless a header string moves).
* Behaviour-preserving for the live tables and the mini-player — their existing tests are the regression net; if a migration would change their output, stop and report.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `dart build cli` succeeds.
3. Manual smoke: the Post/Spill schedule now marks the current round like the exercise schedule (blue bg, white text, progress fill when running), non-participating rounds muted + struck; the exercise, team, post, spill tables and the mini-player row are visually one design; the Coordinator "Rekkefølge" chip is unchanged.
4. `git diff --stat` touches `lib/views/…`, `test/…` only.
5. Clean tree.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes the round/phase-time tables now share one row (built on `PhaseWidget`) and one table widget — the Post/Spill schedules gaining the house active-round highlight and progress fill, the mini-player and live tables behaviour-preserved, and the Coordinator "Rekkefølge" chip left as the deliberate exception; the "|" separator rides along from the shared row and is to be evaluated once visible.

DESIGN-010 is authoritative. Leaf fields are **stage 4**. If migrating a live table would change its behaviour or the shared row can't be built on `PhaseWidget` without a larger refactor, stop and report rather than forcing it.
