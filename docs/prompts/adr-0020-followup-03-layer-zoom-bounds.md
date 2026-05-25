# Follow-up 03: Per-layer zoom bounds in MapConfig

The two `TileLayer` factories in `lib/views/map_view.dart` (`MapConfig.osmLayer`, `MapConfig.topoLayer`) do not declare any zoom bounds. flutter_map then defaults `maxNativeZoom` to 19 and tries to fetch tiles at zoom 18–19 from Kartverket's cache, which only publishes webmercator topo tiles up to zoom 18 in practice (see [`cache.kartverket.no`](https://cache.kartverket.no/) and the WMTS capabilities document). Above that the network returns 404s or empty tiles. Introduce explicit min/max bounds per layer so each layer only fetches what its source actually serves and over-zoom is handled by upscaling instead of dropping out.

Scope is `lib/views/map_view.dart` only.

## Order of work

1. **Add zoom bounds to `MapConfig.topoLayer`:**
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
   `maxNativeZoom: 18` matches Kartverket's published webmercator range. `maxZoom: 19` keeps the layer visible across the whole camera range so the user does not see the layer pop out when zooming past 18 — flutter_map upscales the deepest available tile.

2. **Add zoom bounds to `MapConfig.osmLayer`:**
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

3. **Leave `MapView.minZoom` and `MapView.maxZoom` alone.** They are the camera's hard cap and still default to `2` and `19`. The per-layer bounds operate underneath those.

4. **Verification.**
   - `flutter analyze` clean.
   - `flutter test`. Report results. `test/widget_test.dart` remains known-broken.
   - Smoke-check: switch the layer toggle to Topo, zoom to 18, then to 19. Tiles at 19 should appear upscaled instead of disappearing or showing blank tiles. Switch to OSM and zoom to 19 — tiles should be sharp (native). At zoom 2 (the camera's minimum), both layers should still render.
   - Check the network panel (or `flutter_map` debug logs) if available: no requests should be made for topo tiles at `{z} > 18`.

## Constraints

- Do not change `urlTemplate`, headers or any other field on the existing tile layers.
- Do not change `MapView.minZoom` / `MapView.maxZoom` defaults.
- Do not add a new layer or remove an existing one.
- Match existing `dart format` style.

## Expected diff scope

`lib/views/map_view.dart` only. No l10n, no regenerated files.
