# Fix: fill the map to full height + padding in the Post/Spill expanded layout

You are working in the RingDrill repository, on `design-010`. A polish follow-up to the just-landed Post/Spill expanded map-right layout (`design-010-post-spill-expanded-map-split.md`, the `WideDetailMapSplit` helper). Read `AGENTS.md` rule 9.

**Views only.** No model/renderer/schema change.

## Fix 1 — The map fills the full available height (drop the fixed-height hack)

In the expanded right pane the map panel (`StationPositionPanel` / `RolePositionPanel`, built on `PositionCardShell`) uses a **fixed** thumbnail height, so the panel is shorter than the pane and leaves an empty gap below the coordinate bar (the red squiggle in the screenshots). The map should **expand to fill the whole available pane height**, with the legend and the coordinate bar pinned **below** the filled map — not a fixed-height frame floating with the position text.

* Give `PositionCardShell` a **fill mode** where the thumbnail flexes (`Expanded`) to take all remaining height, with `legend` + coordinate bar laid out below it (the bar stays at the very bottom of the pane, no gap). Keep today's fixed-`thumbnailHeight` behaviour as the default for the stacked/inline (compact/medium) uses — only the expanded right pane fills.
* In `WideDetailMapSplit` (or where the right pane is built), pass the panel in fill mode and let it fill the pane's height; **remove the computed "pane height minus an allowance for the bar/legend" logic** — the flex layout makes that unnecessary and is what caused the leftover gap.
* **Compose with the pending position-card collapse** (`design-010-collapsible-section-cards.md`, not yet run): that follow-up makes the position card collapse to its coordinate bar. A flexing map sets this up cleanly — when not collapsed the map fills the pane; when collapsed the map is absent and the pane shrinks to just the bar. Whichever of the two lands second, the fill mode and the collapse must coexist: don't force the pane to the full/computed map height while collapsed.

## Fix 2 — Remove the extra top padding on the left column (don't pad the map)

The left column's first card and the map pane don't start on the same line (the red rule at the top). The **map's top is correct** — the map must **not** get more padding. The problem is an **extra top padding on the left column** that this view has but the other views (coordinator etc.) don't. Remove that extra top inset on the left column so its first card's top lines up with the map's top, matching the other surfaces.

* Remove the extra top padding on the **left column** so the left column's first card aligns with the map pane's top. Do not add padding to the map to compensate.
* Keep it **consistent across surfaces** — the Post/Spill expanded layout should use the same top inset as the coordinator's expanded layout, not a larger one.

## Scope — two commits

### Commit 1. Fill the map + padding

`position_card.dart` (fill mode), `wide_detail_map_split.dart` + `station_screen.dart` / `roleplay_screen.dart` (pass fill mode, drop the computed-height allowance, remove the left column's extra top padding so tops align — don't pad the map).

Commit: `fix(views): fill the map to full height and align padding in the Post/Spill expanded layout`.

### Commit 2. Test

* In the expanded layout the map panel fills the pane height (the coordinate bar sits at the pane bottom, no fixed-height gap); at a tall and a short pane there is no overflow (`takeException()` null).
* The stacked (compact/medium) layout still uses the fixed thumbnail height (unchanged).

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Commit: `test(views): cover the filled map height in the Post/Spill expanded layout`.

## Ground rules

* Views + test only. Fill mode is additive — the inline/stacked panel is unchanged.
* Breakpoint/pane-width logic stays as landed (`WindowSizeClass.fromWidth(constraints.maxWidth)`); this only changes how the right pane sizes its content.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `dart build cli` succeeds.
3. Manual smoke: open a Post and a Spill viewer with the master collapsed (wide pane) → the map fills the full height of the right pane with the "● Post"/marker legend and the "Posisjon 32V…" bar pinned at the bottom, no empty gap; the left column's first card top lines up with the map top (achieved by removing the left column's extra top padding, not by padding the map); the top inset matches the coordinator's expanded layout. Stacked (narrower) layout unchanged.
4. `git diff --stat` touches `lib/views/…`, `test/…` only.
5. Clean tree.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted test, one full-suite gate at the end (rule 9). The map fills the expanded right pane's height with the coordinate bar at the bottom; tops and gutters align across the left column and the map pane.
