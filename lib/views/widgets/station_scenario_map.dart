import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/widgets/location_kind_labels.dart';
import 'package:ringdrill/views/widgets/location_kind_style.dart';
import 'package:ringdrill/views/widgets/map_legend.dart';
import 'package:ringdrill/views/widgets/resolve_scoped_field.dart';
import 'package:ringdrill/views/widgets/station_mini_map.dart' show stationNumbering, locationMarker;

/// DESIGN-010's Post viewer map card: the station's own administrative
/// position (id `0`, accent-colored flag, matching `StationMiniMap`'s
/// distinct-from-locations convention) plus every scenario [Location] that
/// carries a coordinate (id `index + 1`), styled by [LocationKind]
/// (ADR-0020/DESIGN-009) — richer than `station_mini_map.dart`'s own
/// `stationMarkers` (plain green pin, generic kind icon), which stays as
/// the administrative-only default for every other map surface.
List<MapMarkerSpec<int>> stationScenarioMarkers(
  BuildContext context,
  Exercise exercise,
  Station station,
) {
  final theme = Theme.of(context);
  final markers = <MapMarkerSpec<int>>[];
  final position = station.position;
  if (position != null) {
    // Number-only at overview zooms (the app-wide station-marker
    // convention, via stationNumbering — see PlanService.getLocations),
    // switching to the full resolved "number name" once zoomed in close
    // enough to have room for it (MapConfig.labelDetailZoomFor) — like
    // every other station-position marker in the app.
    final numbering = stationNumbering(exercise, station);
    markers.add(
      MapMarkerSpec(
        id: 0,
        label: resolveScopedField(context, numbering.rawLabel) ?? numbering.rawLabel,
        shortLabel: numbering.shortLabel,
        point: position,
        child: Icon(Icons.flag, color: theme.colorScheme.primary, size: 30),
      ),
    );
  }
  for (var i = 0; i < station.locations.length; i++) {
    final location = station.locations[i];
    if (location.position == null) continue;
    markers.add(locationMarker(location, id: i + 1));
  }
  return markers;
}

/// The legend strip under the Post viewer's map card: a wrapping row of
/// colored-dot + label chips, one per distinct marker kind actually present
/// (the station's own position, always first, then each distinct
/// [LocationKind] among [station]'s positioned locations, in first-seen
/// order) — never the full [LocationKind] enum, so an empty/simple station
/// gets a short legend.
class StationScenarioLegend extends StatelessWidget {
  const StationScenarioLegend({
    super.key,
    required this.exercise,
    required this.station,
  });

  final Exercise exercise;
  final Station station;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final numbering = stationNumbering(exercise, station);
    final stationLabel =
        resolveScopedField(context, numbering.rawLabel) ?? numbering.rawLabel;
    final entries = <MapLegendEntry>[
      if (station.position != null)
        MapLegendEntry(color: theme.colorScheme.primary, label: stationLabel),
    ];
    final seenKinds = <LocationKind>{};
    for (final location in station.locations) {
      if (location.position == null) continue;
      if (!seenKinds.add(location.kind)) continue;
      entries.add(
        MapLegendEntry(
          color: location.kind.color,
          label: location.kind.label(l10n),
        ),
      );
    }
    return MapLegend(entries: entries);
  }
}
