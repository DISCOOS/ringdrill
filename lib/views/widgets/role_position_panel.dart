import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/position_widget.dart';
import 'package:ringdrill/views/widgets/role_mini_map.dart';

/// Reusable position panel for a single role's detail surface.
///
/// Mirrors [StationPositionPanel] but accepts a [LatLng] directly rather
/// than a Station/Exercise pair, keeping it domain-agnostic.
///
/// Renders:
/// 1. A label row: "Position" on the left, pin icon + UTM coordinates on the
///    right (matching the station panel's layout).
/// 2. A [RoleMiniMap] preview below. Tapping opens the interactive bottom
///    sheet.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              localizations.position,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.place,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: PositionWidget(
                wrapped: false,
                format: PositionFormat.utm,
                position: position,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RoleMiniMap(
          position: position,
          label: label,
          height: mapHeight,
        ),
      ],
    );
  }
}
