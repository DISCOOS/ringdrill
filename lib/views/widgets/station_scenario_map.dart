import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/widgets/location_kind_labels.dart';
import 'package:ringdrill/views/widgets/location_kind_style.dart';

/// DESIGN-010's Post viewer map card: the station's own administrative
/// position (id `0`, accent-colored flag, matching `StationMiniMap`'s
/// distinct-from-locations convention) plus every scenario [Location] that
/// carries a coordinate (id `index + 1`), styled by [LocationKind]
/// (ADR-0020/DESIGN-009) — richer than `station_mini_map.dart`'s own
/// `stationMarkers` (plain green pin, generic kind icon), which stays as
/// the administrative-only default for every other map surface.
List<MapMarkerSpec<int>> stationScenarioMarkers(
  BuildContext context,
  Station station,
) {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);
  final markers = <MapMarkerSpec<int>>[];
  final position = station.position;
  if (position != null) {
    markers.add(
      MapMarkerSpec(
        id: 0,
        label: l10n.station(1),
        point: position,
        child: Icon(Icons.flag, color: theme.colorScheme.primary, size: 30),
      ),
    );
  }
  for (var i = 0; i < station.locations.length; i++) {
    final location = station.locations[i];
    final point = location.position;
    if (point == null) continue;
    markers.add(
      MapMarkerSpec(
        id: i + 1,
        label: location.label.isEmpty ? location.slug : location.label,
        point: point,
        child: Icon(location.kind.icon, color: location.kind.color, size: 28),
      ),
    );
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
  const StationScenarioLegend({super.key, required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final entries = <(Color, String)>[
      if (station.position != null)
        (theme.colorScheme.primary, l10n.station(1)),
    ];
    final seenKinds = <LocationKind>{};
    for (final location in station.locations) {
      if (location.position == null) continue;
      if (!seenKinds.add(location.kind)) continue;
      entries.add((location.kind.color, location.kind.label(l10n)));
    }
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final (color, label) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
      ],
    );
  }
}
