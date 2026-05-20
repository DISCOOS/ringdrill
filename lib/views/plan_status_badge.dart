import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/catalog_status_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/library_view.dart';

/// Compact status indicator for the AppBar showing whether the active plan
/// is local-only or linked to the online catalog.
///
/// For catalog plans it surfaces the last observed catalog service state
/// (online, checking, offline, blocked) via [CatalogStatusService]. The
/// service is only updated when the library dialog actually talks to the
/// catalog, so this badge reflects the most recent known state rather than
/// doing live polling.
class PlanStatusBadge extends StatelessWidget {
  const PlanStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final program = ProgramService().activeProgram;
    if (program == null) return const SizedBox.shrink();

    final isCatalog = program.source.toJson()['runtimeType'] == 'catalog';
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final foreground =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;

    if (!isCatalog) {
      return _BadgeChip(
        icon: Icons.smartphone,
        label: localizations.planStatusLocal,
        color: foreground,
        tooltip: localizations.planStatusLocalTooltip,
      );
    }

    return ValueListenableBuilder<CatalogStatus>(
      valueListenable: CatalogStatusService().listenable,
      builder: (context, status, _) {
        final visual = catalogStatusVisual(status.state, localizations);
        // Use a brighter error tone so it pops on the dark AppBar background.
        final color = visual.isError
            ? theme.colorScheme.errorContainer
            : foreground;
        final tooltip =
            status.tooltip ??
            (visual.isError
                ? visual.label
                : localizations.planStatusOnlineTooltip);
        return _BadgeChip(
          icon: visual.icon,
          label: visual.label,
          color: color,
          tooltip: tooltip,
        );
      },
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.tooltip,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
