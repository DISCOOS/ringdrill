import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/views/map_view.dart';

/// True when both lat and lon are finite (no NaN, no infinity). flutter_map
/// and latlong2 throw `FormatException("LatLng is not finite: ...")` the
/// moment a non-finite point reaches projection, so every extension here
/// filters its input through this gate before touching coordinates.
bool _isFiniteLatLng(LatLng p) =>
    p.latitude.isFinite && p.longitude.isFinite;

/// Public predicate for callers that build [MapMarkerSpec]s outside the
/// [StationLocationX.toMarkerSpecs] convenience (RolePlay markers in
/// `stations_view.dart`, per-station markers in `coordinator_screen.dart`,
/// mini-maps that take a single [LatLng]). Returns true when [p] is non-null
/// and both lat/lon are finite. Use as `if (!p.isFiniteOrNull) continue;`
/// or `.where((m) => m.position.isFiniteOrNull)`.
///
/// A single NaN point poisons the entire [MarkerLayer] build pass — see the
/// crash bundle around commit 5e7cff0 where five Sentry issues turned out to
/// be the same cascade. [MapView] also has a last-line defence, but filtering
/// at the producer keeps the offending entity out of `clusterMarkers.length`
/// counts and search-result lists.
extension LatLngFiniteX on LatLng? {
  bool get isFiniteOrNull {
    final p = this;
    return p != null && _isFiniteLatLng(p);
  }
}

extension LatlngListX on Iterable<LatLng> {
  /// Same as the iterable, but with any non-finite [LatLng] removed. Used
  /// to keep NaN coordinates from poisoning [average]/[fit]/[centroidFit].
  /// Filters defensively rather than at the source so a single bad row in
  /// storage cannot prevent the rest of the map from rendering.
  Iterable<LatLng> get _finite => where(_isFiniteLatLng);

  LatLng average([LatLng? initialCenter]) {
    final pts = _finite.toList(growable: false);
    if (pts.isEmpty) return initialCenter ?? MapConfig.initialCenter;

    double sumLat = 0.0;
    double sumLng = 0.0;

    for (var coordinate in pts) {
      sumLat += coordinate.latitude;
      sumLng += coordinate.longitude;
    }

    double averageLat = sumLat / pts.length;
    double averageLng = sumLng / pts.length;

    return LatLng(averageLat, averageLng);
  }

  CameraFit? fit([EdgeInsets padding = const EdgeInsets.all(72)]) {
    final pts = _finite.toList(growable: false);
    return pts.length < 2
        ? null
        : CameraFit.coordinates(padding: padding, coordinates: pts);
  }

  /// CameraFit that keeps the *centroid* (arithmetic mean of all points)
  /// at the exact centre of the viewport, while still including every
  /// point. flutter_map's [CameraFit.coordinates] centres on the
  /// bounding-box midpoint instead, which drifts toward outliers when
  /// the points are unevenly distributed. We build symmetric bounds
  /// around the centroid with the largest lat/lng delta, so all points
  /// stay visible *and* the centroid is dead centre.
  CameraFit? centroidFit([EdgeInsets padding = const EdgeInsets.all(72)]) {
    final pts = _finite.toList(growable: false);
    if (pts.length < 2) return null;

    final centroid = pts.average();
    if (!_isFiniteLatLng(centroid)) return null;
    double maxLatDelta = 0;
    double maxLngDelta = 0;
    for (final p in pts) {
      maxLatDelta = math.max(
        maxLatDelta,
        (p.latitude - centroid.latitude).abs(),
      );
      maxLngDelta = math.max(
        maxLngDelta,
        (p.longitude - centroid.longitude).abs(),
      );
    }
    // Guard against zero-extent bounds when all points coincide, and
    // against NaN propagation from any pathological arithmetic above.
    if (!maxLatDelta.isFinite || !maxLngDelta.isFinite) return null;
    if (maxLatDelta == 0 && maxLngDelta == 0) return null;

    final bounds = LatLngBounds(
      LatLng(
        centroid.latitude - maxLatDelta,
        centroid.longitude - maxLngDelta,
      ),
      LatLng(
        centroid.latitude + maxLatDelta,
        centroid.longitude + maxLngDelta,
      ),
    );
    return CameraFit.bounds(padding: padding, bounds: bounds);
  }
}

extension StationLocationX on Iterable<StationLocation> {
  LatLng average([LatLng? initialCenter]) {
    return map((e) => e.$3).average(initialCenter);
  }

  CameraFit? fit([EdgeInsets padding = const EdgeInsets.all(72)]) {
    return map((e) => e.$3).fit(padding);
  }

  /// Converts each location to a [MapMarkerSpec] with the standard green
  /// station icon. Optional [clusterGroup] and [onTap] factory are forwarded.
  /// Locations whose point is not finite are dropped: a NaN point would
  /// throw on the next projection pass and take the whole map with it.
  ///
  /// Locations whose id is in [activeIds] are rendered in [activeColor]
  /// (falling back to [color] when null) and flagged
  /// [MapMarkerSpec.highlighted] so their cluster reads as live too. The
  /// default keeps every station the original green.
  List<MapMarkerSpec<(String, int)>> toMarkerSpecs({
    Object? clusterGroup,
    void Function((String, int) id)? onTap,
    Set<(String, int)> activeIds = const <(String, int)>{},
    Color color = Colors.green,
    Color? activeColor,
  }) =>
      where((m) => _isFiniteLatLng(m.$3))
          .map((m) {
            final isActive = activeIds.contains(m.$1);
            return MapMarkerSpec<(String, int)>(
              id: m.$1,
              label: m.$2,
              point: m.$3,
              child: Icon(
                Icons.place,
                color: isActive ? (activeColor ?? color) : color,
                size: 32,
              ),
              clusterGroup: clusterGroup,
              highlighted: isActive,
              onTap: onTap == null ? null : () => onTap(m.$1),
            );
          })
          .toList();
}
