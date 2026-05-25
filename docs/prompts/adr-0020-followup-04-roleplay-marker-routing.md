# Follow-up 04: Roleplay marker tap opens the roleplay order

Tapping a roleplay (theatre-glyph) marker in the Stations tab currently routes to the station screen via `$routeStations/<exerciseUuid>/<rp.index>`. The intended behaviour is to open the roleplay order using the same pattern that `station_screen.dart` and `lib/views/widgets/station_role_summary.dart` already follow, namely `$routeRolePlays/<rp.uuid>`. The `/roleplays/:roleUuid` route is already registered in `main_screen.dart` and `routeRolePlays` already exists in `lib/views/app_routes.dart`.

Scope is `lib/views/stations_view.dart` only.

## Order of work

1. In the `roleSpecs` builder, replace the current `onTap`
   ```dart
   onTap: () {
     final ex = _programService.getExercise(rp.exerciseUuid);
     if (ex != null) {
       context.push('$routeStations/${ex.uuid}/${rp.index}');
     }
   },
   ```
   with
   ```dart
   onTap: () => context.push('$routeRolePlays/${rp.uuid}'),
   ```

2. Drop the local `_programService.getExercise(...)` call from this branch. If that was the only place an import (or the helper itself) was used, clean up so `flutter analyze` stays quiet about unused references.

3. The station marker `onTap` (`_onStationTap`) stays untouched. Only the roleplay branch changes.

## Verification

- `flutter analyze` clean.
- `flutter test`. Report results. `test/widget_test.dart` remains known-broken.
- Smoke-check on the Stations tab: tap a theatre-glyph (roleplay) marker. It must open `RolePlayScreen` for that roleplay, not the station screen. Tap a green station pin — it must still open the station screen as before. Confirm both paths work after clustering, with the marker tap firing once the cluster has expanded.

## Constraints

- Do not touch `MapView`, `MapMarkerSpec`, `RoleMarker`, or any other call site.
- Do not change the station-marker tap path.
- Match existing `dart format` style.

## Expected diff scope

`lib/views/stations_view.dart` only. No l10n, no regenerated files.
