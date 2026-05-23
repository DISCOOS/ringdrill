---
id: DESIGN-002
title: Stations tab
status: Accepted
started: 2026-05-23
accepted: 2026-05-23
owners: ["kengu"]
related_code:
  - lib/views/main_screen.dart
  - lib/views/stations_view.dart
  - lib/views/station_screen.dart
  - lib/views/station_form_screen.dart
  - lib/views/program_view.dart
  - lib/views/coordinator_screen.dart
  - lib/services/program_service.dart
related_designs:
  - exercise-player.md
---

# Stations tab

> Terminology note: Norwegian UI uses **"Poster" / "post"**. English UI and all code use **"Stations" / "station"**. This doc is in English, so the entity is referred to as a *station* throughout. The Norwegian label is shown in the localization-keys table.

## TL;DR

A new **Stations** tab is added to the bottom navigation. Today's "Stations" tab is renamed **Map**, since that is what it actually is. The set of stations is owned by exercise setup. The Stations tab inspects existing stations and edits their properties, nothing else. Each row is an expandable tile. Tile body tap opens the station in `StationScreen`. The chevron toggles expand/collapse. Mini-map tap opens a fuller map in a bottom sheet. Swipe-left opens the edit form directly, reusing the `Dismissible` pattern from the Exercises tab. A FAB in the bottom-right narrows the list to one exercise, mirroring the Map tab filter.

## Rationale

When `CoordinatorScreen` was reframed as the Exercise Player (see [DESIGN-001](./exercise-player.md)), the natural editing path for stations disappeared with it. The player is run-mode focused. Today's "Stations" tab is at the navigation root, but it is a map, not a list, so it serves overview rather than editing.

The Stations list separates navigation root from ownership root. A station still belongs to a single exercise in the data model, but the per-property editing canvas for stations lives at the root, alongside Map, Exercises and Teams. Map answers "where are they", Stations answers "what are they".

## Goals

1. Give station inspection and per-station property editing a home now that the coordinator screen has become the Exercise Player.
2. Rename the misnamed "Stations" tab (which is actually a map) to Map, and reuse the "Stations" label for the new list view.
3. Keep the Exercise Player run-focused. Editing does not happen there.

## Non-goals

* **No structural changes to the set of stations from this tab.** Add, remove, move and reorder are exercise-setup operations and live under the Exercises tab and `StationFormScreen`.
* No data model changes.
* No multi-select or bulk actions.

## Navigation

The bottom navigation gets four destinations in this order:

| # | Label     | Icon              | Route             |
|---|-----------|-------------------|-------------------|
| 0 | Exercises | `Icons.update`    | `/program`        |
| 1 | Map       | `Icons.map`       | `/map`            |
| 2 | Stations  | `Icons.place`     | `/stations`       |
| 3 | Teams     | `Icons.group`     | `/teams`          |

The route `/stations` moves from the Map tab to the new Stations list tab, because the list is the canonical view of the entity and the path should reflect that. The Map tab gets a new route `/map`. The station-detail deep link pattern `/stations/:exerciseUuid/:stationIndex` (today reached from the Map tab) stays valid and lands on `StationExerciseScreen` regardless of which tab the navigation started from. Any external links that point to the bare `/stations` URL now land on the Stations list rather than the Map. That is a deliberate semantic correction.

`Icons.place` (a pin) ties the tab visually to the map markers, so Map and Stations read as two lenses on the same entity.

## Anatomy

