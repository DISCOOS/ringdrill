import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';
import 'package:ringdrill/views/widgets/role_marker.dart';

/// Compact static preview of a role's position. Tapping opens a bottom sheet
/// with an interactive full-screen map. Mirrors [StationMiniMap] but accepts
/// a [LatLng] directly rather than a Station/Exercise pair so it stays
/// domain-agnostic per the project's MapView rule.
///
/// Used in both [RolePlayScreen] (detail view) and the [RolePlaysView]
/// expandable tile body.
class RoleMiniMap extends StatelessWidget {
  const RoleMiniMap({
    super.key,
    required this.position,
    required this.label,
    this.height = 200,
  });

  final LatLng position;
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openMapSheet(context),
        child: IgnorePointer(
          child: MapView(
            layers: MapConfig.layers,
            withToggle: false,
            initialZoom: 15,
            initialCenter: position,
            markers: [
              MapMarkerSpec(
                id: 0,
                label: label,
                point: position,
                child: const RoleMarker(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMapSheet(BuildContext context) {
    return showRingdrillActionSheet<void>(
      context: context,
      builder: (context) => FractionallySizedBox(
        heightFactor: 1.0,
        child: MapView(
          layers: MapConfig.layers,
          withZoom: true,
          withCenter: true,
          withToggle: true,
          initialZoom: 16,
          initialCenter: position,
          interactionFlags: MapConfig.interactive,
          markers: [
            MapMarkerSpec(
              id: 0,
              label: label,
              point: position,
              child: const RoleMarker(),
            ),
          ],
        ),
      ),
    );
  }
}
