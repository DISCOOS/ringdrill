import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/position_widget.dart';
import 'package:ringdrill/views/widgets/border_shell.dart';
import 'package:ringdrill/views/widgets/position_card.dart';
import 'package:ringdrill/views/widgets/role_mini_map.dart';

/// Reusable position panel for a single role's detail surface
/// (docs/prompts/position-panel-read-alignment.md). Mirrors
/// [StationPositionPanel]: takes the domain objects directly (exercise,
/// roleplay, and the station it's placed at) rather than pre-computed
/// label/subtitle strings — [RoleMiniMap] derives the marker label, the map
/// sheet header's numbering and its exercise subtitle from those objects.
///
/// Renders [PositionCardShell]: [RoleMiniMap] on top, a coordinate bar
/// below (label, UTM coordinate). [RoleMiniMap] is a static tap-to-expand
/// preview by default; this panel forwards its own [fillHeight] straight
/// through as [RoleMiniMap.interactive], since `fillHeight: true` is only
/// ever passed once the caller (roleplay_screen.dart's expanded body) has
/// already decided this panel sits in a spacious enough pane — the exact
/// moment to make the map directly interactive instead. The bar itself
/// has no `onTap` to forward, so tapping it is a no-op — read-only either
/// way, never the [PositionCard] picker.
class RolePositionPanel extends StatelessWidget {
  const RolePositionPanel({
    super.key,
    required this.exercise,
    required this.rolePlay,
    this.station,
    this.label,
    this.legend,
    this.sectionId,
    this.mapHeight = 200,
    this.asCard = false,
    this.fillHeight = false,
    this.extraMarkers = const [],
    this.overrides = const {},
    this.onTap,
    this.withTitle = false,
    this.withBorder = false,
    this.padding = EdgeInsets.zero,
  });

  final Exercise exercise;
  final RolePlay rolePlay;

  /// The station [rolePlay] is placed at, if any — forwarded to
  /// [RoleMiniMap] to resolve the person-location fallback position and to
  /// number the role in the map sheet's header.
  final Station? station;

  final bool withTitle;
  final bool withBorder;
  final double mapHeight;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Field-name text for the coordinate bar (e.g. "Plassering") — names
  /// *what this row is*, not who/where it's about. Defaults to
  /// `l10n.position` ("Posisjon"), matching [StationPositionPanel].
  final String? label;

  /// Additional read-only markers shown on the map beside the role's own
  /// central marker (Del B: the parent post's position and the portrayed
  /// person's location, only when they sit at a distinct spot). The
  /// coordinate bar still reads only the role's own central position.
  final List<MapMarkerSpec<int>> extraMarkers;

  /// Effective plan-variable overrides (ADR-0046) at this role's scope —
  /// forwarded to [RoleMiniMap] for the marker's and the map sheet header's
  /// substitution.
  final Map<String, String> overrides;

  /// Forwarded to [PositionCardShell.legend]: the wrapping dot + label strip
  /// under the map (a [MapLegend]) naming the markers present — the Spill
  /// viewer builds one from the marker/post/person-location entries, the same
  /// way the Post viewer's map card does. Null (every other call site) keeps
  /// the map with no legend strip.
  final Widget? legend;

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
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final position = roleCentralPosition(rolePlay, station);

    final content = position == null
        ? _buildNoPositionRow(l10n, theme)
        : _buildPositionCard(l10n, theme, position);

    final positioned = withBorder ? BorderShell(child: content) : content;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // `max` + Expanded in fillHeight mode: the ancestor (the expanded
        // right pane's stretched Row) gives this panel a tight height, and
        // this wrapper must pass all of it through to PositionCardShell's
        // own Expanded thumbnail below — a non-flex child always gets
        // unbounded main-axis constraints for its own measurement pass
        // regardless of mainAxisSize, which conflicts with that Expanded
        // unless it is itself a flex (Expanded) child here too. `min`
        // otherwise, so the panel wraps its content height like every
        // other call site.
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

  Row _buildNoPositionRow(AppLocalizations localizations, ThemeData theme) {
    return Row(
      children: [
        Text(
          localizations.position,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(localizations.noLocation, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  PositionCardShell _buildPositionCard(
    AppLocalizations l10n,
    ThemeData theme,
    LatLng position,
  ) {
    return PositionCardShell(
      asCard: asCard,
      thumbnail: RoleMiniMap(
        exercise: exercise,
        rolePlay: rolePlay,
        station: station,
        height: mapHeight,
        // fillHeight is only ever true once the caller (roleplay_screen.dart's
        // _buildExpandedBody, building a WideDetailMapSplit) has already
        // decided this panel sits in a spacious expanded pane — the exact
        // moment to make the map directly interactive instead of a static
        // tap-to-expand preview.
        interactive: fillHeight,
        extraMarkers: extraMarkers,
        overrides: overrides,
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
