import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/map_camera_link.dart';

/// One entry in a [MapLegend]: a colored dot and the label it stands for.
class MapLegendEntry {
  const MapLegendEntry({
    required this.color,
    required this.label,
    this.points = const [],
  });

  final Color color;
  final String label;

  /// The marker position(s) this entry stands for, so tapping it can move the
  /// map onto them (see [MapLegend]). A list, not a single point, because an
  /// entry is per marker *kind* on some surfaces — the Post viewer's legend has
  /// one entry per distinct `LocationKind`, which several of a station's
  /// locations can share — and the honest answer for those is to frame all of
  /// them rather than to pick one arbitrarily.
  ///
  /// Empty leaves the entry inert, for a legend whose entries do not correspond
  /// to a position at all.
  final List<LatLng> points;
}

/// The wrapping row of colored-dot + label chips shown under a
/// `PositionCardShell`'s map (its `legend` slot) — the domain-agnostic
/// legend both DESIGN-010 viewers share. The Post viewer builds its
/// [entries] from the station's own position plus each distinct
/// `LocationKind` (`StationScenarioLegend`); the Spill viewer builds them
/// from the marker's own position plus the parent post and portrayed
/// person's location — so both read identically instead of each hand-rolling
/// the same `Wrap`.
///
/// An entry that carries [MapLegendEntry.points] doubles as a way to get to the
/// marker it names: tapping it moves the map onto that position, via the
/// [MapCameraScope] the surrounding shell provides. On a map showing several
/// pins at an overview zoom, the legend is the only place the pins are named, so
/// it is where a reader already looks to ask "which one is the LKP?" — which
/// makes it the natural place to answer "and where is it?". Entries with no
/// points, and any legend rendered outside a scope, keep the plain static
/// strip.
class MapLegend extends StatelessWidget {
  const MapLegend({super.key, required this.entries});

  final List<MapLegendEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final link = MapCameraScope.maybeOf(context);
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final entry in entries)
          _LegendChip(
            entry: entry,
            style: theme.textTheme.bodySmall,
            // Resolved at build time, but only *called* on a tap — by which
            // point the map's own element has long since mounted and attached
            // itself. Checking `isAttached` here instead would race that: the
            // legend and the map are built in the same frame, siblings, and the
            // legend goes first.
            onTap: link == null || entry.points.isEmpty
                ? null
                : () => link.focusOn(entry.points),
            tooltip: l10n?.mapLegendFocus(entry.label),
          ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.entry,
    required this.style,
    required this.onTap,
    required this.tooltip,
  });

  final MapLegendEntry entry;
  final TextStyle? style;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: entry.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(entry.label, style: style),
      ],
    );
    if (onTap == null) return content;
    // Padded out from the text's own bounds so the strip is a comfortable tap
    // target on a phone, and so the ink ripple reads as belonging to the whole
    // chip rather than clipping to the text baseline.
    final tappable = Material(
      type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: content,
        ),
      ),
    );
    return tooltip == null
        ? tappable
        : Tooltip(message: tooltip!, child: tappable);
  }
}
