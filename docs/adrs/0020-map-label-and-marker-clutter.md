---
status: accepted
date: 2026-05-25
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0020: Reduce map label and marker clutter via clustering, a unified marker spec, zoom-gated labels and per-layer visibility toggles

## Context and problem statement

The shared `MapView` in [`lib/views/map_view.dart`](../../lib/views/map_view.dart) renders every station as a green `Icons.place` pin with a `FeatureLabel` text card on top, and every roleplay position as a rounded-square theatre glyph with its own label. Both layers are emitted unconditionally for every marker in the input list. The only filter that exists today, `_hiddenExercises` in [`stations_view.dart`](../../lib/views/stations_view.dart), operates on whole exercises.

Three problems surface in practice:

* Stations belonging to the same exercise often sit within a few metres of each other. At country- or city-level zoom the pins overlap and the labels stack on top of one another.
* Roleplay positions tend to cluster around the same stations, so the second marker layer compounds the problem rather than separating cleanly from the first.
* A user who wants to see only stations, only roleplays, or no labels has no way to express that.

There is also a fourth, structural problem: `MapView` exposes two named fields (`markers` and `roleMarkers`) for what is conceptually the same idea (a marker with a label and a tap target). This leaks domain knowledge into a widget that is supposed to be domain-agnostic, and would force two near-identical cluster-layer blocks once clustering is introduced. This ADR addresses the clutter and the structural leak in one change.

## Decision drivers

* `MapView` must remain domain-agnostic. Feature-specific UI hooks in through slot props, not through new domain fields.
* The fix must work on every call site: `StationsView`, `ProgramView`, `MapScreen`, `MapPickerScreen`, `RolePlayScreen`, `StationMiniMap`.
* We have ~20–100 markers in practice, not thousands. Animation quality matters more than raw clustering throughput.
* `flutter_map` is pinned at `^8.2.1`. A minor bump is acceptable; a fork or major rewrite is not.
* The existing exercise filter, banner pattern and "Show all" recovery action in `stations_view.dart` should be reused, not duplicated.

## Considered options

* **Option A: Clustering plugin + unified `MapMarkerSpec` + zoom-gated labels + per-layer toggles (chosen).** Adopt `flutter_map_marker_cluster`, collapse `markers` and `roleMarkers` into a single `List<MapMarkerSpec<K>>` with an optional `clusterGroup` discriminator, gate `FeatureLabel` behind a zoom threshold, and expose a `showLabels` flag plus call-site-owned visibility toggles.
* **Option B: As A but keep the separate `markers` and `roleMarkers` fields.** Smaller diff, but leaves the structural leak in place and produces two near-identical cluster-layer blocks whose badges can overlap at the same point.
* **Option C: `flutter_map_supercluster` instead of `flutter_map_marker_cluster`.** Faster, less animated, no popup integration.
* **Option D: Pure-internal decluttering / collision logic.** No new dependency, full control, but reinvents a solved problem.
* **Option E: Status quo plus call-site visibility toggles only.** Adds the toggle FAB but does not address icon overlap or label stacking.

## Decision outcome

Chosen option: **Option A**, because it solves the clutter, removes the domain leak in `MapView`, and reduces the marker API to one extensible shape while we are already touching every call site for clustering and visibility toggles.

### Dependency change

* Bump `flutter_map: ^8.2.1` → `^8.2.2` in [`pubspec.yaml`](../../pubspec.yaml).
* Add `flutter_map_marker_cluster: ^8.2.2`. `flutter_map_marker_popup` is pulled in transitively but is not used directly.

### Unified marker spec

`MapView` exposes a single immutable spec and an optional style map for clusters:

```dart
class MapMarkerSpec<K> {
  const MapMarkerSpec({
    required this.id,
    required this.label,
    required this.point,
    required this.child,
    this.clusterGroup,
    this.onTap,
  });
  final K id;
  final String label;
  final LatLng point;
  final Widget child;          // the icon (Icons.place, RoleMarker, ...)
  final Object? clusterGroup;  // null = render flat; same key = same cluster
  final VoidCallback? onTap;
}

class MapClusterStyle {
  const MapClusterStyle({
    this.color,
    this.onColor,
    this.size = const Size(40, 40),
  });
  final Color? color;
  final Color? onColor;
  final Size size;
}
```

