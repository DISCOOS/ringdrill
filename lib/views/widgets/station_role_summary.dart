import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/staff.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/drill_player/drill_player_scope.dart';
import 'package:ringdrill/views/widgets/cast_pill.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/gender_segmented_control.dart';

/// Read-only summary of roles (markørordrer) attached to a station.
///
/// Renders a "Roles (n)" header followed by one compact two-line row per
/// matching role. Returns [SizedBox.shrink] when no roles match, so callers
/// can drop this into any vertical layout without a local empty-check.
///
/// The row body's tap always opens the role sheet. [onTapMarker], when
/// supplied, gives the row's own cast-state icon a second, independent
/// affordance: opening the shared marker bottom sheet
/// (`showCastPickerSheet`/`openCastPickerAndApply`, DESIGN-010 browser tile
/// polish) to add/remove/change/edit that role's cast — the same
/// affordance the Spill tile's cast chip already offers, unified here so
/// the Poster tile's marker icon no longer opens the Spill viewer instead.
/// Left null (the default) for every call site but the Poster tile
/// (`station_list_view.dart`) — `plan_view.dart`'s and
/// `coordinator_screen.dart`'s station detail stay exactly as read-only as
/// before, with no cast affordance and no overflow menu.
class StationRoleSummary extends StatelessWidget {
  const StationRoleSummary({
    super.key,
    required this.exercise,
    required this.stationIndex,
    this.onTapMarker,
  });

  final Exercise exercise;
  final int stationIndex;

  /// Opens the marker bottom sheet for the tapped row's [RolePlay]. Null
  /// (default) keeps the row's cast-state icon a plain, non-interactive
  /// indicator.
  final void Function(RolePlay role)? onTapMarker;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final service = PlanService();
    final roles = service
        .loadRolePlays()
        .where(
          (r) =>
              r.exerciseUuid == exercise.uuid && r.stationIndex == stationIndex,
        )
        .toList();
    if (roles.isEmpty) return const SizedBox.shrink();
    final actors = {for (final a in service.loadStaff()) a.uuid: a};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.theater_comedy,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(localizations.playSection, style: theme.textTheme.titleSmall),
            const SizedBox(width: 6),
            Text(
              '(${roles.length})',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...roles.map(
          (r) => _RoleSummaryRow(
            role: r,
            actor: actors[r.staffUuid],
            onTapMarker: onTapMarker,
          ),
        ),
      ],
    );
  }
}

class _RoleSummaryRow extends StatelessWidget {
  const _RoleSummaryRow({
    required this.role,
    required this.actor,
    this.onTapMarker,
  });

  final RolePlay role;
  final Staff? actor;
  final void Function(RolePlay role)? onTapMarker;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Title: effective name · age · gender (role.* already carries the
    // effective identity). Subtitle: description — the person info, now that
    // cast status has moved into the trailing pill.
    final genderLabel = genderLabelFor(role.gender, localizations);
    final metaParts = [
      role.name,
      if (role.age != null) '${role.age}',
      ?genderLabel,
    ];
    final description = role.description ?? '';

    return InkWell(
      onTap: () => unawaited(
        openContextTarget(context, RoleSheetTarget(rolePlayUuid: role.uuid)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // The row is the person (the character) → person icon; the actor
            // who enacts them shows in the trailing cast pill (face).
            Icon(Icons.person, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    metaParts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Cast state as the shared pill — tappable (opens the cast picker)
            // only where the caller wires [onTapMarker]; a bare, non-interactive
            // indicator on the read-only surfaces (plan/coordinator detail).
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: CastPill(
                variant: actor != null
                    ? CastPillVariant.cast
                    : CastPillVariant.uncast,
                label: actor != null
                    ? actor!.realName
                    : localizations.noCastLine,
                onTap: onTapMarker == null ? null : () => onTapMarker!(role),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
