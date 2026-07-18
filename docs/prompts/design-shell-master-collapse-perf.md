# Fix: keep the master pane mounted across collapse (toggle perf)

You are working in the RingDrill repository, on `design-010`. A performance fix for the collapsible master pane (`design-shell-collapsible-master-pane.md`). Read `AGENTS.md` rule 9.

**Views only, wide layout only.** No model/renderer/schema change.

## The problem

Toggling the master pane is slow — worst when re-expanding. In `wide_shell.dart` the collapsed and expanded states build **two different trees**: collapsed is `Row(rail, Expanded(MasterDetailPane()))`, which does **not** build the master column at all — and the master column hosts `tabs`, the `IndexedStack` of all four segment pages (Øvelser/Poster/Spill/Lag). So each toggle disposes and later recreates that whole subtree: every segment page re-runs `initState` (service loads, list building), controllers are rebuilt, scroll positions lost. Re-expanding pays the full rebuild.

## The fix — keep it mounted

Restructure `WideShell` so the master column (the `tabs`/list subtree) **stays mounted** whether collapsed or expanded — collapsing changes its occupied width, not its presence. The invariant: **toggling collapse must not dispose or re-`initState` the segment pages**; their element/state (loaded lists, scroll offset, selected item) survives, so re-expanding is instant.

Constraints to get right:

* **Collapsed occupies no width** (the detail pane fills), **expanded occupies `masterWidth`** — but the list must **not reflow to 0-width** while collapsed (that would rebuild the list's items). Keep the content laid out at `masterWidth` and clip it: e.g. `ClipRect` + a fixed-width inner (`OverflowBox`/`SizedBox(width: masterWidth)`) inside an outer box whose width goes `masterWidth → 0`; or `Offstage` (skips layout but keeps state — re-layout on show is cheap). Either is fine as long as the segment pages are not disposed/re-initialised on toggle.
* **One `rail` instance**, shared across states (don't duplicate it into two branches that swap).
* **Mini player placement** keeps today's behaviour: spans the full bottom width when collapsed, and only the rail+master region when expanded — without forcing the master subtree to rebuild. (If keeping the mini player stable across states is awkward, its own rebuild is cheap; the non-negotiable is that `tabs` is not rebuilt.)
* **Map tab** (`currentTab == 1`) and the **narrow layout** are unaffected.
* A smooth width transition (`AnimatedSize`) is a nice-to-have, not required — correctness + no-rebuild first.

## Scope — two commits

### Commit 1. Master pane stays mounted across collapse

`wide_shell.dart`: a single tree where the master column is always built and its width collapses to 0 (clipped) rather than being removed, so `tabs` is never disposed/re-initialised on toggle; mini-player placement preserved; Map tab / narrow untouched.

Commit: `perf(shell): keep the master pane mounted when collapsed so re-expanding is instant`.

### Commit 2. Test

* Toggling collapse and back does **not** recreate the segment pages: assert the same `State` instance survives (e.g. via a keyed probe or an `initState` counter on a stub segment), or that a scroll offset / selection set before collapsing is still there after re-expanding.
* Collapsed gives the detail pane the full width (no leftover master gap); expanded restores `masterWidth`.
* Map tab and narrow layout render unchanged.

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Commit: `test(shell): master pane survives a collapse toggle without rebuilding`.

## Ground rules

* Views + test only; wide layout only.
* The invariant is no dispose/re-`initState` of `tabs` on toggle — verify it, don't just assume the restructure achieves it.
* Behaviour-preserving otherwise: collapsed/expanded look and the mini-player behaviour are unchanged; only the widget lifecycle across the toggle improves.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `dart build cli` succeeds.
3. Manual smoke (wide): open a segment, scroll the list, toggle the master off and on → it comes back instantly with the scroll position and selection intact (no visible rebuild flash); no right-edge overflow at compact/medium/expanded; the mini-player sits correctly in both states; Map tab and narrow unchanged.
4. `git diff --stat` touches `lib/views/shell/…`, `test/…` only.
5. Clean tree.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted test, one full-suite gate at the end (rule 9). Toggling the master pane no longer rebuilds the segment lists; re-expanding is instant.