```
┌─────────────────────────────────────────────┐
│   AppBar:  Stations                  ⋮      │
├─────────────────────────────────────────────┤
│                                             │
│   A1 · Fire ignition                      ▸ │ ← tap row → opens station
│   Exercise: Forest Fire 2026                │   tap ▸ → expand
│                                             │   swipe ← → edit form
│   A2 · First aid                          ▾ │
│   Exercise: Forest Fire 2026                │
│   Description:                              │
│    "Assess vitals, prioritize ..."         │
│   Position: 60.123, 10.456                  │
│   ┌─────────────────────────────────┐       │
│   │            mini map             │ ← tap │ → bottom sheet
│   └─────────────────────────────────┘       │
│                                             │
│   A3 · Evacuation                         ▸ │
│   Exercise: Forest Fire 2026                │
│                                             │
│   B1 · Radio drill                        ▸ │
│   Exercise: Winter Exercise 2026            │
│                                             │
│                                       ┌───┐ │
│                                       │ ⚑ │ │ ← filter FAB
│                                       └───┘ │   (Badge.count when active)
├─────────────────────────────────────────────┤
│   ⬜ EXECUTION · Round 2/5     06:42  ⏹     │ ← mini-player (DESIGN-001)
├─────────────────────────────────────────────┤
│   [Exercises] [Map] [Stations] [Teams]      │
└─────────────────────────────────────────────┘
```

## List structure

**Flat list, not grouped.** Each station is one row. The Exercises tab already gives a grouped view of the same data, so grouping here would just duplicate it. The owning exercise is still visible in each tile's subtitle.

**Sorting.** First by exercise order (matching the Exercises tab), then by station index (run sequence inside the exercise).

## Filtering

A **filter FAB** in the bottom-right corner narrows the list to one exercise, mirroring the visibility FAB in the Map tab. Same icon (`Icons.tune`), same affordance pattern.

* **Inactive (default):** plain FAB, no badge. List shows stations from every exercise.
* **Active:** the FAB carries `Badge.count(count: 1, child: fab)`, and a slim banner above the bottom navigation shows "Showing stations in: <Exercise name>" with a "Show all" recovery button on the right.

Tap on the FAB opens a modal bottom sheet listing every exercise with a radio selector and an "All exercises" row at the top. Single-select. Selecting a row applies the filter and closes the sheet.

The filter is view state and does not persist across process restarts. The FAB slot is reserved for the filter only.

## Tile anatomy

Each row is an expandable tile.

**Collapsed:**

* Leading: compact station-code square (same style as `_buildStationList` in `CoordinatorScreen`), e.g. `A2`.
* Title: station name.
* Subtitle: `Exercise: <name>`.
* Trailing: chevron.

**Expanded adds:**

* Description block if present.
* Position row: textual coordinate, or "No position set" when `position == null`.
* Mini-map if `position != null`. Static preview centered on the station. No panning inside the tile.

**Tap targets are split:**

* Row body → push `StationScreen` for the station.
* Chevron → toggle expand/collapse.
* Mini-map → open the map bottom sheet (does not navigate).
* Swipe-left → open the edit form (see *Drag to edit*).

Material's stock `ExpansionTile` ties title-tap and chevron-tap to the same handler. The Stations tab uses a shared widget `StationExpansionTile` that owns its own animation and splits the tap targets. See *Shared widgets*.

**Mutex expansion.** At most one tile is open at a time. The mutex state lives in `_expandedStationIndex` on the view, same shape as `_expandedStationIndex` / `_expandedTeamIndex` in `CoordinatorScreen`.

## Drag to edit

Swipe-left on a row opens `StationFormScreen` for the station directly, skipping the `StationScreen` read view. Reuses the same `Dismissible` pattern the Exercises tab uses for delete (`program_view.dart` lines 81-130), with these differences:

* **Direction:** `DismissDirection.endToStart`. No second direction is bound.
* **Background:** `colorScheme.secondaryContainer` with `Icons.edit` and the label "Edit". Distinct from the red delete background on the Exercises tab.
* **Action:** `confirmDismiss` pushes `StationFormScreen` and returns `false`. The row snaps back instead of dismissing. `onDismissed` is never wired.
* **No confirm dialog.** Edit is not destructive, so the swipe goes straight to the form.
* **Interaction with expansion:** swipe and expansion are independent. The whole tile slides as one unit, so an expanded row keeps its expanded state across the swipe.

