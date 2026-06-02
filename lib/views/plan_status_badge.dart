import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/services/catalog_status_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/active_plan_actions.dart' as active_actions;
import 'package:ringdrill/views/library_view.dart';

/// Compact status indicator for the AppBar showing whether the active plan
/// is local-only or linked to the online catalog.
///
/// For catalog plans it surfaces the last observed catalog service state
/// (online, checking, offline, blocked) via [CatalogStatusService]. The
/// badge auto-probes the catalog on first show (and whenever a catalog
/// plan becomes active) while the status is still [CatalogServiceState.unknown],
/// so users who never open the library dialog don't see the indicator
/// permanently stuck on "Sjekker". Tapping the badge re-runs the probe.
class PlanStatusBadge extends StatefulWidget {
  const PlanStatusBadge({super.key});

  @override
  State<PlanStatusBadge> createState() => _PlanStatusBadgeState();
}

class _PlanStatusBadgeState extends State<PlanStatusBadge> {
  StreamSubscription<ProgramEvent>? _programEventsSub;

  /// Whether the active catalog plan has local edits that have not been
  /// published yet. Recomputed only on [ProgramEvent]s (not on every build)
  /// so the program content hash is not re-run on each rebuild.
  bool _hasUnpublishedChanges = false;

  @override
  void initState() {
    super.initState();
    _refreshUnpublishedState();
    _scheduleProbeIfNeeded();
    // Re-evaluate when the active plan changes so switching to a fresh
    // catalog plan kicks off an initial probe. Also rebuild — the badge's
    // build method reads program.source to choose between the local and
    // online variants, so a publish that flips source from local to catalog
    // must propagate through build, not just trigger a probe.
    _programEventsSub = ProgramService().events.listen((_) {
      if (!mounted) return;
      _refreshUnpublishedState();
      setState(() {});
      _scheduleProbeIfNeeded();
    });
  }

  @override
  void dispose() {
    _programEventsSub?.cancel();
    super.dispose();
  }

  void _scheduleProbeIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final program = ProgramService().activeProgram;
      if (program == null || !active_actions.isCatalogProgram(program)) {
        return;
      }
      if (CatalogStatusService().value.state != CatalogServiceState.unknown) {
        return;
      }
      active_actions.probeCatalogService(context);
    });
  }

  Future<void> _onTap() async {
    // Debounce while a probe is already in flight, otherwise re-run it.
    if (CatalogStatusService().value.state == CatalogServiceState.checking) {
      return;
    }
    await active_actions.probeCatalogService(context);
  }

  /// Recompute whether the active catalog plan diverges from its published
  /// snapshot. Edits are saved to SharedPreferences immediately, but they are
  /// not pushed to the catalog until the user publishes, so a divergent
  /// content hash means "unpublished", never "unsaved".
  void _refreshUnpublishedState() {
    final program = ProgramService().activeProgram;
    _hasUnpublishedChanges =
        program != null &&
        active_actions.isCatalogProgram(program) &&
        program.contentHash != null &&
        program.computeContentHash() != program.contentHash;
  }

  Future<void> _onPublishTap() async {
    // Reuse the shared publish flow. For an already-published catalog plan
    // this is a one-tap silent update, with 412-conflict handling and a
    // result snackbar. A successful publish emits a ProgramEvent that
    // flips this badge back to the plain online state.
    await active_actions.publishActivePlan(context);
  }

  @override
  Widget build(BuildContext context) {
    final program = ProgramService().activeProgram;
    if (program == null) return const SizedBox.shrink();

    final isCatalog = active_actions.isCatalogProgram(program);
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

    if (_hasUnpublishedChanges) {
      return _BadgeChip(
        icon: Icons.cloud_upload_outlined,
        label: localizations.planStatusUnpublished,
        color: foreground,
        tooltip: localizations.planStatusUnpublishedTooltip,
        onTap: _onPublishTap,
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
          onTap: _onTap,
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
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 18, color: color),
        ],
      ),
    );
    final wrapped = onTap == null
        ? content
        // Wrap in a transparent Material with a matching borderRadius so the
        // InkWell splash and highlight clip to the badge bounds instead of
        // bleeding onto the AppBar surface behind it.
        : Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(4),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(4),
              child: content,
            ),
          );
    return Tooltip(message: tooltip, child: wrapped);
  }
}
