# Follow-up 03: Zoom bounds on tile layers and camera

Two related fixes in `lib/views/map_view.dart`, both about making zoom bounds actually hold:

1. The two `TileLayer` factories in `MapConfig` (`osmLayer`, `topoLayer`) do not declare any zoom bounds, so flutter_map defaults `maxNativeZoom` to 19 and tries to fetch Kartverket topo tiles above the published webmercator range (typically 18). Above that the network returns empty tiles.
2. `MapOptions` does not pass `minZoom` / `maxZoom`, so only the `_zoomIn` / `_zoomOut` FABs respect `widget.minZoom` / `widget.maxZoom`. Pinch, scroll-wheel and double-tap-zoom let the camera drift past those bounds.

Scope is `lib/views/map_view.dart` only.

## Order of work

1. **Zoom bounds on `MapConfig.topoLayer`:**
   ```dart
   static TileLayer get topoLayer => TileLayer(
     key: const ValueKey('topo'),
     urlTemplate:
         'https://cache.kartverket.no/v1/wmts/1.0.0/topo/default/webmercator/{z}/{y}/{x}.png',
     subdomains: const [],
     userAgentPackageName: 'discoos.org/ringdrill',
     minZoom: 0,
     maxZoom: 19,
     minNativeZoom: 0,
     maxNativeZoom: 18,
   );
   ```
   `maxNativeZoom: 18` matches Kartverket's published webmercator range. `maxZoom: 19` keeps the layer visible across the whole camera range, so flutter_map upscales the deepest available tile instead of dropping the layer above 18.

2. **Zoom bounds on `MapConfig.osmLayer`:**
   ```dart
   static TileLayer get osmLayer => TileLayer(
     key: const ValueKey('osm'),
     urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
     userAgentPackageName: 'discoos.org/ringdrill',
     subdomains: const [],
     minZoom: 0,
     maxZoom: 19,
     minNativeZoom: 0,
     maxNativeZoom: 19,
   );
   ```
   OSM serves tiles natively through zoom 19, so `maxNativeZoom` matches `maxZoom`.

3. **Camera bounds in `MapOptions`.** Inside `MapView.build`, where `MapOptions(...)` is constructed, add `minZoom` and `maxZoom`:
   ```dart
   options: MapOptions(
     initialZoom: widget.initialZoom,
     initialCenter: widget.initialCenter,
     initialCameraFit: widget.initialFit,
     minZoom: widget.minZoom,
     maxZoom: widget.maxZoom,
     interactionOptions: InteractionOptions(
       flags: widget.interactionFlags,
     ),
     onTap: (tapPosition, point) { ... },
   ),
   ```
   This caps every camera-moving path — pinch, scroll-wheel, double-tap-zoom, `fitCamera`, and the FABs — to the same `[widget.minZoom, widget.maxZoom]` interval the `_zoomIn` / `_zoomOut` clamps already use.

4. **Leave the `MapView` constructor defaults alone.** `minZoom: 2` and `maxZoom: 19` stay as today. They are now actually enforced.

## Verification

- `flutter analyze` clean.
- `flutter test`. Report results. `test/widget_test.dart` remains known-broken.
- Smoke-check:
  - Switch to the Topo layer, zoom past 18 with pinch or scroll-wheel. Tiles should appear upscaled, not blank. No requests should be made for topo tiles at `{z} > 18`.
  - Switch to OSM and zoom to 19. Tiles should be sharp (native).
  - Try to zoom past 19 with scroll-wheel, pinch and double-tap. The camera must stop at 19 in every case, matching the behaviour of the `+` FAB.
  - Try to zoom below 2 the same way. The camera must stop at 2.
  - Call sites that pass their own `minZoom` / `maxZoom` (e.g. mini-maps) should still respect those tighter bounds rather than the defaults.

## Constraints

- Do not change `urlTemplate`, headers or other fields on the existing tile layers.
- Do not change the default `minZoom` / `maxZoom` on `MapView`.
- Do not add a new layer or remove an existing one.
- Match existing `dart format` style.

## Expected diff scope

`lib/views/map_view.dart` only. No l10n, no regenerated files.
