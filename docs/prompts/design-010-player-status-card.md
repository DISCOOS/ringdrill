# Implement DESIGN-010 follow-up: the player status card

You are working in the RingDrill repository, on `design-010`. This is a **standalone follow-up** (not a DESIGN-010 stage, and independent of the schedule-table polish `03e` and the leaf-fields stage 4): improve the running-exercise **status** shown in the four player/overview surfaces. Today it shows only a countdown + phase (e.g. "20:45 / VENT / ferdig 10:45") — thin, and it breaks visually before the exercise starts (a long `mm:ss` cramped against phase/now-next). Replace it with one shared status card with two states. `docs/design/010-inline-preview-and-resolve-scope.md` is authoritative; the visual spec is `docs/design/mockups/running-status-post-lag.html` — **build to it**.

**No model or schema change.** Views + l10n + test. All data comes from the existing `ExerciseEvent` (phase, countdown, running/pending) and the rotation helpers (`Exercise.schedule` + `Exercise.teamIndex`/`stationIndex`) — no new data.

## The card: two states

**Not started (pending).** A simple, centered pre-start block: a large **countdown to start spelled out with units** — "20 timer 45 min" (drop zero units: "45 min", "2 timer") rather than an ambiguous `hh:mm` clock, since the time to start can be hours or days — then "TIL START" and a subline (start time + round count / role context). No phase, no now/next. This is what fixes the cramped long-countdown case, and now that the pre-start block is roomy there is space for the spelled-out form.

**Running.** The rich block:
* Countdown line: big number + big bold **phase name** (`ØVE`/`EVAL`/`RULL`/…), with small "min igjen av" between them ("5 min igjen av **ØVE**"). The whole line must stay on **one line** — "min igjen av" never wraps — and must fit the available width beside the meta cell: fit the line to width (scale the number/phase down via the same `TextPainter` measured fit, or wrap the line in a `FittedBox`/`BoxFit.scaleDown`) so it neither wraps nor overflows, at any width or text scale.
* A meta cell to the right, separated by a thin vertical divider: "Runde N av M" on top, "ferdig HH:MM" below.
* A progress bar (phase progress), `ExerciseEvent`-driven — the same source the schedule table's active-round fill uses.
* A **now/next** strip: two equal, centered cells split by a divider. Each cell is **two rows** — a label row, then an **auto-sized value** row. For a "next" cell the **time is inline on the label row** ("Neste · 11:15" — no "kl" prefix), not a separate line, so both cells are label / value and their **values align vertically**. The value is an optional number **badge** + text.
  * **Auto-size the value in both cells** between a max and a min font size: pick the largest font in `[min, max]` that fits the cell; when even the minimum does not fit, render at the minimum and **ellipsize** (never shrink below the floor, never clip mid-word). Use a `TextPainter`-**measured** fit (the Post card alignment already measures text this way), not a floor-less `FittedBox`/`BoxFit.scaleDown`; **do not add an `auto_size_text` dependency**. Short values (`Lag 1`, `ØVE`) render large and fill the cell; long ones (a post name like `Fisker (Angler)`) shrink and wrap cleanly. Both cells share the same min/max so the pair reads as matched.
  * The **now** value is distinguished by the **accent (live) colour**, not by a larger size — sizing is symmetric so the two values align.
  * **Labels are plain "Nå" / "Neste"** — no "post"/"lag"/"aktive" qualifier (the badge/value already conveys the type). The Coordinator is the exception: two forward cells that must be distinguished, "Neste fase" and "Neste runde".

The state is chosen by `ExerciseEvent` (pending → not-started, running → running).

## Now/next per surface

* **Coordinator** (whole exercise): the current phase is already in the countdown, so there is no "Nå" cell. Two **forward-looking** cells: "Neste fase" = next phase + time, "Neste runde" = next round + its start time.
* **Post player** (a station): "Nå" = the team at this post now; "Neste" = next team + time.
* **Lag player** (a team): "Nå" = current post (badge + name); "Neste" = next post (badge + name) + time.
* **Spill player** (a marker): "Nå" = the team at the marker's post now; "Neste" = next team + time. When the marker's post has no team that round, show "Ikke aktiv nå".

