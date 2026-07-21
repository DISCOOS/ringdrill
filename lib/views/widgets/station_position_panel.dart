import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/position_widget.dart';
import 'package:ringdrill/views/widgets/position_card.dart';
import 'package:ringdrill/views/widgets/station_mini_map.dart';

/// Reusable "position panel" for a single station detail surface
/// (docs/prompts/position-panel-read-alignment.md).
///
/// Renders [PositionCardShell]: a bordered card with the static
/// [StationMiniMap] preview on top and a coordinate bar below (the
/// "Position" label, the UTM coordinate). [StationMiniMap]'s own tap
/// affordance always opens the interactive `openStationMapSheet`; the bar
/// itself only does so when the caller passes [onTap] for that purpose —
/// station_screen.dart instead wires it to open the station editor, and
/// every other call site leaves it null (bar tap is then a no-op; the
/// thumbnail remains the one affordance). This stays read-only either
/// way — never the [PositionCard] picker.
///
/// When the station has no [Station.position] the card is omitted
/// entirely and the row shows the "no location" fallback text instead.
class StationPositionPanel extends StatelessWidget {
  const StationPositionPanel({
    super.key,
    required this.exercise,
    required this.station,
    this.miniMapKey,
    this.markers,
    this.legend,
    this.sectionId,
    this.asCard = false,
    this.fillHeight = false,
    this.mapHeight = 200,
    this.padding = EdgeInsets.zero,
    this.onTap,
  });

  final Station station;
  final Exercise exercise;

  final double mapHeight;

  /// Forwarded to [PositionCardShell.sectionId]. Null (every call site but
  /// the Post viewer) keeps this panel exactly as it always was: no
  /// collapse chevron, always expanded.
  final String? sectionId;

  /// Forwarded to [PositionCardShell.fillHeight]: the map flexes to fill
  /// all remaining height an ancestor gives this panel instead of the
  /// fixed [mapHeight] — the Post viewer's expanded right pane
  /// (`WideDetailMapSplit`) passes `true`; every other call site keeps the
  /// default fixed-height inline card.
  final bool fillHeight;

  /// Overrides the embedded [StationMiniMap]'s default administrative-only
  /// marker with a richer scenario set (DESIGN-010's Post viewer). Null
  /// keeps every other call site's existing single-marker behaviour.
  final List<MapMarkerSpec<int>>? markers;

  /// A legend strip under the map, above the coordinate bar — forwarded to
  /// [PositionCardShell]'s own `legend` slot. Null omits it (every call
  /// site but the Post viewer).
  final Widget? legend;

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

  final VoidCallback? onTap;

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
              onTap: onTap,
              asCard: asCard,
              thumbnail: StationMiniMap(
                key: miniMapKey,
                exercise: exercise,
                station: station,
                height: mapHeight,
                markers: markers,
                // Square bottom corners: the map sits flush above the
                // coordinate bar, and PositionCardShell's own outer
                // rounding already handles the card's top corners.
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              thumbnailHeight: mapHeight,
              fillHeight: fillHeight,
              sectionId: sectionId,
              legend: legend,
              barLabel: InkWell(
                onTap: onTap,
                child: Text(
                  localizations.position,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              barChild: Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: onTap,
                  child: PositionWidget(
                    format: PositionFormat.utm,
                    position: position,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
    );
  }
}