## Map bottom sheet

Tap on the mini-map inside an expanded tile opens a `showModalBottomSheet` with:

* Drag handle at the top.
* Interactive `MapView` centered on the station, marker highlighted.
* Pan and zoom enabled.
* Dismiss by drag-down or tap outside, returning the user to the Stations list with the tile still expanded.

Single marker, single station. For the plan-wide map, the user switches to the Map tab.

## Behaviour

| Gesture                  | Result                                                                 |
|--------------------------|------------------------------------------------------------------------|
| Tap tile body            | Push `StationScreen` for the station.                                  |
| Tap chevron              | Toggle expansion. Collapse any previously expanded row (mutex).        |
| Tap mini-map             | Open the map bottom sheet. No navigation.                              |
| Swipe-left on the row    | `confirmDismiss` pushes `StationFormScreen`, returns false, row snaps back. |
| Tap filter FAB           | Open the exercise picker bottom sheet.                                 |
| Tap "Show all" in banner | Clear filter. Banner disappears, FAB drops its badge.                  |

**No stations in the plan:** empty-state message "No stations yet. Add a station from the Exercises tab."

**Filter excludes everything:** banner stays visible ("Showing stations in: <name>") with "Show all" as the recovery. List area shows "No stations in this exercise."

## Relationship to the Exercise Player

The Stations tab inside the coordinator player (per DESIGN-001) stays run-focused and gets no edit affordances. To edit a station during a pause: minimize the full player, switch to the Stations tab, tap or swipe-left on the station. The player plays, the Stations tab edits, the Exercises tab owns the set.

## Shared widgets

