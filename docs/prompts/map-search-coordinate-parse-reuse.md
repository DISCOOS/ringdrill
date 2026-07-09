# Reuse the typed-variable coordinate parser in the map search field

You are working in the RingDrill repository. One small, views-only fix: the map search field must resolve UTM coordinate input the same way the DESIGN-008 location variable input does, so that pasting or typing a UTM string centers the map on it. Read `AGENTS.md` rule 9.

## Background

DESIGN-008 follow-up 11 (typed variables, `VariableType.location`) introduced a single, tested coordinate parser, `parseCoordinateInput(String)` in [`lib/utils/variable_values.dart`](../../lib/utils/variable_values.dart). It accepts either a decimal `lat,lng` pair **or** a UTM string, and returns a `LatLng?` (null when it reads as neither). It is Flutter-free and already the sole coordinate parser behind the location variable field ([`lib/views/widgets/variable_value_field.dart`](../../lib/views/widgets/variable_value_field.dart)).

Crucially, `parseCoordinateInput` does two things the map search field does **not**:

1. It bounds-checks the decimal pair (`lat.abs() <= 90`, `lng.abs() <= 180`) via `_latLngPattern`, so `123,456` is correctly rejected rather than treated as a location.
2. Before calling `toLatLngFromUtm`, it **strips the app's own UTM display suffixes** — the trailing `E`/`N` on easting/northing (as produced by the app's UTM renderer, e.g. `32V 0580414E 6552008N`). `toLatLngFromUtm`'s grammar only takes bare numbers, so without this strip a UTM string copied straight out of a brief or a position card never parses. It also guards against the `NaN` that `proj4dart` can return on near-singular inputs (`isFinite` checks).

## The bug

The map search field, `_searchLocation` in [`lib/views/map_view.dart`](../../lib/views/map_view.dart) (around lines 1194–1222), re-implements coordinate parsing inline instead of reusing `parseCoordinateInput`:

* Its lat,lng branch does a naive `input.contains(",")` → `split(",")` → `double.tryParse`, with no range check.
* Its UTM branch calls **raw** `input.toLatLngFromUtm()` with no E/N normalization.

The result matches the reported symptom: a decimal `lat,lng` resolves and recenters the map, but a UTM coordinate — including the app's own displayed UTM format — does not resolve to a `LatLng`, so the map never centers on it.

## Scope of change

Views only. No model, renderer, schema, or l10n change (no new user-facing strings — this is a parser swap). Reuse the existing `parseCoordinateInput`; do not add a new parser or move `parseCoordinateInput` out of `variable_values.dart`.

`variable_values.dart` is Flutter-free and `map_view.dart` is already a Flutter widget, so importing it there is fine.

## Implementation

In `lib/views/map_view.dart`:

1. Add `import 'package:ringdrill/utils/variable_values.dart';`. If, after the edit, the direct `toLatLngFromUtm` call is gone and nothing else in the file uses `utils/projection.dart`, drop that now-unused import (let `flutter analyze` tell you).
2. In `_searchLocation`, replace **both** the inline `lat,lng` split block and the raw `input.toLatLngFromUtm()` block with a single call to `parseCoordinateInput(input)`. On a non-null, finite result: `_mapController.move(result, _mapController.camera.zoom)`, clear `_isSearching`, and `return` (same early-exit behavior the two branches have today).
3. Leave everything downstream unchanged: when `parseCoordinateInput` returns null, fall through exactly as before to the parent-supplied `searchTargets` matching and then the geocoder. Keep the existing `try/catch` + `Sentry.captureException` wrapper and the 50 ms throttle intact.

Keep the explanatory comment accurate: note that coordinate input (decimal `lat,lng` or UTM, including the app's own `…E …N` display format) is parsed by the shared `parseCoordinateInput`, and that a null result falls through to search targets and the geocoder.

## Commits

Two commits (Conventional Commits, English).

1. `fix(map): resolve UTM search input by reusing parseCoordinateInput` — the parser swap in `_searchLocation`, import fix.
2. `test(map): cover UTM and lat,lng resolution in the map search field` — see below.

List the touched files explicitly and confirm `git status` is clean at each commit.

## Tests

Add a widget/unit test for the map search field's coordinate handling. Prefer the lightest harness that can drive `_searchLocation` and observe the resulting `_mapController` move (mirror how existing `test/views/…` map tests are set up; if the search field is only reachable through a widget, pump it and enter text). Cover:

* A decimal `lat,lng` recenters the map on that point (regression — must still work).
* A UTM string in the app's own display format (`32V 0580414E 6552008N`, i.e. with `E`/`N` suffixes) recenters the map on the same point as the equivalent decimal pair — this is the bug being fixed and must fail before the change.
* A bare-number UTM string (`32V 580414 6552008`) also resolves.
* Garbage / out-of-range input (`123,456`, `not a coordinate`) does **not** move the map and falls through to the geocoder branch.

If a decent map-search widget test harness does not already exist and building one balloons the change, stop and report rather than inventing a large fixture; a focused test that calls the parsing path directly is acceptable.

## Test-loop discipline (rule 9)

Per commit: `flutter analyze` + the targeted `test/views/` map tests only. Run the full `flutter test` and `dart build cli` **once** at the end. No ARB change here, so no `make i18n`.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` with no new failures.
2. `dart build cli` succeeds (confirms `variable_values.dart` stays Flutter-free and the CLI path is unaffected).
3. Manual smoke in the map view search field: typing `59.7445, 10.2045` centers the map; typing `32V 0580414E 6552008N` centers it on the same place; garbage still falls through to place search.
4. `git diff --stat` touches only `lib/views/map_view.dart` and `test/views/…`.
5. Clean tree.

## Deliverables

Two commits, clean tree, targeted tests per commit, one full-suite gate at the end. The final commit body records that the map search field now resolves coordinate input through the shared `parseCoordinateInput`, so UTM strings — including the app's own `…E …N` display format — recenter the map, matching the location variable field. If reuse requires more than the import + call swap and a test, stop and report.
