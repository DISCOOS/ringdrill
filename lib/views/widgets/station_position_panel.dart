import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/position_widget.dart';
import 'package:ringdrill/views/widgets/border_shell.dart';
import 'package:ringdrill/views/widgets/position_card.dart';
import 'package:ringdrill/views/widgets/position_empty_state.dart';
import 'package:ringdrill/views/widgets/station_mini_map.dart';

/// How a panel renders a missing position.
///
/// Shared by [StationPositionPanel] and `RolePositionPanel`, which face the same
/// choice on the same surfaces.
enum PositionEmptyStyle {
  /// The one-line `Posisjon … Ikke satt` row. For a dense inline slot with no real
  /// map height of its own.
  row,

  /// The full card, with a teaching empty state where the map would be.
  card,
}

/// Reusable "position panel" for a single station detail surface
/// (docs/prompts/position-panel-read-alignment.md).
///
/// Renders [PositionCardShell]: a bordered card with [StationMiniMap] on
/// top and a coordinate bar below (the "Position" label, the UTM
/// coordinate). [StationMiniMap] is a static tap-to-expand preview by
/// default; pass [interactive] to render it directly interactive instead
/// (the caller decides — the expanded pane and the medium map segment both
/// opt in). The bar itself only opens anything when the caller passes
/// [onTap] for that purpose — station_screen.dart wires it to open the
/// station editor, and every other call site leaves it null (bar tap is
/// then a no-op). This stays read-only either way — never the
/// [PositionCard] picker.
///
/// With no [Station.position], [emptyStyle] decides the shape: [PositionEmptyStyle.row]
/// keeps the one-line fallback (a dense inline call site inside an `ExpansionTile`
/// body), [PositionEmptyStyle.card] renders the same [PositionCardShell] as a set
/// position with a teaching empty state in the thumbnail slot. Explicit rather than
/// derived from [fillHeight], because "owns a real map height" and "flexes to fill
/// its parent" are different questions and the medium map segment answers them
/// differently.
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
    this.interactive = false,
    this.mapHeight = 200,
    this.label,
    this.onTap,
    this.withTitle = false,
    this.withBorder = false,
    this.padding = EdgeInsets.zero,
    this.emptyStyle = PositionEmptyStyle.row,
    this.emptyState,
  });

  final String? label;
  final bool withTitle;
  final bool withBorder;
  final Station station;
  final double mapHeight;
  final Exercise exercise;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

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

  /// Forwarded to [StationMiniMap.interactive]: render the map directly
  /// interactive (pan/zoom/tap, own FAB stack, fullscreen command) instead
  /// of the static tap-to-expand preview. Decoupled from [fillHeight] —
  /// the medium detail body wants an interactive map at an explicit
  /// [mapHeight] (inside a scrolling column, where `fillHeight`'s
  /// `Expanded` sizing can't apply), while the expanded pane wants both.
  final bool interactive;

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

  /// Forwarded to [PositionCardShell]. Defaults to `false` because most
  /// call sites embed this panel inside an `ExpandableTile` body — itself
  /// a `Card` — where the panel's own [Card] would nest inside it.
  /// Station/RolePlay detail screens, which show this panel on a bare
  /// page with no ambient card, pass `true`.
  final bool asCard;

  /// How a missing position renders. Defaults to the row every existing call site
  /// already showed.
  final PositionEmptyStyle emptyStyle;

  /// The teaching empty state for [PositionEmptyStyle.card], built by the caller.
  ///
  /// Prebuilt on purpose: the action is role-gated and disabled while an exercise
  /// runs, and that is the call site's knowledge (`IfEditable`, `stopExerciseFirst`).
  /// Threading permission inputs through this widget would put that logic in a
  /// shared panel used by six surfaces that do not all need it. Null falls back to
  /// the explanation with no action, which is also the viewer's variant.
  final Widget? emptyState;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final position = station.position;
    final content = position == null
        ? (emptyStyle == PositionEmptyStyle.card
              ? _buildEmptyCard(l10n, theme)
              : _buildNoPositionRow(l10n, theme))
        : _buildPositionCard(l10n, theme, position);

    final positioned = withBorder ? BorderShell(child: content) : content;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // `max` + Expanded in fillHeight mode: the ancestor (the expanded
        // right pane's stretched Row) gives this panel a tight height, and
        // this wrapper must pass all of it through to PositionCardShell's
        // own Expanded thumbnail below — a `min` Column would instead give
        // its child unbounded height to measure it, which conflicts with
        // that Expanded. `min` otherwise, so the panel wraps its content
        // height like every other call site.
        mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (withTitle) ...[
            Text(
              l10n.placement.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
          ],
          fillHeight ? Expanded(child: positioned) : positioned,
        ],
      ),
    );
  }

  Row _buildNoPositionRow(AppLocalizations l10n, ThemeData theme) {
    return Row(
      children: [
        Text(
          l10n.position,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(l10n.positionNotSet, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  /// The same shell as a set position, with the teaching state where the map goes.
  ///
  /// No `legend`: it labels markers, and there are none. Everything else —
  /// `thumbnailHeight`, `fillHeight`, `sectionId`, `asCard` — is forwarded
  /// unchanged, so the card is the same object in both states and the transition
  /// does not read as two components.
  PositionCardShell _buildEmptyCard(AppLocalizations l10n, ThemeData theme) {
    return PositionCardShell(
      onTap: onTap,
      asCard: asCard,
      thumbnail:
          emptyState ??
          PositionEmptyState(
            title: l10n.noPositionTitle,
            body: l10n.noPositionStationBody,
            height: fillHeight ? null : mapHeight,
          ),
      thumbnailHeight: mapHeight,
      fillHeight: fillHeight,
      sectionId: sectionId,
      barLabel: Text(
        label ?? l10n.position,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      barChild: Align(
        alignment: Alignment.centerRight,
        child: Text(
          l10n.positionNotSet,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  PositionCardShell _buildPositionCard(
    AppLocalizations l10n,
    ThemeData theme,
    LatLng position,
  ) {
    return PositionCardShell(
      onTap: onTap,
      asCard: asCard,
      thumbnail: StationMiniMap(
        key: miniMapKey,
        exercise: exercise,
        station: station,
        height: mapHeight,
        interactive: interactive,
        markers: markers,
        // Square bottom corners: the map sits flush above the
        // coordinate bar, and PositionCardShell's own outer
        // rounding already handles the card's top corners.
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      thumbnailHeight: mapHeight,
      fillHeight: fillHeight,
      sectionId: sectionId,
      legend: legend,
      barLabel: InkWell(
        onTap: onTap,
        child: Text(
          label ?? l10n.position,
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
    );
  }
}
