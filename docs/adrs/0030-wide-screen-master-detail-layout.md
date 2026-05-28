---
status: accepted
date: 2026-05-29
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0030: Adopt a Material 3 master/detail layout on medium and expanded viewports, promote forms to modal dialogs and anchor the drill mini-player to the master column

## Context and problem statement

`_wideScreen` is a single boolean at `width > 600` that only swaps `NavigationBar` for `NavigationRail`. The five tabs stay full-width, every detail surface opens as a 720 px sheet centred over an otherwise empty body, every form pushes a fullscreen `MaterialPageRoute`, and `DrillMiniPlayer` is hidden entirely when `_wideScreen` is true.

[ADR-0026](./0026-sheet-based-context-navigation.md) and [ADR-0027](./0027-unified-bottom-sheet-chrome.md) routed all detail surfaces through `ContextSheetController`. That controller is the seam to teach about wide layouts. Its `show` / `replace` / `close` grammar is preserved.

## Decision drivers

* Use the available pixels on medium and expanded.
* Keep ADR-0026 semantics on every surface, sheet or pane.
* Stop tearing down the shell on every form open.
* Restore the persistent mini-player on medium and expanded.
* Align with Material 3 window-size classes. No new dependencies.

## Considered options

* **Option A: Material 3 master/detail, route detail through `ContextSheetController`, dialog forms, master-anchored mini-player. (chosen)**
* **Option B: Two-column on expanded only.** Rejected. Drops the most common tablet target.
* **Option C: Per-screen responsive rewrite.** Rejected. Loses the central seam.
* **Option D: `flutter_adaptive_scaffold`.** Rejected. Dependency, opinionated, does not reuse the sheet plumbing.

## Decision outcome

Chosen option: **Option A**.

### Window-size classes

| Class    | Width        | Navigation       | Body                          |
|----------|--------------|------------------|-------------------------------|
| Compact  | `< 600`      | `NavigationBar`  | Full-width tab + sheet        |
| Medium   | `600`–`839`  | `NavigationRail` | Master + detail (compact)     |
| Expanded | `>= 840`     | `NavigationRail` | Master + detail (standard)    |

A `WindowSizeClass` enum in `lib/views/shell/` replaces `_wideScreen`. Layout decisions read the enum; pane shape inside the body is computed by `LayoutBuilder` so split-screen degrades gracefully.

### Master/detail

Layout on medium and expanded:

```
[Rail | Master | Detail]
```

* Master column hosts the active tab's existing list view (`ProgramView`, `StationsView`, `StationListView`, `RolePlaysView`, `TeamsView`).
* Master width: `360 px` expanded, `280 px` medium.
* Fallback: if `viewport - rail - master < 360`, the layout falls back to compact (full-width tab + sheet) for that viewport. Affects 600–679 px.
* Detail column renders the active `ContextSheetTarget` or the tab's empty-pane widget.

`ContextSheetController.show(target)` short-circuits through `MasterDetailScope` when present, otherwise falls back to `showRingdrillViewerSheet`. `replace` and `close` route the same way. Existing call sites are unchanged.

### Empty detail states

One widget per list tab. Tab icon, one-line copy, nothing else. Tab switch clears the detail pane.

### Map tab exception

Internal split inside the Map tab body. Map left, detail right.

* Expanded: ~2/3 + ~1/3. Medium: ~60/40.
* Fallback to full-width map + sheet if detail would be < 360 px.
* Tap marker fills detail. Tap same marker again clears it.

### Brief stays fullscreen

`BriefSheetTarget` is opened via `showRingdrillViewerSheet` with `maxBodyWidth: double.infinity` on every window size. `ContextSheetController.show` skips the `MasterDetailScope` short-circuit when the target is `BriefSheetTarget`.

### Forms become modal dialogs

New helper `showRingdrillFormDialog<T>` in `lib/views/widgets/ringdrill_sheet.dart`:

* `showDialog` with scrim.
* `Dialog`, `clipBehavior: Clip.antiAlias`, `BorderRadius.circular(16)`, `elevation: 8`.
* Body: `ConstrainedBox(maxWidth: 720, maxHeight: viewport.height * 0.88)`.
* Form's own `AppBar` kept. Leading `Icons.arrow_back` becomes `Icons.close` per ADR-0027.
* Commit/cancel via `Navigator.pop(context, result)`. Unchanged.

