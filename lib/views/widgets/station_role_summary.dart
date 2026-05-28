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
/// This widget is intentionally **non-interactive** except for the row-body
/// tap that opens the role sheet. There is no cast affordance, no
/// swipe-to-edit, and no overflow menu. Authoring stays on the dedicated
/// Station screen and the Markører tab.
class StationRoleSummary extends StatelessWidget {
  const StationRoleSummary({
    super.key,
    required this.exercise,
    required this.stationIndex,
  });

  final Exercise exercise;
  final int stationIndex;

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
          (r) => _RoleSummaryRow(role: r, actor: actors[r.actorUuid]),
        ),
      ],
    );
  }
}

class _RoleSummaryRow extends StatelessWidget {
  const _RoleSummaryRow({required this.role, required this.actor});

  final RolePlay role;
  final Actor? actor;

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
            Icon(
              Icons.theater_comedy,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
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
            // Non-interactive cast-state indicator — no IconButton wrapper.
            Icon(
              actor != null ? Icons.person : Icons.person_add_outlined,
              color: actor != null
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
