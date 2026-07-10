import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/position_widget.dart';
import 'package:ringdrill/views/widgets/position_card.dart';
import 'package:ringdrill/views/widgets/role_mini_map.dart';

/// Reusable position panel for a single role's detail surface
/// (docs/prompts/position-panel-read-alignment.md). Mirrors
/// [StationPositionPanel] but accepts a [LatLng] directly rather than a
/// Station/Exercise pair, keeping it domain-agnostic.
///
/// Renders [PositionCardShell]: the static [RoleMiniMap] preview on top,
/// a coordinate bar below (label, UTM coordinate, trailing chevron). Tap
/// (thumbnail or bar) opens the same interactive bottom sheet as
/// [RoleMiniMap] on its own — read-only, never the [PositionCard] picker.
class RolePositionPanel extends StatelessWidget {
  const RolePositionPanel({
    super.key,
    required this.position,
    required this.label,
    this.mapHeight = 200,
    this.asCard = false,
    this.sourceLabel,
  });

  final LatLng position;

  /// Role name — used as the map marker label and bottom-sheet title.
  final String label;

  final double mapHeight;

  /// The scenario `Location` this position was taken from (DESIGN-010's
  /// Spill viewer: "the marker's position follows the portrayed person's
  /// location") — shown as a small second line under the "Posisjon" bar
  /// label. Null (every other call site) keeps the single-line label.
  final String? sourceLabel;

  /// Forwarded to [PositionCardShell]. Defaults to `false` because most
  /// call sites embed this panel inside an `ExpandableTile` body — itself
  /// a `Card` — where the panel's own [Card] would nest inside it. The
  /// RolePlay detail screen, which shows this panel on a bare page with
  /// no ambient card, passes `true`.
  final bool asCard;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PositionCardShell(
      onTap: () => openRoleMapSheet(context, position, label),
      asCard: asCard,
      thumbnail: RoleMiniMap(
        position: position,
        label: label,
        height: mapHeight,
      ),
      thumbnailHeight: mapHeight,
      barLabel: sourceLabel == null
          ? Text(
              localizations.position,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  localizations.position,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(sourceLabel!, style: theme.textTheme.bodySmall),
              ],
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
    );
  }
}
