import 'package:flutter/material.dart';

/// One entry in a [MapLegend]: a colored dot and the label it stands for.
class MapLegendEntry {
  const MapLegendEntry({required this.color, required this.label});

  final Color color;
  final String label;
}

/// The wrapping row of colored-dot + label chips shown under a
/// `PositionCardShell`'s map (its `legend` slot) — the domain-agnostic
/// legend both DESIGN-010 viewers share. The Post viewer builds its
/// [entries] from the station's own position plus each distinct
/// `LocationKind` (`StationScenarioLegend`); the Spill viewer builds them
/// from the marker's own position plus the parent post and portrayed
/// person's location — so both read identically instead of each hand-rolling
/// the same `Wrap`.
class MapLegend extends StatelessWidget {
  const MapLegend({super.key, required this.entries});

  final List<MapLegendEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final entry in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: entry.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(entry.label, style: theme.textTheme.bodySmall),
            ],
          ),
      ],
    );
  }
}
