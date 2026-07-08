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
  });

  final LatLng position;

  /// Role name — used as the map marker label and bottom-sheet title.
  final String label;

  final double mapHeight;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PositionCardShell(
      onTap: () => openRoleMapSheet(context, position, label),
      thumbnail: RoleMiniMap(
        position: position,
        label: label,
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
    );
  }
}