Dispatch helper `openFormSurface<T>(context, builder:)` chooses dialog on medium/expanded, `MaterialPageRoute` on compact. Call sites in `active_plan_actions.dart` plus direct form-push sites route through it. Form widgets are not modified.

Sites: `ExerciseFormScreen`, `StationFormScreen`, `ActorScreen`, `RolePlayScreen`-edit, `SettingsPage`, `AboutPage`. The DESIGN-001 V2 fullscreen player is not a form and stays a route push.

### Drill mini-player

* Compact: unchanged. Above `NavigationBar` in `_buildBottomChrome`.
* Medium / expanded: anchored to the master column's bottom edge, full master width, above safe-area. No side margin, no rounded pill. Tap opens the immersive `CoordinatorScreen` sheet as today.

The future DESIGN-001 V2 fullscreen player covers master and detail, so no extra branching is needed to hide the mini-player when it opens.

### Deep links

`_ContextSheetDeepLinkLauncher` is unchanged. On medium and expanded the target lands in the pane. Internal `replace` does not update the URL, mirroring ADR-0026.

### Deferred

* **FAB placement on medium and expanded.** Choice between `NavigationRail.trailing` (today) and master-column leading is left to a follow-up. Until then FAB stays in `NavigationRail.trailing`.

### Consequences

* Good: Detail surfaces use the available width without a per-screen rewrite.
* Good: `ContextSheetController` API unchanged. Call sites are layout-agnostic.
* Good: Forms keep the shell standing on tablet and desktop.
* Good: Mini-player is persistent on every window size.
* Good: Map tab gets a real detail surface.
* Bad: 600–679 px viewports fall back to compact sheet inside `medium`. Threshold is explicit, fallback is the existing path.
* Bad: Five empty-pane widgets and three new shell concepts (`WindowSizeClass`, `MasterDetailScope`, `openFormSurface`).
* Bad: Map tab split is a one-off, documented as an exception in DESIGN-005.

## Pros and cons of the options

### Option A — Material 3 master/detail, dialog forms, master-anchored mini-player

* Good: Reuses `ContextSheetController`, lines up with M3, restores the mini-player.
* Bad: Three new shell concepts, Map-tab exception, 600–679 px fallback.

### Option B — Two-column on expanded only

* Good: Smallest change.
* Bad: Leaves medium tablets on the current layout.

### Option C — Per-screen responsive rewrite

* Good: Maximum per-screen freedom.
* Bad: Loses the central seam, doubles every detail surface.

### Option D — `flutter_adaptive_scaffold`

* Good: Off-the-shelf shell.
* Bad: Dependency, ignores the existing sheet plumbing.

## Links

* Related ADRs:
  * [ADR-0026](./0026-sheet-based-context-navigation.md) — supersedes the "centred 720 px sheet" wide rule. Detail-navigation grammar unchanged and extended to the pane.
  * [ADR-0027](./0027-unified-bottom-sheet-chrome.md) — `showRingdrillFormDialog` is a sibling helper. Sheet chrome stays in force on compact and on the Brief fullscreen overlay.
  * [ADR-0028](./0028-feature-first-views-layout.md) — new shell concepts live in `lib/views/shell/`.
  * [ADR-0029](./0029-live-activity-and-foreground-service.md) — `DrillMiniPlayer` widget unchanged. Only its mounting point moves.
* Related design docs:
  * [DESIGN-001](../design/exercise-player.md) — fullscreen player still a route push.
  * [DESIGN-005](../design/wide-screen-layout.md) — layout diagrams, empty-pane copy, Map-tab split.
* Related code:
  * `lib/views/shell/main_screen.dart`
  * `lib/views/shell/window_size_class.dart` (new), `master_detail_scope.dart` (new), `open_form_surface.dart` (new)
  * `lib/views/widgets/ringdrill_sheet.dart`
  * `lib/views/widgets/context_sheet.dart`
  * `lib/views/active_plan_actions.dart`
  * `lib/views/player/drill_mini_player.dart`