Post identifiers use the shared **number badge** (e.g. "2a"), not baked into the name or the title (the app's norm — see the badge used in the coordinator "Rekkefølge" chip). Team/phase values are plain.

## Scope

Three commits.

### Commit 1. Shared status-card widget

Build one `PlayerStatusCard` (name your own) with the two states from the mockup: the pre-start block and the running block (countdown + meta cell + divider + progress bar + a `nowNext` slot taking two cells). Each now/next cell: centered, two rows — a label row (time inline for a "next" cell) then an auto-sized value with an optional leading badge; the two cells' values align. Drive phase/countdown/progress/state from `ExerciseEvent`. Locate today's status/countdown block (the mini-player/coordinator countdown) and consolidate onto this one widget rather than leaving parallel implementations.

Files: a new status-card widget under `lib/views/…`, ARB (`Runde N av M`, `TIL START`, `min igjen av`, `ferdig`, the now/next labels), regenerated localizations. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): add a shared player status card with pre-start and running states`.

### Commit 2. Wire the four surfaces with role-specific now/next

Render the card in the coordinator, Post player, Lag player and Spill player, each computing its now/next from the rotation helpers (`Exercise.schedule` + `teamIndex`/`stationIndex`) — phase for the coordinator, team-at-post for Post/Spill (with Spill's "Ikke aktiv nå"), post for Lag. Use the number badge for post codes and drop the code from the surface title where it was baked in.

Files: `lib/views/coordinator_screen.dart`, `lib/views/station_screen.dart`, `lib/views/team_exercise_screen.dart`, `lib/views/roleplay_screen.dart` (and the mini-player/countdown widget if that is where the block lives). `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): show the status card with role-specific now/next in every player`.

### Commit 3. Tests

* State switch: a pending `ExerciseEvent` renders the pre-start block (no phase/now-next); a running one renders the countdown + meta + progress + now/next.
* Each surface's now/next resolves from the rotation helpers: coordinator = phase→next phase; Post/Spill = team-at-post now→next (Spill shows "Ikke aktiv nå" when the post has no team that round); Lag = post now→next.
* A long post name shows via badge + wrapped/`FittedBox` name (not truncated to "…"); the countdown/progress track the `ExerciseEvent`.

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Files: test files under `test/views/`. Commit: `test(views): cover the player status card states and per-role now/next`.

## Ground rules

* Build to the mockup; reuse the `ExerciseEvent`, the rotation helpers, the number-badge component and (for the running progress) the same phase-progress source the schedule table uses. One shared status card — no parallel status blocks left behind.
* Views + l10n + test only. No model, renderer, or schema change. `make i18n` on ARB changes.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; `make i18n` only on ARB change; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `make i18n` idempotent; `dart build cli` succeeds.
3. Manual smoke: before start, every surface shows the simple pre-start countdown (no cramping); while running, the countdown reads "X min igjen av <PHASE>", the meta shows "Runde N av M / ferdig HH:MM", the progress bar tracks the phase, and the now/next is right for the role (coordinator phase, Post/Spill team, Lag post) with post number badges and un-truncated names; Spill shows "Ikke aktiv nå" on a round its post is unused.
4. `git diff --stat` touches `lib/views/…`, `lib/l10n/…`, `test/…` only.
5. Clean tree; localizations committed with ARB changes.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes the four player/overview surfaces now share one status card with a simple pre-start state and a rich running state (phase countdown, round/finish meta, progress, role-specific now/next), driven by `ExerciseEvent` and the rotation helpers, with post numbers as badges.

The mockup is the visual authority. Independent of `03e` (table polish) and stage 4 (leaf fields). If today's status block cannot be consolidated onto one shared card without a larger refactor of the mini-player, stop and report.
