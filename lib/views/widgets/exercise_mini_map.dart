import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/views/map_view.dart';

/// Static, non-interactive preview of every station marker in an
/// exercise, framed to fit them all. This is the multi-marker sibling of
/// [StationMiniMap] (single station) and [RoleMiniMap] (single role):
/// embed it wherever an exercise overview map is shown so the 8px corner
/// radius, the [IgnorePointer] gesture suppression and the marker
/// framing stay consistent with every other embedded map in the app.
///
/// Renders nothing when [markers] is empty, so callers can drop it into a
/// column without guarding on the marker count themselves.
class ExerciseMiniMap extends StatelessWidget {
  const ExerciseMiniMap({
    super.key,
    required this.markers,
    this.height = 200,
    this.mapKey,
  });

  /// Station locations to plot. Typically `exercise.getLocations(false)`.
  final List<StationLocation> markers;

  /// Fixed preview height. Defaults to the 200px used by the exercise
  /// card; pass a smaller value for tighter embeddings.
  final double height;

  /// Optional key forwarded to the embedded [MapView]. Use a stable
  /// [ValueKey] when several previews share a parent so each keeps its
  /// own camera state instead of recycling a sibling's.
  final Key? mapKey;

  @override
  Widget build(BuildContext context) {
    if (markers.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: IgnorePointer(
          child: MapView<(String, int)>(
            key: mapKey,
            layers: MapConfig.layers,
            withToggle: false,
            withClustering: false,
            markers: markers.toMarkerSpecs(),
            initialFit: markers.fit(),
            initialCenter: markers.average(),
          ),
        ),
      ),
    );
  }
}
