import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/services/catalog_status_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/active_plan_actions.dart' as active_actions;
import 'package:ringdrill/views/widgets/catalog_browser.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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
  const PlanStatusBadge({super.key, this.publishOverride});

  /// Replaces the publish call, for tests.
  ///
  /// The state this widget exists to show — the spinner — only exists *during* the
  /// await, and the real path resolves in microtasks under `flutter_test`'s stubbed
  /// HttpClient, so the in-flight frame is never rendered and cannot be asserted.
  /// A seam is the honest way to test a state that is defined by being mid-flight.
  @visibleForTesting
  final Future<void> Function(BuildContext context)? publishOverride;

  @override
  State<PlanStatusBadge> createState() => _PlanStatusBadgeState();
}

class _PlanStatusBadgeState extends State<PlanStatusBadge> {
  StreamSubscription<PlanEvent>? _planEventsSub;

  /// Whether the active catalog plan has local edits that have not been
  /// published yet. Recomputed only on [PlanEvent]s (not on every build)
  /// so the plan content hash is not re-run on each rebuild.
  bool _hasUnpublishedChanges = false;

  /// True while a publish started from this badge is in flight.
  ///
  /// Publishing uploads the whole plan, so on a slow connection the tap looked
  /// like it did nothing until the result snackbar arrived seconds later. The
  /// outcome was never actually silent — `_runUpload` reports success, 409/412 and
  /// a catch-all failure — but with no in-flight feedback there is nothing to tell
  /// "working" from "the tap missed", and the natural response to that is to tap
  /// again.
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _refreshUnpublishedState();
    _scheduleProbeIfNeeded();
    // Re-evaluate when the active plan changes so switching to a fresh
    // catalog plan kicks off an initial probe. Also rebuild — the badge's
    // build method reads plan.source to choose between the local and
    // online variants, so a publish that flips source from local to catalog
    // must propagate through build, not just trigger a probe.
    _planEventsSub = PlanService().events.listen((_) {
      if (!mounted) return;
      _refreshUnpublishedState();
      setState(() {});
      _scheduleProbeIfNeeded();
    });
  }

  @override
  void dispose() {
    _planEventsSub?.cancel();
    super.dispose();
  }

  void _scheduleProbeIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final plan = PlanService().activePlan;
      if (plan == null || !active_actions.isCatalogPlan(plan)) {
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
    final plan = PlanService().activePlan;
    _hasUnpublishedChanges =
        plan != null &&
        active_actions.isCatalogPlan(plan) &&
        plan.contentHash != null &&
        plan.computeContentHash() != plan.contentHash;
  }

  Future<void> _onPublishTap() async {
    // Debounce: a second upload of the same plan would race the first and can
    // land a 412 against the etag the first one is about to move.
    if (_publishing) return;
    setState(() => _publishing = true);
    try {
      // Reuse the shared publish flow. For an already-published catalog plan
      // this is a one-tap silent update, with 412-conflict handling and a
      // result snackbar. A successful publish emits a PlanEvent that
      // flips this badge back to the plain online state.
      await (widget.publishOverride ?? active_actions.publishActivePlan)(
        context,
      );
    } catch (e, stackTrace) {
      // publishActivePlan reports its own failures — success, 409, 412 and a
      // catch-all all raise a snackbar — so anything arriving here is a path that
      // reporting missed. Caught rather than left to escape: a Future returned to
      // a VoidCallback becomes an unhandled async error, which is logged to the
      // console and nowhere the user or Sentry will see it.
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
    } finally {
      // finally, not after the await: the first-time path opens a dialog and the
      // conflict path opens another, either of which can throw or be dismissed.
      // Leaving the badge spinning forever would be worse than the missing
      // spinner this fixes.
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = PlanService().activePlan;
    if (plan == null) return const SizedBox.shrink();

    final isCatalog = active_actions.isCatalogPlan(plan);
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

    if (_hasUnpublishedChanges || _publishing) {
      // Kept on the unpublished branch while publishing even though the flag may
      // already have flipped: the badge must not change label mid-upload.
      return _BadgeChip(
        icon: Icons.cloud_upload_outlined,
        label: _publishing
            ? localizations.planStatusPublishing
            : localizations.planStatusUnpublished,
        color: foreground,
        tooltip: _publishing
            ? localizations.planStatusPublishing
            : localizations.planStatusUnpublishedTooltip,
        busy: _publishing,
        onTap: _publishing ? null : _onPublishTap,
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
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  /// Swaps the icon for a spinner of the same size, so the badge does not change
  /// width and shift the AppBar around it while working.
  final bool busy;

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
          if (busy)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
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
