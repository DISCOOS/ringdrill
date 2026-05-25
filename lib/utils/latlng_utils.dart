import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/views/map_view.dart';

extension LatlngListX on Iterable<LatLng> {
  LatLng average([LatLng? initialCenter]) {
    if (isEmpty) return initialCenter ?? MapConfig.initialCenter;

    double sumLat = 0.0;
    double sumLng = 0.0;

    for (var coordinate in this) {
      sumLat += coordinate.latitude;
      sumLng += coordinate.longitude;
    }

    double averageLat = sumLat / length;
    double averageLng = sumLng / length;

    return LatLng(averageLat, averageLng);
  }

  CameraFit? fit([EdgeInsets padding = const EdgeInsets.all(72)]) {
    return length < 2
        ? null
        : CameraFit.coordinates(padding: padding, coordinates: toList());
  }

  /// CameraFit that keeps the *centroid* (arithmetic mean of all points)
  /// at the exact centre of the viewport, while still including every
  /// point. flutter_map's [CameraFit.coordinates] centres on the
  /// bounding-box midpoint instead, which drifts toward outliers when
  /// the points are unevenly distributed. We build symmetric bounds
  /// around the centroid with the largest lat/lng delta, so all points
  /// stay visible *and* the centroid is dead centre.
  CameraFit? centroidFit([EdgeInsets padding = const EdgeInsets.all(72)]) {
    final pts = toList(growable: false);
    if (pts.length < 2) return null;

    final centroid = pts.average();
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
    // Guard against zero-extent bounds when all points coincide.
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
  List<MapMarkerSpec<(String, int)>> toMarkerSpecs({
    Object? clusterGroup,
    void Function((String, int) id)? onTap,
  }) =>
      map(
        (m) => MapMarkerSpec<(String, int)>(
          id: m.$1,
          label: m.$2,
          point: m.$3,
          child: const Icon(Icons.place, color: Colors.green, size: 32),
          clusterGroup: clusterGroup,
          onTap: onTap == null ? null : () => onTap(m.$1),
        ),
      ).toList();
}
