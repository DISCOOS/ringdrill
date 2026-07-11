import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';

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
/// (`station_list_view.dart`) — `program_view.dart`'s and
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
    final service = ProgramService();
    final roles = service
        .loadRolePlays()
        .where(
          (r) =>
              r.exerciseUuid == exercise.uuid && r.stationIndex == stationIndex,
        )
        .toList();
    if (roles.isEmpty) return const SizedBox.shrink();
    final actors = {for (final a in service.loadActors()) a.uuid: a};

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
            Text(
              localizations.stationRolesSection,
              style: theme.textTheme.titleSmall,
            ),
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
            actor: actors[r.actorUuid],
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
  final Actor? actor;
  final void Function(RolePlay role)? onTapMarker;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final titleText = role.age != null
        ? '${role.name}, ${role.age}'
        : role.name;
    final subtitleText = actor != null
        ? localizations.castedByLine(actor!.realName)
        : localizations.noCastLine;
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: actor != null
          ? colorScheme.onSurfaceVariant
          : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
      fontStyle: actor != null ? FontStyle.normal : FontStyle.italic,
    );

    return InkWell(
      onTap: () => ContextSheet.of(
        context,
      ).show(context, RoleSheetTarget(rolePlayUuid: role.uuid)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // The marker (face) icon — the same `Icons.face` the cast picker
            // uses for a marker, so a marker row reads consistently; distinct
            // from the section header's masks-theater icon above, which names
            // the "markers" group.
            Icon(Icons.face, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(titleText, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    subtitleText,
                    style: subtitleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Cast-state indicator, matching the Spill tile's cast chip
            // icon/meaning exactly. A bare Icon (no IconButton) when
            // onTapMarker is null (program_view.dart/coordinator_screen.dart
            // stay read-only); the Poster tile's marker-row wraps it as the
            // one consistent "open the marker sheet" affordance shared with
            // Spill (DESIGN-010 browser tile polish, Fix 4).
            if (onTapMarker == null)
              Icon(
                actor != null ? Icons.person : Icons.person_add_outlined,
                color: actor != null
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              )
            else
              IconButton(
                tooltip: actor != null
                    ? localizations.editCast
                    : localizations.addCast,
                icon: Icon(
                  actor != null ? Icons.person : Icons.person_add_outlined,
                  color: actor != null
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                onPressed: () => onTapMarker!(role),
              ),
          ],
        ),
      ),
    );
  }
}