`MapView` groups the incoming list by `clusterGroup`:

* Markers with a null group are emitted into one flat `MarkerLayer`.
* Each non-null group becomes one `MarkerClusterLayerWidget` configured from `clusterStyles[group]` or a sensible default. One group always becomes exactly one cluster, so two groups never produce overlapping cluster badges at the same point.

Each `Marker` is rendered as `Column(FeatureLabel(spec.label) + spec.child)` with the label zoom-gated (see below). Tap is forwarded to `spec.onTap` via an internal `GestureDetector`, replacing the existing global `onMarkerTap`.

The previous `_RoleMarker` widget moves out of `map_view.dart` to a public widget (e.g. `lib/views/widgets/role_marker.dart`) and stops rendering its own label, since `MapView` now owns label rendering.

### Clustering

Default cluster configuration applied to every `MarkerClusterLayerWidget`:

* `maxClusterRadius: 45`.
* `size: const Size(40, 40)` (overridable per group).
* `padding: const EdgeInsets.all(50)` so cluster-tap zoom-in does not push the bounds against the FAB column.
* `maxZoom: 17`.
* `builder:` returns a circular badge sized from the group's style, count centred in `onColor`.

`StationMiniMap` and the inline map in `ProgramView` keep the flat-`MarkerLayer` path. `MapView` gains a `withClustering` bool (default `true`); the mini-map call sites pass `false`.

### Zoom-gated labels

* New constant `MapConfig.labelMinZoom = 14.0`. Below this zoom, the label slot returns `SizedBox.shrink()`.
* The label slot reads the current zoom via `MapCamera.of(context)` so it rebuilds when the camera changes.
* `AnimatedOpacity` ramps from 0 at `labelMinZoom - 1` to 0.55 at `labelMinZoom` for a softer transition.

The threshold is a constant for now. Exposing it as a per-call prop is deferred until a call site asks for it.

### Per-layer visibility toggles

`MapView` gets one new flag:

* `showLabels: bool = true` — global on/off for the label slot. The zoom-gate still applies on top.

Marker-type visibility stays a call-site concern: with a unified list, the call site builds the spec list it wants and omits whatever the user has toggled off.

In `StationsView`, the existing `_buildVisibilityFab` for exercises gains two siblings in `topRightCommands`:

1. **Labels** FAB (`Icons.label` / `Icons.label_off`). Toggles `_showLabels`, forwarded to `MapView.showLabels`. No badge — the icon swap is the affordance.
2. **Marker types** FAB (`Icons.tune_outlined` over `Icons.place`). Opens a bottom sheet with two switches: "Show stations" / "Vis poster" and "Show roleplays" / "Vis markører". Carries `Badge.count` when at least one type is off.

The existing filter banner is reused. When two or more filter types are active it falls back to a generic "Filter active" / "Filter aktivt" label. The "Show all" action clears `_hiddenExercises`, restores both marker-type toggles and turns labels back on.

### Localization

New keys in [`lib/l10n/app_en.arb`](../../lib/l10n/app_en.arb) and [`lib/l10n/app_nb.arb`](../../lib/l10n/app_nb.arb):

* `showLabels` — "Show labels" / "Vis etiketter".
* `hideLabels` — "Hide labels" / "Skjul etiketter".
* `markerTypes` — "Marker types" / "Markørtyper".
* `showStations` — "Show stations" / "Vis poster".
* `showRoleplays` — "Show roleplays" / "Vis markører".
* `filterActiveCombined` — "Filter active" / "Filter aktivt".

`showAll` already exists and is reused for the combined banner.

### Public API summary on `MapView`

```dart
MapView({
  ...existing fields,
  required List<MapMarkerSpec<K>> markers,     // replaces markers + roleMarkers
  Map<Object, MapClusterStyle> clusterStyles = const {},
  bool showLabels = true,
  bool withClustering = true,
});
```

