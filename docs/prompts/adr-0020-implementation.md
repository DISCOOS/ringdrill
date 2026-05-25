# Implement ADR-0020

Authoritative spec: [`docs/adrs/0020-map-label-and-marker-clutter.md`](../adrs/0020-map-label-and-marker-clutter.md). Read it before starting. This prompt only covers work-order and gotchas, not the design.

## Order of work

1. **Dependency.** In `pubspec.yaml`, bump `flutter_map: ^8.2.1` → `^8.2.2` and add `flutter_map_marker_cluster: ^8.2.2`. Run `flutter pub get`.

2. **New marker API in `lib/views/map_view.dart`.**
   - Add `MapMarkerSpec<K>` and `MapClusterStyle` exactly as the ADR's "Unified marker spec" section defines them.
   - Remove `markers: List<(K, String, LatLng)>`, `roleMarkers: List<(K, String, LatLng)>` and `onMarkerTap: ValueSetter<(K, String, LatLng)>?`.
   - Add `markers: List<MapMarkerSpec<K>>`, `clusterStyles: Map<Object, MapClusterStyle> = const {}`, `showLabels: bool = true`, `withClustering: bool = true`.
   - Group `widget.markers` by `clusterGroup`. Null group becomes one flat `MarkerLayer`. Each non-null group becomes one `MarkerClusterLayerWidget` with `maxClusterRadius: 45`, `padding: const EdgeInsets.all(50)`, `maxZoom: 17`, size from the style, and a circular-badge builder that uses `style.color` / `style.onColor`.
   - Render each `Marker` as a `Column(FeatureLabel(spec.label), spec.child)` wrapped in a `GestureDetector(onTap: spec.onTap, behavior: HitTestBehavior.deferToChild)`.
   - When `withClustering: false`, ignore `clusterGroup` and emit everything into a single flat `MarkerLayer`.

3. **Lift `_RoleMarker` out.** Move it to `lib/views/widgets/role_marker.dart` as a public widget. Remove its internal label rendering (the `Column` with `FeatureLabel` inside `_RoleMarker.build`). `MapView` now owns label rendering for every spec.

4. **Zoom-gated labels.**
   - Add `MapConfig.labelMinZoom = 14.0`.
   - Inside `FeatureLabel` (or a new internal label-wrapper in `map_view.dart`), read the current zoom via `MapCamera.of(context)` so it rebuilds on camera change.
   - Below `labelMinZoom - 1`: return `SizedBox.shrink()`. Between `labelMinZoom - 1` and `labelMinZoom`: `AnimatedOpacity` from 0 to 0.55. At or above: 0.55.
   - `showLabels: false` short-circuits the whole label slot to `SizedBox.shrink()`, regardless of zoom.

5. **Migrate call sites.** Each one to the new `MapMarkerSpec` form.
   - `lib/views/stations_view.dart`: one combined list. `clusterGroup: 'stations'` for station locations, `clusterGroup: 'roleplays'` for roleplay positions. `clusterStyles` built from Theme: green for stations (`Colors.green` / `Colors.white`), tertiary for roleplays (`colorScheme.tertiaryContainer` / `colorScheme.onTertiaryContainer`). Per-spec `onTap` replaces the old `onMarkerTap`.
   - `lib/views/roleplay_screen.dart`: roleplay group only.
   - `lib/views/program_view.dart`: one group, `withClustering: false`.
   - `lib/views/widgets/station_mini_map.dart`: one group, `withClustering: false`.
   - `lib/views/map_picker_screen.dart`, `lib/views/map_screen.dart`: one group, default styling.

6. **Toggles + banner in `stations_view.dart`.**
   - Two new FABs in `topRightCommands` after the existing `_buildVisibilityFab`:
     1. **Labels FAB.** Icon swaps between `Icons.label` and `Icons.label_off`. Tap toggles a local `_showLabels` field, passed to `MapView.showLabels`. No badge.
     2. **Marker-types FAB.** Opens a `showModalBottomSheet` with two `SwitchListTile`s (`showStations`, `showRoleplays`) wrapped in `StatefulBuilder` for live count updates. Sheet pushes changes back via `setState`. FAB carries `Badge.count(n)` where `n` is the number of types currently off (1 or 2).
   - Banner: when exactly one filter type is active, keep today's specific text (exercises hidden, stations off, roleplays off, or labels off). When two or more are active, fall back to a single banner with text `filterActiveCombined` and a "Show all" button that clears `_hiddenExercises`, sets both marker-type switches back on, and sets `_showLabels = true`.

7. **Localization.** Add to both `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb`:
   - `showLabels` → "Show labels" / "Vis etiketter"
   - `hideLabels` → "Hide labels" / "Skjul etiketter"
   - `markerTypes` → "Marker types" / "Markørtyper"
   - `showStations` → "Show stations" / "Vis poster"
   - `showRoleplays` → "Show roleplays" / "Vis markører"
   - `filterActiveCombined` → "Filter active" / "Filter aktivt"
   `showAll` already exists.

8. **Verification.**
   - `make build` to regenerate l10n.
   - `flutter analyze` must be clean.
   - `flutter test`. Report the result. `test/widget_test.dart` is known-broken (default counter template) and must not be claimed as passing.
   - Smoke-test stations_view manually or note it as pending: dense cluster at city zoom collapses to one badge per group, expands on tap, labels disappear below labelMinZoom and reappear above, both new FABs toggle as described, banner switches to combined text when two filter types are active.

## Constraints

- No changes to `lib/models/`, `lib/services/`, `bin/` or `netlify/`. This is a view-layer refactor.
- `MapView` stays domain-agnostic. It must not reference "station" or "roleplay" anywhere. Only the call sites know what `'stations'` and `'roleplays'` mean.
- Keep `bin/ringdrill.dart` Flutter-free. None of the new code is reachable from it, but check.
- Web-safe imports only. `MapView` already follows this. Do not introduce `dart:html` or `package:web` through the new widgets.
- Match existing `dart format` style. No new lint suppressions without a code comment explaining why.

## Expected diff scope

`pubspec.yaml`, `lib/views/map_view.dart`, `lib/views/widgets/role_marker.dart` (new), the six migrated call-site files, `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb`, and the regenerated `lib/l10n/app_localizations*.dart`. No other files should change.
