import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/position_widget.dart';
import 'package:ringdrill/views/widgets/border_shell.dart';
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
    this.label,
    this.legend,
    this.position,
    this.sectionId,
    this.mapHeight = 200,
    this.asCard = false,
    this.fillHeight = false,
    this.extraMarkers = const [],
    this.onTap,
    this.withTitle = false,
    this.withBorder = false,
    this.padding = EdgeInsets.zero,
  });

  final bool withTitle;
  final bool withBorder;
  final LatLng? position;
  final double mapHeight;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Role name — used as the map marker label and bottom-sheet title.
  final String? label;

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

    final content = position == null
        ? _buildNoPositionRow(l10n, theme)
        : _buildPositionCard(l10n, theme, position!);

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
        position: position,
        label: label ?? l10n.position,
        height: mapHeight,
        extraMarkers: extraMarkers,
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
