# Implement: keep master and detail in sync on any redirect

You are working in the RingDrill repository, on `design-010`. A wide-shell correctness fix: when a redirect changes the **detail** target (a cross-entity link, e.g. the Spill viewer's post-context card opening its Post, or any card that calls `ContextSheet.replace`/`show`), the **master** pane must follow — the right segment selected and the right row highlighted — so master and detail never drift out of sync. Read `AGENTS.md` rule 9.

**Views only, wide layout only.** No model/renderer/schema change.

## The bug

Selecting a link that targets a different entity loads the correct detail view, but the master stays where it was: on the previous segment, with the previous (or no) row highlighted. The user sees the right detail while the list beside it shows something unrelated — and the per-segment selection memory can even revert the detail on the next rebuild. It happens anywhere a redirect sets a new `ContextSheetTarget` of a different kind than the active segment (the Spill → Post post-context card is one instance; there are others).

## Expected behaviour

A redirect that changes the detail target is a navigation of the **whole** master/detail, not just the detail pane. On any target change (via `ContextSheet.show` / `ContextSheet.replace` / `MasterDetailScope.setTarget`) in the wide layout:

* **Switch the master to the segment that owns that target type**, and
* **select/highlight that item** in the master list, recording it as that segment's selection (the per-segment memory from `design-shell-collapsible-master-followup-fixes.md`).

So opening a Post from the Spill viewer switches the master to the **Poster** segment with that station selected; the list and the detail always agree.

Target → segment map (centralize it in one helper, don't scatter `is StationSheetTarget` checks):

* `ExerciseSheetTarget` → Øvelser
* `StationSheetTarget` → Poster
* `RoleSheetTarget` → Spill
* `TeamSheetTarget` / `TeamOverviewSheetTarget` → Lag
* `BriefSheetTarget` → no segment (the brief is a modal / not a master-detail selection) — leave the master untouched.

## Implementation sketch

* Add a single `segmentForTarget(ContextSheetTarget)` helper returning the owning `ProgramSegment` (or null for `BriefSheetTarget`).
* When the shared target changes in the wide layout (the `MainScreen`/`ProgramPageControllerBase` side that already owns the segment state, the per-segment selection memory and `firstDetailTarget`), derive the segment from the new target: if it differs from the active segment, switch the active segment; either way, record the target as that segment's remembered selection so the master highlights it and does not revert it on the next rebuild.
* Make this the authority on a redirect: the target→segment sync sets the selection, so the auto-select-first and per-segment memory must not immediately overwrite it (order the updates so the redirect wins; guard against a feedback loop between "segment changed → restore memory" and "target changed → set segment").
* Narrow layout is unaffected (no master/detail; the detail is a full-screen sheet).

Once this lands, the Spill post-context card's navigation (and every other cross-entity redirect) lands correctly with the master in sync — no per-card handling needed.

## Scope — two commits

### Commit 1. Target → master sync

`segmentForTarget` helper + the `MainScreen`/`ProgramPageControllerBase` wiring so a target change switches the master segment and selects the item, coordinated with the existing per-segment memory / auto-select.

Commit: `fix(shell): sync the master segment and selection to the detail target`.

### Commit 2. Tests

* Setting a `StationSheetTarget` while the master is on the Spill segment switches the master to Poster and selects that station (and it is not reverted on rebuild).
* Each target type maps to its segment; `BriefSheetTarget` leaves the master untouched.
* An explicit in-segment selection still works and is remembered (no regression to the per-segment memory).
* Narrow layout unaffected.

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Commit: `test(shell): cover master/detail sync on cross-segment redirects`.

## Ground rules

* Views + test only; wide layout only; narrow unchanged.
* One `segmentForTarget` helper — no scattered target-type checks.
* Compose with (don't fight) the per-segment selection memory and auto-select-first; the redirect is the authority when it fires.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `dart build cli` succeeds.
3. Manual smoke (wide): from the Spill viewer, open the post-context card's Post → the master switches to Poster with that station highlighted and the detail shows the Post viewer, staying put (no revert). Repeat for other cross-entity links. Switching segments manually still restores each segment's own last selection.
4. `git diff --stat` touches `lib/views/…`, `test/…` only.
5. Clean tree.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). Master and detail stay in sync on every redirect; the mapping lives in one helper.
