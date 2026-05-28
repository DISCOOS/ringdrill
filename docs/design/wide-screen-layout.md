---
id: DESIGN-005
title: Wide-screen layout
status: Accepted
started: 2026-05-29
accepted: 2026-05-29
owners: ["kengu"]
related_code:
  - lib/views/shell/main_screen.dart
  - lib/views/widgets/context_sheet.dart
  - lib/views/widgets/ringdrill_sheet.dart
  - lib/views/player/drill_mini_player.dart
  - lib/views/active_plan_actions.dart
related_designs:
  - exercise-player.md
  - stations-tab.md
  - roleplays-tab.md
related_adrs:
  - 0026-sheet-based-context-navigation.md
  - 0027-unified-bottom-sheet-chrome.md
  - 0028-feature-first-views-layout.md
  - 0030-wide-screen-master-detail-layout.md
---

# Wide-screen layout

## TL;DR

Master/detail shell on medium (600–839 px) and expanded (≥ 840 px). List tabs become a fixed-width master column. Detail surfaces render inline in the right column instead of as sheets. Forms open as modal dialogs. `DrillMiniPlayer` anchors to the master column footer. Map tab is an internal split (map + detail). Compact (< 600 px) is unchanged.

See [ADR-0030](../adrs/0030-wide-screen-master-detail-layout.md) for rationale and options. This doc covers anatomy, copy, sizing and implementation steps.

## Non-goals

* No new detail screens. Existing screens render unchanged. Only their mount surface changes.
* No data-model or schema changes.
* No new state-management mechanism.
* No third-party adaptive package.
* No change to compact (< 600 px).
* FAB placement on medium/expanded is deferred (see ADR-0030).

## Window-size classes

| Class    | Width        | Navigation       | Body                          |
|----------|--------------|------------------|-------------------------------|
| Compact  | `< 600`      | `NavigationBar`  | Full-width tab + sheet        |
| Medium   | `600`–`839`  | `NavigationRail` | Master + detail (compact)     |
| Expanded | `>= 840`     | `NavigationRail` | Master + detail (standard)    |

`WindowSizeClass.of(context)` reads `MediaQuery.sizeOf(context).width`. Convenience getters:

```dart
bool get hasRail         => this >= WindowSizeClass.medium;
bool get hasMasterDetail => this >= WindowSizeClass.medium;
```

Fallback inside `LayoutBuilder`: if `viewport - rail - master < 360`, render the compact body (full-width tab + sheet) regardless of class. Affects 600–679 px.

## Anatomy

### Medium and expanded shell

```
┌──────┬────────────────┬─────────────────────────────────────┐
│      │                │                                     │
│ Rail │   Master       │   Detail                            │
│      │   (list)       │                                     │
│      │                │                                     │
│      │                │                                     │
│      ├────────────────┤                                     │
│      │ DrillMini      │                                     │
│      │ Player         │                                     │
└──────┴────────────────┴─────────────────────────────────────┘
```

* Rail. `NavigationRail` with five destinations (Øvelser, Kart, Poster, Markører, Lag). Trailing slot keeps the active tab's `buildFAB` until the FAB-placement follow-up resolves.
* Master. The active tab's existing list view. Width `360 px` expanded, `280 px` medium.
* Detail. The active `ContextSheetTarget` or the tab's empty-pane widget.
* DrillMiniPlayer. Bottom of the master column, full master width, above safe-area. Visible only when `ExerciseService().isStarted`. Tap opens the immersive `CoordinatorScreen`.

### Compact shell

Unchanged. `NavigationBar`, full-width `IndexedStack`, `DrillMiniPlayer` above the nav bar in `_buildBottomChrome`, detail via `showRingdrillViewerSheet`.

## Behaviour

### Detail navigation

`ContextSheetController.show` short-circuits through `MasterDetailScope` when present (except for `BriefSheetTarget`). Otherwise it opens the sheet as today.

```dart
Future<void> show(BuildContext context, ContextSheetTarget target) async {
  if (target is! BriefSheetTarget) {
    final scope = MasterDetailScope.maybeOf(context);
    if (scope != null) {
      scope.setTarget(target);
      return;
    }
  }
  // existing sheet path
}
```

`replace(target)` assigns the active target. Same `ValueNotifier<ContextSheetTarget?>` drives both surfaces.

`close()` clears the target. Compact pops the sheet. Medium/expanded resets the pane to its empty state.

Cross-references in detail screens (e.g. `replace(StationSheetTarget(...))` from a team screen) work unchanged.

### Empty detail states

Tab icon + one-line copy. No CTA.

