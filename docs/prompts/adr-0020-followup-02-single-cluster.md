# Follow-up 02: One cluster for all markers, and preserve camera on filter changes

Two small refinements on top of follow-up 01, both local to `lib/views/stations_view.dart`. No changes to `MapView`, the marker API, l10n or any other file.

## What is wrong today

1. **Markers cluster by type.** `stationSpecs` and `roleSpecs` are emitted with `clusterGroup: 'stations'` and `clusterGroup: 'roleplays'` respectively, producing two cluster badges that visually collide whenever both types sit at the same place.
2. **Filter changes reset the camera.** Toggling any switch in the filter sheet or pressing "Show all" in either banner calls `_recenter()`, which runs `_mapController.fitCamera(...)` and throws away the user's pan and zoom. The behaviour is inherited from the original exercises-only sheet and stopped making sense once the sheet also controls labels and marker types.

Type identity is still preserved on each leaf marker (green pin for stations, role marker for roleplays), so a unified cluster does not lose that distinction. Manual recentering remains available via the bottom-right `center` FAB and via `stationsTabReselectTick`.

## Order of work

1. **One `clusterGroup` for every spec.** In the `stationSpecs` and `roleSpecs` list builders, set `clusterGroup: 'markers'` on both.

2. **One entry in `clusterStyles`.** Replace the two-entry map with:
   ```dart
   clusterStyles: {
     'markers': MapClusterStyle(
       color: scheme.primaryContainer,
       onColor: scheme.onPrimaryContainer,
     ),
   },
   ```
   `primaryContainer` is chosen because it does not favour either type's leaf-marker colour and stays readable in both light and dark themes.

3. **Stop refitting on filter changes.** In `_openFilterSheet`, change the inline helper from
   ```dart
   void applyAndRefit() {
     setState(() {});
     _recenter();
   }
   ```
   to
   ```dart
   void apply() {
     setState(() {});
   }
   ```
   Rename every call site inside the sheet (exercise toggle row, "Show all" button) from `applyAndRefit()` to `apply()`.

4. **Stop refitting from the banners.** In both `_buildFilterBanner` and `_buildCombinedFilterBanner`, change the `TextButton.onPressed` body from
   ```dart
   setState(...);
   _recenter();
   ```
   to just the `setState(...)` part, with no `_recenter()` call.

5. **Leave `_recenter` itself alone.** It stays wired to `stationsTabReselectTick.addListener(_recenter)` in `initState`. Re-selecting the Stations tab should still refit the camera.

## Verification

- `flutter analyze` clean.
- `flutter test`. Report results. `test/widget_test.dart` remains known-broken.
- Smoke-check on Stations tab:
  - A city-level view with both stations and roleplays in roughly the same area shows one badge per cluster, not two stacked. Tap the cluster, zoom in, confirm the individual green pins and role markers reappear.
  - Pan and zoom the map to an arbitrary corner. Open the filter sheet and toggle exercises, stations, roleplays and labels in turn. The camera must stay exactly where the user left it for every toggle.
  - Press "Show all" from both the sheet and the banner. The camera must still stay put.
  - Leave the Stations tab and re-select it. The camera must refit to the visible markers at that point, proving the tab-reselect path is untouched.

## Constraints

- Do not touch `MapView`, `MapMarkerSpec`, `MapClusterStyle`, `role_marker.dart`, any other call site, or `pubspec.yaml`.
- Do not delete `'stations'` / `'roleplays'` strings from anywhere else (no other file references them).
- Do not introduce a new "auto-recenter on demand" UI element. The existing center FAB is the recovery path.
- Match existing `dart format` style.

## Expected diff scope

`lib/views/stations_view.dart` only. No l10n, no regenerated files.
