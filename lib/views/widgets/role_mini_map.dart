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
    this.extraMarkers = const [],
  });

  final LatLng position;
  final String label;
  final double height;

  /// Additional read-only markers (the parent post's position, the portrayed
  /// person's location) shown alongside this role's own central marker — the
  /// caller only includes ones that sit at a distinct spot. Empty for the
  /// RolePlaysView tile.
  final List<MapMarkerSpec<int>> extraMarkers;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            openRoleMapSheet(context, position, label, extraMarkers: extraMarkers),
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
              ...extraMarkers,
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the interactive single-role map in a modal bottom sheet. Exposed
/// as a top-level function (mirrors `openStationMapSheet` in
/// `station_mini_map.dart`) so callers that don't embed [RoleMiniMap]
/// itself — e.g. `RolePositionPanel`'s coordinate bar — can trigger the
/// same interaction.
Future<void> openRoleMapSheet(
  BuildContext context,
  LatLng position,
  String label, {
  List<MapMarkerSpec<int>> extraMarkers = const [],
}) {
  return showRingdrillActionSheet<void>(
    context: context,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
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
          ...extraMarkers,
        ],
      ),
    ),
  );
}