Removed: the old `markers: List<(K, String, LatLng)>`, `roleMarkers: List<(K, String, LatLng)>` and `onMarkerTap: ValueSetter<(K, String, LatLng)>?`. Tap is now per-spec via `MapMarkerSpec.onTap`.

### Call-site migration

Every `MapView` call site is touched. The mechanical pattern is the same everywhere:

* `lib/views/stations_view.dart` — build one list combining stations and roleplays, set `clusterGroup: 'stations'` / `'roleplays'`, attach `onTap` per spec, supply `clusterStyles` from the active theme.
* `lib/views/roleplay_screen.dart` — same pattern, roleplay group only.
* `lib/views/program_view.dart` — single group, `withClustering: false`.
* `lib/views/widgets/station_mini_map.dart` — single group, `withClustering: false`.
* `lib/views/map_picker_screen.dart`, `lib/views/map_screen.dart` — single group, default styling.
* `_RoleMarker` is lifted out of `map_view.dart` into its own widget file.

### Consequences

* Good: City-zoom maps stop being a wall of overlapping labels.
* Good: One cluster per group, so cluster badges never overlap at the same point.
* Good: `MapView` becomes truly domain-agnostic — no more `markers` vs `roleMarkers` split.
* Good: Adding a future marker type (waypoints, hazards) is a new spec at the call site, not a new field on `MapView`.
* Good: Users get fine-grained control over visibility using one familiar filter banner.
* Bad: One more runtime dependency, plus its transitive `flutter_map_marker_popup`.
* Bad: Every `MapView` call site must migrate to the new API in the same change.
* Bad: Cluster builders, marker rendering and zoom-gated labels share no theming surface; the colour story must be kept in sync by hand.
* Bad: The 14.0 zoom threshold is a magic number. The label toggle FAB is the escape hatch when it is wrong for a given drill.

## Pros and cons of the options

### Option A — Plugin + unified spec + zoom-gated labels + toggles

* Good: One change addresses clutter, structural leak and missing controls together.
* Good: One group → one cluster, no inter-group badge overlap.
* Good: Extensible for future marker types without new fields on `MapView`.
* Bad: Breaks the existing `MapView` API; every call site migrates at once.

### Option B — As A but keep the dual-list API

* Good: Smaller diff. Call-site signatures unchanged.
* Bad: Two cluster layers can still produce overlapping badges at the same point.
* Bad: Leaves the domain leak in `MapView` for a future ADR to clean up — and that ADR would touch every call site anyway, so the cost is paid twice.

### Option C — `flutter_map_supercluster`

* Good: Faster clustering on large datasets.
* Bad: No animation between zoom levels.
* Bad: Our marker counts do not need the throughput.

### Option D — Internal decluttering

* Good: Zero new dependencies.
* Bad: Reinvents a well-understood Leaflet feature. A naive "do not draw overlapping markers" loses the count cue a cluster badge provides for free.
* Bad: Maintenance cost lands on us forever.

### Option E — Status quo plus call-site visibility toggles

* Good: Smallest change. No new dependency, no new constant.
* Bad: Does not address icon overlap or label stacking.

## Links

* Related ADRs:
  * [ADR-0018](./0018-roleplayer-data-model.md)
  * [ADR-0019](./0019-roleplayer-participant-role.md)
* Related code:
  * `lib/views/map_view.dart` — `MapMarkerSpec`, `MapClusterStyle`, clustering, label gating, `showLabels`, `withClustering`.
  * `lib/views/widgets/role_marker.dart` (new) — extracted from `map_view.dart`.
  * `lib/views/stations_view.dart` — the two new FABs, combined banner, hosted toggle state, spec construction.
  * `lib/views/roleplay_screen.dart`, `lib/views/program_view.dart`, `lib/views/widgets/station_mini_map.dart`, `lib/views/map_picker_screen.dart`, `lib/views/map_screen.dart` — migrate to `MapMarkerSpec`.
  * `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb` — new strings.
* External references:
  * [flutter_map_marker_cluster](https://pub.dev/packages/flutter_map_marker_cluster)
  * [flutter_map programmatic interaction](https://docs.fleaflet.dev/usage/programmatic-interaction)
