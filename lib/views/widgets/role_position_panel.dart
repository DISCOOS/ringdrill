import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/position_widget.dart';
import 'package:ringdrill/views/widgets/position_card.dart';
import 'package:ringdrill/views/widgets/role_mini_map.dart';

/// Reusable position panel for a single role's detail surface
/// (docs/prompts/position-panel-read-alignment.md). Mirrors
/// [StationPositionPanel] but accepts a [LatLng] directly rather than a
/// Station/Exercise pair, keeping it domain-agnostic.
///
/// Renders [PositionCardShell]: the static [RoleMiniMap] preview on top,
/// a coordinate bar below (label, UTM coordinate). [RoleMiniMap]'s own tap
/// affordance opens the interactive bottom sheet; the bar itself has no
/// `onTap` to forward, so tapping it is a no-op — read-only either way,
/// never the [PositionCard] picker.
class RolePositionPanel extends StatelessWidget {
  const RolePositionPanel({
    super.key,
    required this.position,
    required this.label,
    this.mapHeight = 200,
    this.asCard = false,
    this.fillHeight = false,
    this.sectionId,
    this.extraMarkers = const [],
    this.legend,
  });

  /// Additional read-only markers shown on the map beside the role's own
  /// central marker (Del B: the parent post's position and the portrayed
  /// person's location, only when they sit at a distinct spot). The
  /// coordinate bar still reads only [position].
  final List<MapMarkerSpec<int>> extraMarkers;

  /// Forwarded to [PositionCardShell.legend]: the wrapping dot + label strip
  /// under the map (a [MapLegend]) naming the markers present — the Spill
  /// viewer builds one from the marker/post/person-location entries, the same
  /// way the Post viewer's map card does. Null (every other call site) keeps
  /// the map with no legend strip.
  final Widget? legend;

  final LatLng position;

  /// Role name — used as the map marker label and bottom-sheet title.
  final String label;

  final double mapHeight;

  /// Forwarded to [PositionCardShell]. Defaults to `false` because most
  /// call sites embed this panel inside an `ExpandableTile` body — itself
  /// a `Card` — where the panel's own [Card] would nest inside it. The
  /// RolePlay detail screen, which shows this panel on a bare page with
  /// no ambient card, passes `true`.
  final bool asCard;

  /// Forwarded to [PositionCardShell.fillHeight]: the map flexes to fill
  /// all remaining height an ancestor gives this panel instead of the
  /// fixed [mapHeight] — the Spill viewer's expanded right pane
  /// (`WideDetailMapSplit`) passes `true`; every other call site keeps the
  /// default fixed-height inline card.
  final bool fillHeight;

  /// Forwarded to [PositionCardShell.sectionId]. Null (every call site but
  /// the Spill viewer) keeps this panel exactly as it always was: no
  /// collapse chevron, always expanded.
  final String? sectionId;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PositionCardShell(
      asCard: asCard,
      thumbnail: RoleMiniMap(
        position: position,
        label: label,
        height: mapHeight,
        extraMarkers: extraMarkers,
      ),
      thumbnailHeight: mapHeight,
      fillHeight: fillHeight,
      sectionId: sectionId,
      legend: legend,
      barLabel: Text(
        localizations.position,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      barChild: Align(
        alignment: Alignment.centerRight,
        child: PositionWidget(
          format: PositionFormat.utm,
          position: position,
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}