| Tab        | Copy (nb)                          | l10n key prefix          |
|------------|------------------------------------|--------------------------|
| Øvelser    | "Velg en øvelse"                   | `detailEmpty.exercise`   |
| Kart       | (no empty pane, see Map exception) | —                        |
| Poster     | "Velg en post for å se detaljer"   | `detailEmpty.station`    |
| Markører   | "Velg en markør"                   | `detailEmpty.roleplay`   |
| Lag        | "Velg et lag"                      | `detailEmpty.team`       |

Tab switch clears the pane. Targets are tab-typed and not preserved across tabs.

Deep-link entry uses the existing `_ContextSheetDeepLinkLauncher` and lands the target in the pane on medium/expanded.

### Map tab exception

```
┌──────┬────────────────────────────────┬──────────────────┐
│ Rail │     Map                        │   Detail         │
│      │                                │                  │
│      ├────────────────────────────────┤                  │
│      │ DrillMiniPlayer                │                  │
└──────┴────────────────────────────────┴──────────────────┘
```

* Expanded: map ~2/3, detail ~1/3. Medium: ~60/40.
* Fallback to full-width map + sheet if detail would be < 360 px.
* Tap marker → fills detail with `StationSheetTarget`. Tap same marker → clears.
* No master list.

Mini-player anchors to the bottom of the map area at the same vertical position as on list tabs.

### Brief stays fullscreen

`BriefSheetTarget` always opens via `showRingdrillViewerSheet` with `maxBodyWidth: double.infinity`. Brief's own TOC sidebar handles wide layouts internally.

### Forms become modal dialogs

```dart
Future<T?> openFormSurface<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  if (WindowSizeClass.of(context).hasMasterDetail) {
    return showRingdrillFormDialog<T>(context: context, builder: builder);
  }
  return Navigator.of(context).push<T>(
    MaterialPageRoute(builder: (_) => builder(context)),
  );
}
```

`showRingdrillFormDialog<T>` in `lib/views/widgets/ringdrill_sheet.dart`:

* `showDialog` with scrim.
* `Dialog`, `clipBehavior: Clip.antiAlias`, `BorderRadius.circular(16)`, `elevation: 8`.
* Body: `ConstrainedBox(maxWidth: 720, maxHeight: viewport.height * 0.88)`.
* Form's `AppBar` kept. Leading swapped to `Icons.close`.
* `Navigator.pop(context, result)` returns the result. Unchanged.

Migrate call sites in `active_plan_actions.dart`, `StationListView`, `RolePlaysView` and `MainScreen` drawer items to `openFormSurface`. Form widgets are not modified. Compact keeps `MaterialPageRoute`.

### Drill mini-player

* Compact: unchanged. Above `NavigationBar` in `_buildBottomChrome`, 12 px rounded pill.
* Medium/expanded: master-column footer. Full master width, no side margin. Only the top corners are rounded (12 px). Above safe-area. Tap opens `CoordinatorScreen` via `showDrillPlayerSheet`.

The DESIGN-001 V2 fullscreen player covers master and detail, so no extra branching is needed.

## State and lifecycle

* Tab controllers and the keep-alive `IndexedStack` are unchanged. They render into the master column on medium/expanded.
* `ContextSheetController` owns the single `ValueNotifier<ContextSheetTarget?>`. The detail pane listens to it via `ValueListenableBuilder`.
* `MasterDetailScope` is an `InheritedWidget` exposing `setTarget(target)`. Mounted by `MainScreen` only on medium/expanded.

## Deferred decisions

* FAB placement on medium/expanded. Stays at `NavigationRail.trailing` until decided.
* Saved-detail-per-tab. Tab switch always returns to empty.
* Three-pane layout at ≥ 1240 px.

## Implementation steps

1. `lib/views/shell/window_size_class.dart` — `WindowSizeClass` enum + `of(context)` + getters. Replace `_wideScreen` in `main_screen.dart`.
2. `lib/views/shell/master_detail_scope.dart` — `MasterDetailScope` + `_MasterDetailPane`.
3. `lib/views/shell/open_form_surface.dart` — `openFormSurface<T>`.
4. `lib/views/widgets/ringdrill_sheet.dart` — add `showRingdrillFormDialog<T>`.
5. `lib/views/widgets/context_sheet.dart` — `show` short-circuits through `MasterDetailScope` unless `target is BriefSheetTarget`.
6. `lib/views/shell/main_screen.dart` — mount `MasterDetailScope`, render master + detail with Map-tab split, move mini-player to master footer. `_buildBottomChrome` renders mini-player only on compact.
7. Five empty-pane widgets, one per list tab. Map tab has none.
8. l10n keys in `app_en.arb` and `app_nb.arb` for the empty-pane copy.
9. Migrate form-opening call sites to `openFormSurface`. Form widgets unchanged.

No data-model or schema changes. No new dependencies.
