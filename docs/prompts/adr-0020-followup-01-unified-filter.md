# Follow-up 01: Unified filter command in StationsView

The ADR-0020 implementation landed three separate FABs in `topRightCommands` (exercises, labels, marker types). Stacked together they crowd the top-right column and two of them use near-identical `Icons.tune` variants. Consolidate them into one filter command with a single bottom sheet.

Scope is `lib/views/stations_view.dart` and the two `.arb` files. `MapView` itself does not change — this is a call-site refactor on top of the unified `MapMarkerSpec` API already in place.

## Order of work

1. **Replace the three FABs with one.** In `topRightCommands`, drop `_buildVisibilityFab`, `_buildLabelsFab` and `_buildMarkerTypesFab`. Add a single `_buildFilterFab(context, localizations, allExercises)` that returns a `FloatingActionButton` with `heroTag: 'filter'`, `tooltip: l.filter`, `child: const Icon(Icons.filter_alt)`. Wrap in `Badge.count(count: activeDimensions, child: fab)` when at least one dimension is active.

   `activeDimensions` is computed as:
   ```
   (hiddenCount > 0 ? 1 : 0)
   + (!_showStations ? 1 : 0)
   + (!_showRoleplays ? 1 : 0)
   + (!_showLabels ? 1 : 0)
   ```
   Range 0–4.

2. **Single bottom sheet.** Replace `_openVisibilitySheet` and `_openMarkerTypesSheet` with one `_openFilterSheet(context, l, allExercises)`. The sheet uses `showDragHandle: true`, `isScrollControlled: true`, and a `StatefulBuilder` so live counts and the "Show all" enable-state update as the user toggles.

   Sheet layout, top to bottom:

   - **Section header** `l.filterShowOnMap` ("Vis på kart" / "Show on map").
   - Three `SwitchListTile`s:
     - `l.showStations` bound to `_showStations`.
     - `l.showRoleplays` bound to `_showRoleplays`.
     - `l.showLabels` bound to `_showLabels`.
   - `Divider`.
   - **Section header** combining `l.exercise(2)` ("Øvelser" / "Exercises") and the existing "X of N" count, styled like the current `_openVisibilitySheet` header.
   - The existing per-exercise toggle list. Reuse the row builder verbatim from today's sheet.
   - `Divider`.
   - Bottom action row: a right-aligned `TextButton` labelled `l.showAll`, disabled when `activeDimensions == 0`. On tap it clears `_hiddenExercises`, sets `_showStations = true`, `_showRoleplays = true`, `_showLabels = true`, calls `applyAndRefit()`, and pops the sheet.

   The sheet's `applyAndRefit` callback stays the same as today: `setState(() {}); _recenter();`. Toggling display switches does not require a refit (markers stay where they are), but a no-op `setState` on the parent is still needed so `MapView.showLabels` and the spec construction pick up the new flags.

3. **Drop unused helpers.** Remove `_buildVisibilityFab`, `_buildLabelsFab`, `_buildMarkerTypesFab`, `_openVisibilitySheet`, `_openMarkerTypesSheet` once the new ones are in place. Keep `_buildFilterBanner` and `_buildCombinedFilterBanner` exactly as they are — banner logic is unchanged.

4. **Localization.** Add to both `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb`:
   - `filter` → "Filter" / "Filter"
   - `filterShowOnMap` → "Show on map" / "Vis på kart"

   `showStations`, `showRoleplays`, `showLabels`, `hideLabels`, `markerTypes` and `filterActiveCombined` already exist from the initial ADR-0020 work. `hideLabels` and `markerTypes` are no longer referenced after this refactor — leave the keys in place, do not delete them (a future use is plausible and deleting localized strings is high-friction).

5. **Verification.**
   - `make build` to regenerate l10n.
   - `flutter analyze` clean.
   - `flutter test`. Report results. `test/widget_test.dart` remains known-broken.
   - Smoke-check: open Stations tab, tap the filter FAB, toggle each switch in turn, confirm badge count updates and reflects 0–4, confirm "Show all" resets all four dimensions and disables itself afterwards, confirm the banner above the map still switches between specific text (only exercises filtered) and generic text (any other combination).

## Constraints

- No changes to `lib/views/map_view.dart`, `lib/views/widgets/role_marker.dart`, the other migrated call sites, or `pubspec.yaml`. This is a stations_view-local refactor.
- Keep the existing banner behaviour. Do not collapse the specific-vs-generic banner into one.
- Do not introduce new icons beyond `Icons.filter_alt`. The previous `Icons.label`, `Icons.label_off`, `Icons.tune`, `Icons.tune_outlined` usage goes away with the old FABs.
- Match existing `dart format` style. No new lint suppressions without a comment.

## Expected diff scope

`lib/views/stations_view.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb`, regenerated `lib/l10n/app_localizations*.dart`. Nothing else should change.
