# Implement: expanded map-right layout for the Post and Spill viewers

You are working in the RingDrill repository, on `design-010`. Bring the **Post viewer** (`station_screen.dart`) and **Spill viewer** (`roleplay_screen.dart`) into the same pane-local wide layout the coordinator already has: when the pane is wide enough, the map moves to a fixed full-height right pane and everything else sits in a scrolling left column. References: the coordinator implementation (`design-010-coordinator-play-and-status-polish.md` commit "coordinator play-mode layout for compact, medium and expanded" + the pane-local-breakpoint fix), and the mockup `docs/design/mockups/coordinator-play-breakpoints.html` for the expanded arrangement. Read `AGENTS.md` rule 9.

**Views only.** No model/renderer/schema change.

## The gap

Only the coordinator got the expanded map-right / rest-left split. The Post and Spill detail viewers still stack everything vertically at all widths — so when their detail pane is wide (e.g. the master is collapsed, or a large screen), the map spans full width with the text sections above/below instead of sitting beside them. The three detail surfaces should feel the same. (Lag — `team_screen.dart` / `team_exercise_screen.dart` — is **out of scope**: its layout needs its own design pass, per Kengu.)

## Behaviour

Drive the layout off the **pane's own width**, exactly like the coordinator: in the body's `LayoutBuilder`, `WindowSizeClass.fromWidth(constraints.maxWidth)` (not `.of(context)` — the pane is narrower than the window inside master/detail).

* **expanded** (pane ≥ 840): a two-pane `Row` — a **capped-width scrolling left column** (~440, must not stretch) holding the textual/tabular sections, and the **map panel filling the remaining width, full height** (clearly wider than the left column, matching the coordinator). The left column scrolls; the map pane is fixed.
* **compact / medium** (< 840): today's stacked layout, unchanged (map inline between sections).

Section split (confirm the exact widget/section names in each file first):

* **Post (`station_screen.dart`)** — right: the map panel (`StationPositionPanel` — map + legend + the "Posisjon" coordinate row; keep the cohesive panel together). Left column: POSTBESKRIVELSE (description rollup), PERSONER, TIDSPLAN (schedule card).
* **Spill (`roleplay_screen.dart`)** — right: the role map panel (`RolePositionPanel` — map + coordinate row). Left column: the post-context card, the person/identity card, NÅR AKTIV (schedule).

If the coordinate row proves trivially separable and reads better in the left column with the other info, that's fine — but the map graphic itself must be the right pane. Prefer keeping the existing panel intact over splitting it.

If the expanded split is essentially identical in both screens, extract a small shared helper (e.g. `lib/views/shell/wide_detail_map_split.dart`, `WideDetailMapSplit({required List<Widget> left, required Widget mapPane, double leftMaxWidth})`) and use it in both, so the two do not drift. The coordinator's equivalent may stay as is; adopt the helper there too only if it drops in cleanly (don't destabilise the coordinator for this).

## Scope — three commits

### Commit 1. Post viewer expanded split

`station_screen.dart` (+ the shared helper if extracted): expanded → capped left column + full-height map pane; compact/medium unchanged.

Commit: `feat(views): expanded map-right layout for the Post viewer`.

### Commit 2. Spill viewer expanded split

`roleplay_screen.dart`: same treatment, reusing the helper.

Commit: `feat(views): expanded map-right layout for the Spill viewer`.

### Commit 3. Tests

* At a wide pane (≥ 840) the Post viewer places the map panel beside a capped left column (map pane present as a side pane, not full-width-stacked); at a narrow pane it stacks. Same for the Spill viewer.
* `takeException()` is null at both widths (no overflow) — the pane-local width is what drives it, not the window.

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Commit: `test(views): cover Post/Spill expanded map-right layout`.

## Ground rules

* Views + test only; Lag (`team_screen`/`team_exercise_screen`) untouched.
* Breakpoint from `WindowSizeClass.fromWidth(constraints.maxWidth)`, not the window; no new pixel constants beyond the left-column cap.
* Behaviour-preserving in compact/medium — only the expanded arrangement is new.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `dart build cli` succeeds.
3. Manual smoke: open a Post viewer and a Spill viewer in the wide layout, collapse the master → the map moves to a wide fixed right pane with the description/persons/schedule (Post) or post-context/person/schedule (Spill) in a capped left column; expand the master (narrower pane) → they stack as before. No right-edge overflow at any width.
4. `git diff --stat` touches `lib/views/…`, `test/…` only.
5. Clean tree.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). Post and Spill match the coordinator's expanded flow; Lag is deferred to its own design pass.
