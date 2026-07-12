# Implement DESIGN-010 follow-up: coordinator breakpoint from its own pane width

You are working in the RingDrill repository, on `design-010`. A correctness fix to the just-landed coordinator play-mode layout (`design-010-coordinator-play-and-status-polish.md`). Read `AGENTS.md` rule 9.

**No model, renderer, or schema change.** A one-line layout-source fix plus a small enum helper.

## The bug

The coordinator picks its compact/medium/expanded layout from `WindowSizeClass.of(context)`, which reads the **full window width** (`MediaQuery.sizeOf`). But in the wide master/detail shell (`wide_shell.dart`) the coordinator lives in the **detail pane**, which is much narrower than the window: the left region is `rail (72) + master (320 / 420)`, and the detail pane is the `Expanded` remainder.

So at a 920-px window the shell is expanded → master region ≈ 492 → detail pane ≈ 428, yet the coordinator reads 920, believes it is `expanded`, and tries to render the two-pane map-right layout inside a ~428-px pane — the "RIGHT OVERFLOWED BY 20 PIXELS" stripe in the screenshots. The pre-DESIGN-010 code guarded against exactly this with a dual check (`MediaQuery ≥ 1120 && constraints.maxWidth ≥ 900`); the rework dropped the local-width half.

## The fix

The coordinator's breakpoint must come from **its own available width**, not the window.

1. **`lib/views/shell/window_size_class.dart`** — add a pure `WindowSizeClass.fromWidth(double width)` using the same thresholds, and have `of(context)` delegate to it:

   ```dart
   static WindowSizeClass fromWidth(double width) {
     if (width >= 840) return WindowSizeClass.expanded;
     if (width >= 600) return WindowSizeClass.medium;
     return WindowSizeClass.compact;
   }

   static WindowSizeClass of(BuildContext context) =>
       fromWidth(MediaQuery.sizeOf(context).width);
   ```

2. **`coordinator_screen.dart`** — in `_buildBody`, derive the size class from the body's own `LayoutBuilder` `constraints.maxWidth` via `WindowSizeClass.fromWidth(constraints.maxWidth)`, instead of `WindowSizeClass.of(context)`. The layout now responds to the coordinator's actual pane width: the full body in the narrow (single-pane) layout, or the detail pane inside master/detail.

That's the whole change. Consequence: inside master/detail the detail pane is typically ~430–730 px → the coordinator renders `compact`/`medium` (stacked; map via the `Kart` segment), so there is no three-column squeeze and no overflow. The `expanded` map-right layout appears only when the coordinator's **own** pane is ≥ 840 (a genuinely wide window in the single-pane layout, or — once the master pane can collapse, the separate follow-up — a collapsed master giving the detail full width).

Leave the players (Post/Lag/Spill/Team) as they are: they only stack cards and never branched on window size.

## Scope — two commits

### Commit 1. Breakpoint from local pane width

`window_size_class.dart` (`fromWidth` + `of` delegating) and `coordinator_screen.dart` (`_buildBody` uses `constraints.maxWidth`).

Commit: `fix(views): coordinator picks its layout from its own pane width, not the window`.

### Commit 2. Test

Pump `CoordinatorScreen` (running, with stations) inside a `SizedBox(width: ~430)` while `MediaQuery` reports a wide (~1200) window; assert `tester.takeException()` is null (no overflow) and that the `Kart` segment is present and the expanded map pane is **absent** — i.e. the layout followed the 430-px pane, not the 1200-px window. A second case at a ≥ 840-px pane still shows the expanded map pane and drops `Kart`.

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Commit: `test(views): coordinator layout tracks its pane width inside master/detail`.

## Ground rules

* Views + the `WindowSizeClass` helper only. No model, renderer, ARB, or schema change.
* Behaviour-preserving: the three layouts themselves are unchanged — only which one is chosen, and from which width.
* `fromWidth` is pure (no `BuildContext`); `of` must keep behaving exactly as before for its existing callers.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `dart build cli` succeeds.
3. Manual smoke: in the wide master/detail shell at a ~900–1250 px window, opening an exercise shows the coordinator **stacked** in the detail pane (schedule card + `Poster | Lag | Kart` segment + list), with no right-edge overflow. Widen until the detail pane itself is very wide (or, later, collapse the master) and the map-right expanded layout appears.
4. `git diff --stat` touches `lib/views/…`, `test/…` only.
5. Clean tree.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted test, one full-suite gate at the end (rule 9). The master-pane collapse toggle is a separate follow-up; do not build it here.
