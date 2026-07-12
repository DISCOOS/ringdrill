# Fix: collapsible-master-pane follow-up regressions

You are working in the RingDrill repository, on `design-010`. Two regressions from the collapsible-master-pane work (`design-shell-collapsible-master-pane.md`). Read `AGENTS.md` rule 9.

**Views only, wide layout only.** No model/renderer/schema change.

## Fix A — Preserve the selected row per segment

In the wide layout, selecting a program segment button (Øvelser / Poster / Spill / Lag) **resets the selected row**: the auto-select re-fires on every segment switch and overwrites the shared detail target with that segment's *first* item, discarding any row the user had already picked in that segment. Switching away and back loses the selection. Not expected — auto-select-first is only meant to populate a segment that has **no** valid selection yet.

Expected:

* **Remember the selection per segment** for the session. Switching to a segment restores its remembered selection when the item still exists (not deleted/reordered away).
* **Auto-select the first item only when the segment has no valid remembered selection** (first visit this session, or the remembered item is gone). The original feature is preserved for a freshly opened segment.
* **Never override an explicit pick**; re-tapping the already-active segment is a no-op for selection. Narrow is unaffected.

Implementation: wherever the auto-select was wired (the `MainScreen`/program-view side that reads the active segment and sets the shared `ContextSheetTarget`), replace "on segment change → set `firstDetailTarget`" with a per-segment remembered target — a `Map<segment, ContextSheetTarget?>` (updated when the user selects a row), restored on switch, falling back to `firstDetailTarget` only when there is no valid memory. Guard against re-running on rebuilds that are not real segment changes. If a segment/selection notifier already owns this (e.g. a `ProgramPageController`), hang the memory there rather than adding parallel state.

## Fix B — The Lag detail still shows the close-X, not the sidebar toggle

`team_screen.dart` (the **Lag** detail — "Lag N" with the team's exercise list, reached from the Lag segment) was **missed** in the leading migration: it still hardcodes `IconButton(Icons.close)` (around line 47) instead of the shared `MasterDetailLeading`. So in the wide layout it shows the close-X, and pressing it closes the detail with no way to bring the master back (the toggle is the only re-open affordance now). `team_exercise_screen.dart` (the team *player*) was migrated correctly — this is the sibling screen that was overlooked.

Fix: replace `team_screen.dart`'s hardcoded close leading with `MasterDetailLeading`, passing the same `onClose` (the existing `MasterDetailScope.maybeOf(context) != null ? ContextSheet.of(context).close() : Navigator.pop(context)` behaviour) — identical to how the other detail screens adopt it. Then it shows the `sidebar_left` toggle in the wide layout and the close-X only in narrow, like the rest.

While here, grep for any *other* detail screen still hardcoding `IconButton(Icons.close)` as its AppBar `leading` under a possible `MasterDetailScope`, and migrate it too — complete the goal, don't leave a sixth one for another round.

## Scope — three commits

### Commit 1. Per-segment selection memory (Fix A)

The auto-select wiring restores a segment's remembered selection on switch and only auto-selects the first item when there is none.

Commit: `fix(shell): remember the selected row per segment instead of resetting it`.

### Commit 2. Lag detail uses the shared leading (Fix B)

`team_screen.dart` (and any other overlooked detail screen) adopts `MasterDetailLeading`, so the wide layout shows the sidebar toggle and narrow keeps the close-X.

Commit: `fix(shell): use the shared detail leading in the team (Lag) detail view`.

### Commit 3. Tests

* Selecting a non-first row in a segment, switching to another segment, then back, keeps the non-first row selected; a first-visit segment still auto-selects its first item; re-tapping the active segment does not change the selection; a remembered item that no longer exists falls back to the first.
* The Lag detail (`team_screen`) shows the `sidebar_left` toggle under a `MasterDetailScope` and the close-X without one — same assertion the other detail screens already have.

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Commit: `test(shell): cover per-segment selection memory and the Lag detail leading`.

## Ground rules

* Views + test only; wide layout only; narrow unchanged (close-X stays there).
* Preserve auto-select-first for segments with no valid selection.
* One shared `MasterDetailLeading` — do not reintroduce bespoke close/toggle logic.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `dart build cli` succeeds.
3. Manual smoke (wide): pick row #3 in Øvelser, switch to Poster (first post shows), back to Øvelser → #3 still selected; a never-visited segment shows its first item; re-tapping the current segment does nothing. Open a Lag item → its detail shows the `sidebar_left` toggle (not a close-X), and toggling collapses/restores the master. Narrow: close-X unchanged everywhere.
4. `git diff --stat` touches `lib/views/…`, `test/…` only.
5. Clean tree.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9).
