import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/position_widget.dart';
import 'package:ringdrill/views/widgets/position_card.dart';
import 'package:ringdrill/views/widgets/station_mini_map.dart';

/// Reusable "position panel" for a single station detail surface
/// (docs/prompts/position-panel-read-alignment.md).
///
/// Renders [PositionCardShell]: a bordered card with the static
/// [StationMiniMap] preview on top and a coordinate bar below (the
/// "Posisjon" label, the UTM coordinate, a trailing chevron). Reuses
/// [StationMiniMap]'s own "tap opens the interactive bottom sheet"
/// affordance for the thumbnail; the shell's own [InkWell] covers the
/// same tap for the coordinate bar so the whole card is one affordance.
/// This stays read-only — the tap opens `openStationMapSheet`, never the
/// [PositionCard] picker.
///
/// When the station has no [Station.position] the card is omitted
/// entirely and the row shows the "no location" fallback text instead.
class StationPositionPanel extends StatelessWidget {
  const StationPositionPanel({
    super.key,
    required this.exercise,
    required this.station,
    this.mapHeight = 200,
    this.miniMapKey,
    this.padding = EdgeInsets.zero,
    this.asCard = false,
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

  /// Forwarded to [PositionCardShell]. Defaults to `false` because most
  /// call sites embed this panel inside an `ExpandableTile` body — itself
  /// a `Card` — where the panel's own [Card] would nest inside it.
  /// Station/RolePlay detail screens, which show this panel on a bare
  /// page with no ambient card, pass `true`.
  final bool asCard;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final position = station.position;

    return Padding(
      padding: padding,
      child: position == null
          ? Row(
              children: [
                Text(
                  localizations.position,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  localizations.noLocation,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            )
          : PositionCardShell(
              onTap: () => openStationMapSheet(context, exercise, station),
              asCard: asCard,
              thumbnail: StationMiniMap(
                key: miniMapKey,
                exercise: exercise,
                station: station,
                height: mapHeight,
              ),
              thumbnailHeight: mapHeight,
              barLabel: Text(
                localizations.position,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              barChild: Align(
                alignment: Alignment.centerRight,
                child: PositionWidget(
                  wrapped: false,
                  format: PositionFormat.utm,
                  position: position,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
    );
  }
}
