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

  CameraFit? fit() {
    return length < 2
        ? null
        : CameraFit.coordinates(
            padding: EdgeInsets.all(72),
            coordinates: toList(),
          );
  }
}

extension StationLocationX on Iterable<StationLocation> {
  LatLng average([LatLng? initialCenter]) {
    return map((e) => e.$3).average(initialCenter);
  }

  CameraFit? fit() {
    return map((e) => e.$3).fit();
  }
}
