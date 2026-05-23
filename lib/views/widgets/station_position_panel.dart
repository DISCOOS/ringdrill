import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/position_widget.dart';
import 'package:ringdrill/views/widgets/station_mini_map.dart';

/// Reusable "position panel" for a single station detail surface.
///
/// Renders two stacked pieces:
///
/// 1. A label row: "Posisjon" (or its localized equivalent) anchored to
///    the left of the row, and the pin icon + UTM coordinates anchored
///    to the right. The pin sits immediately next to the coordinates so
///    they read as a single unit, instead of the previous layout where
///    an [Expanded] around [PositionWidget] introduced a wide gap
///    between the pin on the far left and the right-aligned coordinates
///    on the far right.
/// 2. A static [StationMiniMap] preview below the label row. Tapping the
///    preview opens the interactive bottom-sheet variant (provided by
///    [StationMiniMap]) so the coordinator can pan/zoom or switch base
///    layers without leaving the expansion tile.
///
/// When the station has no [Station.position] the mini-map is omitted
/// and the row shows the "no location" fallback text instead of the
/// coordinates.
class StationPositionPanel extends StatelessWidget {
  const StationPositionPanel({
    super.key,
    required this.exercise,
    required this.station,
    this.mapHeight = 200,
    this.miniMapKey,
    this.padding = EdgeInsets.zero,
  });

  final Exercise exercise;
  final Station station;
  final double mapHeight;

  /// Optional key forwarded to the embedded [StationMiniMap]. Useful
  /// when several stations are rendered together (e.g. inside a list
  /// of [ExpansionTile]s) so each preview has its own [MapView]
  /// instance and they do not share camera state.
  final Key? miniMapKey;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hasPosition = station.position != null;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // "Posisjon" / "Position" label sits on the far left so
              // the row reads as a property/value pair instead of an
              // orphan icon. Uses the muted onSurfaceVariant colour so
              // it does not compete visually with the coordinates.
              Text(
                localizations.position,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Icon(
                hasPosition ? Icons.place : Icons.place_outlined,
                color: hasPosition
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                size: 20,
              ),
              const SizedBox(width: 4),
              // Flexible — not Expanded — so the coordinates keep their
              // intrinsic width when there is room, but still wrap or
              // shrink gracefully on a narrow screen (e.g. landscape
              // phone) instead of overflowing the row.
              Flexible(
                child: hasPosition
                    ? PositionWidget(
                        wrapped: false,
                        format: PositionFormat.utm,
                        position: station.position,
                        style: theme.textTheme.bodyMedium,
                      )
                    : Text(
                        localizations.noLocation,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.right,
                      ),
              ),
            ],
          ),
          if (hasPosition) ...[
            const SizedBox(height: 12),
            StationMiniMap(
              key: miniMapKey,
              exercise: exercise,
              station: station,
              height: mapHeight,
            ),
          ],
        ],
      ),
    );
  }
}