Stations appear as expandable tiles in more than one place (this tab today, the coordinator-player's Stations tab in [DESIGN-001](./exercise-player.md), potentially other surfaces later). Mini-map previews of a single station can show up anywhere a station is rendered. Two reusable widgets keep the tile shape, the tap-target split and the "tap mini-map → bottom sheet" interaction consistent regardless of where the tile is used.

### `StationExpansionTile`

Lives at `lib/views/widgets/station_expansion_tile.dart`.

Generic expandable tile for a station entity. Slot-based so different surfaces can fill the content they need:

| Slot       | Type    | Notes                                                                              |
|------------|---------|------------------------------------------------------------------------------------|
| `leading`  | Widget  | Typically the compact station-code square.                                         |
| `title`    | Widget  | Station name, or a more complex Row (e.g. coordinator player's rotation strip).    |
| `subtitle` | Widget? | Optional. Stations tab uses `Exercise: <name>`.                                    |
| `body`     | Widget  | Caller-supplied expanded content.                                                  |

Tap targets:

* Tap on the leading + title + subtitle area → callback `onOpen`.
* Tap on the trailing chevron → callback `onToggle`.
* `expanded: bool` is controlled by the parent so the parent can enforce the mutex across rows.

The widget owns the expand/collapse animation (`AnimatedSize` or `AnimatedCrossFade` around `body`) and the chevron rotation.

Adoption:

* The Stations tab uses it as specced in *Tile anatomy*.
* The coordinator-player's Stations tab currently uses Material `ExpansionTile` directly in `_buildStationList` (`coordinator_screen.dart` lines 721-839). Migrating it to `StationExpansionTile` is a follow-up refactor. The shape is compatible: the existing complex title-row becomes the `title` slot, the PhaseTile bodies become the `body` slot, and the existing `_handleExpansionChange` mutex becomes the parent-controlled `expanded` flag.

### `StationMiniMap`

Lives at `lib/views/widgets/station_mini_map.dart`.

Static-preview map widget for a single station. Tap opens the map bottom sheet specced in *Map bottom sheet*, regardless of which surface the widget is embedded in.

Spec:

* Input: the `(Exercise, Station)` pair (the `Exercise` provides any context `MapView` needs).
* Render: small, interactivity-disabled `MapView` (around 120-160 px tall) with one marker centered on the station.
* Tap: `showModalBottomSheet` with the interactive variant. Single source of truth for this interaction.

Usable inside `StationExpansionTile`'s `body` slot, inside `StationScreen` if that ever grows a map preview, and inside the coordinator-player's Stations tab if mini-maps are added there later. Every caller gets the same tap-to-zoom behavior for free.

## Open questions

* **Mini-map implementation.** Reuse `MapView` with `interactionFlags` disabled, or build a lighter widget? Decide at implementation time.

## Implementation notes

### Routing changes

In `lib/views/main_screen.dart`:

* Rename the existing `routeStations` constant's value from `/stations` to `/map`. Its semantic owner is now the Map tab.
* Introduce a new `routeStationList` (value `/stations`) for the Stations list tab. Keep the deep-link subpath `:exerciseUuid/:stationIndex` under it, delegating to `StationExerciseScreen`.
* Add a destination with `Icons.place` and the new `stationsTab` localization key.
* Add a `PageWidget` with a new `StationListController` and `StationListView` to `_pages`.
* Add `/stations` to the `routes` array passed to `MainScreen`.

### Localization changes

`app_en.arb` and `app_nb.arb` gain:

| Key                   | English                                              | Norwegian                                                 | Where used                          |
|-----------------------|------------------------------------------------------|-----------------------------------------------------------|-------------------------------------|
| `mapTab`              | "Map"                                                | "Kart"                                                    | Map tab label                       |
| `stationsTab`         | "Stations"                                           | "Poster"                                                  | Stations tab label                  |
| `allExercises`        | "All exercises"                                      | "Alle øvelser"                                            | Filter sheet default row            |
| `showingStationsIn`   | "Showing stations in: {name}"                        | "Viser poster i: {name}"                                  | Active-filter banner                |
| `noStationsInExercise`| "No stations in this exercise."                      | "Ingen poster i denne øvelsen."                           | Empty state when filter excludes all|
| `noStationsYet`       | "No stations yet. Add a station from the Exercises tab." | "Ingen poster ennå. Legg til en post fra Øvelser-fanen." | Empty state when plan has no stations|
| `editStation`         | "Edit station"                                       | "Rediger post"                                            | Swipe background label              |

### `StationListView`

`lib/views/station_list_view.dart`:

* `StationListView extends StatefulWidget` listening to `ProgramService().events`.
* `StationListController extends ScreenController` mirroring `StationsPageController`. `buildFAB` returns the filter FAB.
* List builder collects `(Exercise, Station)` pairs from `ProgramService().loadExercises()` and sorts as described.
* `_filterExerciseUuid: String?` for the filter.
* `_expandedStationIndex: int?` as the expansion mutex. Swipe needs no state — `Dismissible` handles it.

Note: the existing class `StationsView` (in `stations_view.dart`) keeps its current map-view responsibility. Consider renaming it to `MapView` or `StationMapView` in a follow-up to align with its new label. Out of scope for this design.

### `StationExpansionTile` and `StationMiniMap`

Build the two shared widgets specced under *Shared widgets*. Both live under `lib/views/widgets/`.

`StationExpansionTile` shape:

* Leading + title + subtitle wrapped in an `InkWell` with `onTap: onOpen`.
* Chevron as an `IconButton` with `onPressed: onToggle`.
* `body` slot wrapped in `AnimatedSize` (or `AnimatedCrossFade`) keyed on `expanded`.

`StationMiniMap` shape:

* `MapView` configured with one marker and interactivity disabled.
* An `InkWell` overlay (or the `MapView`'s own gesture hook) calls into the bottom-sheet helper on tap.

The bottom-sheet helper can be a private function in `station_mini_map.dart` or a top-level `openStationMapSheet(context, exercise, station)` if other surfaces want to call it directly.

### Swipe-to-edit

Reuse Flutter's built-in `Dismissible`, same as `program_view.dart` lines 81-130. No new package.

```dart
Dismissible(
  key: ValueKey(station.uuid),
  direction: DismissDirection.endToStart,
  background: _editSwipeBackground(context),
  confirmDismiss: (_) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StationFormScreen(
          exerciseUuid: exercise.uuid,
          stationIndex: station.index,
        ),
      ),
    );
    return false; // bounce back, do not dismiss
  },
  child: StationExpansionTile(...),
)
```

### Filter FAB, banner and picker

* FAB pattern follows `_buildVisibilityFab` in `stations_view.dart` (lines 198-212): plain FAB inactive, `Badge.count` when active.
* Banner follows `_buildFilterBanner` in `stations_view.dart` (lines 220-263), with "Showing stations in: <name>" and a "Show all" `TextButton`.
* Picker sheet follows `_openVisibilitySheet` in `stations_view.dart` (lines 270-367), but single-select with an "All exercises" row at the top.

### Map bottom sheet

`showModalBottomSheet` with `showDragHandle: true`, `isScrollControlled: true`, `useSafeArea: true`. Body is a fixed-height container (around 70% of screen height) with a `MapView` centered on the station, one marker. Interactivity flags match the Map tab (`MapConfig.interactive`).

### Tests

* Four tabs render in `MainScreen` after the migration.
* Sort order matches "exercise order, then station index".
* Tile body tap navigates to `StationExerciseScreen` with the correct route.
* Chevron tap toggles expansion; expanding a new row collapses the previous.
* Mini-map tap opens the bottom sheet and does not navigate.
* Swipe-left navigates to `StationFormScreen` via `confirmDismiss` and snaps back without dismissing.
* Filter FAB carries a badge when active.
* "Show all" banner button clears the filter.
* Existing `StationsView` tests still pass after the route move (now `/map`).

## Changelog

* 2026-05-23 — Draft opened. Decisions locked: four tabs, rename the existing "Stations" (map view) tab to Map, `Icons.place` for the new Stations list tab, flat list, mutex expansion with a mini-map inside the expanded tile, reuse of `StationScreen` for editing, no edit affordances in the Exercise Player's Stations tab.
* 2026-05-23 — Review iterations. No "Open station" button: tap tile body opens station, chevron toggles, mini-map opens bottom sheet. Filter moved from chip to bottom-right FAB with the Map-tab pattern (`Badge.count` + banner + "Show all"). Set of stations locked to exercise-setup ownership; the Stations tab does not add, remove or reorder. Swipe-left on a row opens `StationFormScreen` directly via `Dismissible` + `confirmDismiss` returning false (reusing the pattern in `program_view.dart`).
* 2026-05-23 — Extracted `StationExpansionTile` and `StationMiniMap` as shared widgets under `lib/views/widgets/`. The Stations tab uses both. The coordinator-player's Stations tab (DESIGN-001) is flagged for migration from Material `ExpansionTile` to `StationExpansionTile` in a follow-up refactor. `StationMiniMap` centralizes the "tap mini-map → bottom sheet" interaction so any surface that embeds it gets the same behavior.
* 2026-05-23 — Terminology alignment. Norwegian "post" maps to English "station". Doc rewritten so English prose, widget names, code identifiers and localization keys use "station(s)" throughout. The Norwegian "Poster" label is kept as the localization value, not the doc terminology. Route plan changed: the canonical `/stations` path now belongs to the Stations list tab, and the Map tab moves to `/map`. The station-detail deep link `/stations/:exerciseUuid/:stationIndex` is preserved and shared by both tabs.
* 2026-05-23 — Status bumped to **Accepted**. The design is locked as the direction for implementation. Open questions (mini-map implementation) are not blocking for the code architecture and are decided as the implementation proceeds.
