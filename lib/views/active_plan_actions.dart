import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoid/nanoid.dart';
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/data/drill_library.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/services/catalog_refresh_indicator_registry.dart';
import 'package:ringdrill/services/catalog_status_service.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/views/add_exercises_dialog.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/catalog_conflict_dialog.dart';
import 'package:ringdrill/views/download_all_plans_dialog.dart';
import 'package:ringdrill/views/drill_format_messages.dart';
import 'package:ringdrill/views/export_plan_dialog.dart';
import 'package:ringdrill/views/library_view.dart';
import 'package:ringdrill/views/plan_view.dart';
import 'package:ringdrill/views/publish_plan_dialog.dart';
import 'package:ringdrill/views/widgets/ringdrill_picker.dart';
import 'package:ringdrill/web/trigger_download_web.dart'
    if (dart.library.io) 'package:ringdrill/web/trigger_download_stub.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> openPlan(BuildContext context) => showOpenPlanDialog(context);

/// Show the rename dialog for [plan] and persist the new name. Shared
/// between the appbar title tap and the library dialog's plan actions so
/// both surfaces use exactly the same prompt.
Future<void> renamePlan(BuildContext context, Plan plan) async {
  final localizations = AppLocalizations.of(context)!;
  final name = await showAdaptiveDialog<String>(
    context: context,
    builder: (context) => _PlanNameDialog(
      title: localizations.libraryRename,
      initialText: plan.name,
      actionLabel: localizations.save,
      cancelLabel: localizations.cancel,
    ),
  );
  if (name == null || name.isEmpty) return;
  final planService = PlanService();
  final loaded = planService.loadPlan(plan.uuid) ?? plan;
  final updated = loaded.copyWith(
    name: name,
    metadata: plan.metadata.copyWith(updated: DateTime.now()),
  );
  await planService.replacePlan(updated);
}

/// Convenience wrapper that renames the currently active plan. Used by the
/// appbar title tap; shows a snackbar when there is no active plan.
Future<void> renameActivePlan(BuildContext context) async {
  final localizations = AppLocalizations.of(context)!;
  final plan = PlanService().activePlan;
  if (plan == null) {
    _showSnackBar(context, localizations.requiresActivePlan);
    return;
  }
  await renamePlan(context, plan);
}

/// Pulls the latest version of a catalog-sourced [plan] and merges it
/// into the local copy via [PlanService.refreshCatalogItem], using the
/// shared catalog-conflict dialog to resolve any divergence.
///
/// No dedicated "in progress" UI here — callers are expected to already be
/// showing one: the Plan/Roster tabs' pull-to-refresh `RefreshIndicator`
/// (see plan_view.dart / roster_view.dart) covers the drag-gesture case,
/// and [refreshActivePlanFromCatalogViaIndicator] reuses that same indicator
/// for the drawer's "Oppdater fra katalog" entry. Only the eventual outcome
/// is surfaced, via a single plain result snackbar.
Future<void> refreshPlanFromCatalog(BuildContext context, Plan plan) async {
  final localizations = AppLocalizations.of(context)!;
  final client = _buildPublishClient();
  try {
    final outcome = await PlanService().refreshCatalogItem(
      plan.uuid,
      client,
      onConflict:
          (
            diff, {
            required ownedSlug,
            required remoteUnchanged,
            required localVersion,
            required catalogVersion,
          }) {
            return showCatalogConflictDialog(
              context,
              diff: diff,
              ownedSlug: ownedSlug,
              remoteUnchanged: remoteUnchanged,
              localVersion: localVersion,
              catalogVersion: catalogVersion,
            );
          },
    );
    debugPrint(
      '[refreshPlanFromCatalog] slug=${plan.source.whenOrNull(catalog: (slug, latestEtag, installedAt, latestVersion) => slug)} '
      'outcome=${outcome.kind}',
    );
    final message = _catalogRefreshMessage(localizations, outcome, plan);
    if (message != null && context.mounted) {
      _showSnackBar(context, message);
    }
  } catch (e, stackTrace) {
    // Genuinely unexpected at this point — the 404 "plan removed from
    // catalog" case is handled as a normal outcome above, not an
    // exception — so anything landing here (network failure, a server
    // error status, a parse failure) is worth having in Sentry instead of
    // silently swallowed, matching the other catch blocks in this file.
    // debugPrint too: Sentry only reports with analytics consent, and this
    // is exactly the failure someone would want to see locally while
    // debugging why a refresh keeps failing.
    debugPrint('[refreshPlanFromCatalog] failed: $e');
    if (context.mounted) {
      _showSnackBar(context, localizations.catalogServiceUnavailable);
    }
    unawaited(Sentry.captureException(e, stackTrace: stackTrace));
  }
}

/// Map a [CatalogRefreshOutcome] to a user-facing message. Returns null when
/// no feedback should be shown (e.g. when the plan is no longer available).
String? _catalogRefreshMessage(
  AppLocalizations localizations,
  CatalogRefreshOutcome outcome,
  Plan plan,
) {
  switch (outcome.kind) {
    case CatalogRefreshKind.upToDate:
      return localizations.catalogRefreshUpToDate(plan.name);
    case CatalogRefreshKind.updatedSilently:
      return localizations.catalogRefreshUpdated(plan.name);
    case CatalogRefreshKind.updatedAfterPrompt:
      // overwriteLocal: either applied a real catalog update or discarded
      // local-only edits. The service tells us which via remoteUnchanged.
      return outcome.remoteUnchanged
          ? localizations.catalogRefreshReverted(plan.name)
          : localizations.catalogRefreshUpdated(plan.name);
    case CatalogRefreshKind.cancelled:
      return localizations.catalogRefreshCancelled;
    case CatalogRefreshKind.forked:
      return localizations.catalogRefreshForked;
    case CatalogRefreshKind.published:
      return localizations.catalogRefreshPublished;
    case CatalogRefreshKind.failed:
      return null;
    case CatalogRefreshKind.removedFromCatalog:
      return localizations.catalogRefreshRemoved(plan.name);
  }
}

/// Convenience wrapper that refreshes the currently active plan from the
/// catalog; shows a snackbar when there is no active plan, or when the
/// active plan isn't catalog-sourced.
///
/// Used directly as the Plan/Roster tabs' `RefreshIndicator.onRefresh` —
/// the pull gesture itself is already the "in progress" UI, so this does
/// nothing extra to show one. For entry points with no such gesture (the
/// drawer's "Oppdater fra katalog"), use
/// [refreshActivePlanFromCatalogViaIndicator] instead, which reuses that
/// same indicator programmatically rather than calling this directly.
Future<void> refreshActivePlanFromCatalog(BuildContext context) async {
  final localizations = AppLocalizations.of(context)!;
  final plan = PlanService().activePlan;
  if (plan == null) {
    _showSnackBar(context, localizations.requiresActivePlan);
    return;
  }
  if (!isCatalogPlan(plan)) {
    _showSnackBar(context, localizations.catalogServiceUnavailable);
    return;
  }
  await refreshPlanFromCatalog(context, plan);
}

/// Same guard as [refreshActivePlanFromCatalog], but for entry points with
/// no pull gesture of their own — the drawer's "Oppdater fra katalog" entry,
/// which pops the drawer before this even starts, so by the time the network
/// fetch is running there is nothing else on screen showing anything
/// happened. Reuses whichever tab's pull-to-refresh `RefreshIndicator` is
/// currently visible (via [CatalogRefreshIndicatorRegistry]) instead of a
/// bespoke progress snackbar, so both entry points look identical.
///
/// Falls back to running the refresh directly — no visible progress, just
/// the eventual result snackbar — when the current tab has no such indicator
/// (e.g. the Kart/Stations tab).
Future<void> refreshActivePlanFromCatalogViaIndicator(
  BuildContext context,
) async {
  final localizations = AppLocalizations.of(context)!;
  final plan = PlanService().activePlan;
  if (plan == null) {
    _showSnackBar(context, localizations.requiresActivePlan);
    return;
  }
  if (!isCatalogPlan(plan)) {
    _showSnackBar(context, localizations.catalogServiceUnavailable);
    return;
  }
  final triggered = await CatalogRefreshIndicatorRegistry().trigger();
  if (triggered || !context.mounted) return;
  await refreshPlanFromCatalog(context, plan);
}

/// True when [plan] was installed from the online catalog (vs. local
/// or imported). Drives drawer-entry enablement for catalog-only actions.
bool isCatalogPlan(Plan plan) =>
    plan.source.toJson()['runtimeType'] == 'catalog';

/// Hits the catalog endpoint to update [CatalogStatusService] with a fresh
/// reachability outcome (online / unavailable / corsBlocked). Returns the
/// fetched feed when reachable, or an empty page otherwise so callers like
/// the library "På nett"-tab can render an empty list without a try/catch.
/// Both the library dialog and the appbar [PlanStatusBadge] use this so the
/// state transitions stay consistent.
Future<MarketFeedPageResponse> probeCatalogService(BuildContext context) async {
  // Capture localizations up-front: we may finish after the caller's widget
  // unmounts (e.g. the library dialog closes mid-fetch), in which case
  // reading from context post-await would throw.
  final localizations = AppLocalizations.of(context)!;
  final status = CatalogStatusService();
  status.setStatus(CatalogServiceState.checking);
  try {
    final feed = await _buildPublishClient().marketFeed();
    status.setStatus(CatalogServiceState.online);
    return feed;
  } catch (error) {
    final isCors = _isLikelyCatalogCorsBlocked(error);
    final details = error.toString();
    final tooltip = isCors
        ? '${localizations.catalogServiceCorsBlockedTooltip}\n\n$details'
        : details;
    status.setStatus(
      isCors
          ? CatalogServiceState.corsBlocked
          : CatalogServiceState.unavailable,
      tooltip: tooltip,
    );
    return const MarketFeedPageResponse(items: []);
  }
}

bool _isLikelyCatalogCorsBlocked(Object error) {
  if (!kIsWeb) return false;
  final message = error.toString();
  return message.contains('ClientException') &&
      message.contains('Failed to fetch') &&
      message.contains(AppConfig.ringDrillBaseUrl);
}

Future<void> createNewPlan(BuildContext context) async {
  final localizations = AppLocalizations.of(context)!;
  if (ExerciseService().isStarted) {
    _showSnackBar(context, localizations.libraryCannotSwitchRunning);
    return;
  }

  final name = await _promptPlanName(context, localizations);
  if (name == null || !context.mounted) return;

  final plan = await PlanService().createPlan(name: name);
  // ADR-0032 *Activation contract*: route to the new plan so the URL and
  // the in-memory active plan move together. The redirect gate runs
  // `setActive` as a side effect.
  if (context.mounted) context.go(planPath(plan.uuid));
}

Future<void> addExercises(BuildContext context) =>
    showAddExercisesDialog(context);

/// Same name-then-choose flow as [exportActivePlan], one level up: lets
/// the user name the bundle and pick which saved plans to include
/// (everything is preselected — see [showDownloadAllPlansDialog]), then
/// encodes the chosen plans into one drill-library ZIP and downloads
/// (web) or shares (native) it via [triggerDownload] — the same
/// cross-platform path `MigrationPage._export` already uses for the
/// migration exporter (ADR-0045).
Future<void> downloadAllPlans(BuildContext context) async {
  final localizations = AppLocalizations.of(context)!;
  final plans = PlanService()
      .listPlans()
      .map((shell) => PlanService().loadPlan(shell.uuid))
      .whereType<Plan>()
      .toList();

  final input = await showDownloadAllPlansDialog(
    context,
    plans: plans,
    localizations: localizations,
    title: localizations.libraryDownloadAll,
    actionLabel: localizations.downloadAction,
  );
  if (input == null || !context.mounted) return;

  final fileName = '${input.fileName}.zip';
  final bytes = DrillLibrary.fromPlans(input.plans);
  try {
    await triggerDownload(fileName, bytes);
    if (context.mounted) {
      _showSnackBar(context, localizations.exportSuccess(fileName));
    }
  } catch (e, stackTrace) {
    if (context.mounted) {
      _showSnackBar(context, localizations.exportFailure(fileName));
    }
    unawaited(Sentry.captureException(e, stackTrace: stackTrace));
  }
}

/// Drawer entry point that replaces the old single-purpose "Eksporter som
/// .drill" tile: lets the user choose between downloading the whole
/// library ([downloadAllPlans]) or just the active plan ([exportActivePlan])
/// instead of only ever offering the latter.
Future<void> downloadActivePlan(BuildContext context) async {
  final localizations = AppLocalizations.of(context)!;
  // Use the shared "pick one" primitive so this is a bottom sheet on
  // compact and a dialog on medium/expanded (the same adaptive split every
  // other picker uses), instead of always a bottom sheet.
  final choice = await showRingdrillPicker<String>(
    context: context,
    title: localizations.downloadTitle,
    items: const ['all', 'plan'],
    itemBuilder: (context, item, onTap) => switch (item) {
      'all' => ListTile(
        leading: const Icon(Icons.folder_zip_outlined),
        title: Text(localizations.libraryDownloadAll),
        onTap: onTap,
      ),
      _ => ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(localizations.libraryDownloadPlan),
        onTap: onTap,
      ),
    },
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'all':
      await downloadAllPlans(context);
    case 'plan':
      await exportActivePlan(context);
  }
}

/// Copies the catalog deep-link URL for the currently active plan to the
/// clipboard. Requires the active plan to be catalog-published — the drawer
/// tile is already gated on that via [isCatalogPlan], but we re-check here
/// as a safety-net.
Future<void> shareActivePlan(BuildContext context) async {
  final localizations = AppLocalizations.of(context)!;
  final plan = PlanService().activePlan;
  if (plan == null) {
    _showSnackBar(context, localizations.requiresActivePlan);
    return;
  }
  final slug = plan.source.whenOrNull(
    catalog: (slug, latestEtag, installedAt, latestVersion) => slug,
  );
  if (slug == null) {
    _showSnackBar(context, localizations.planStatusLocalTooltip);
    return;
  }
  await Clipboard.setData(ClipboardData(text: _buildShareableUrl(slug)));
  if (!context.mounted) return;
  _showSnackBar(context, localizations.planUrlCopied);
}

/// Builds the install URL a recipient can paste into a browser. Production
/// links always use the canonical App-Link host. Debug web builds that point
/// at a local catalog use the current Flutter web origin, because the local
/// Netlify function host serves API calls only and does not apply the SPA
/// `/i/<slug>` catch-all.
String _buildShareableUrl(String slug) {
  final baseUrl = AppConfig.catalogBaseUrl(
    isWeb: kIsWeb,
    isRelease: kReleaseMode,
    isDebug: kDebugMode,
  );
  final lower = baseUrl.toLowerCase();
  final isLocal = lower.contains('localhost') || lower.contains('127.0.0.1');
  if (kIsWeb && isLocal) return '${Uri.base.origin}/i/$slug';
  return 'https://ringdrill.app/i/$slug';
}

Future<void> sendActivePlanTo(BuildContext context) async {
  await _exportSelected(
    context,
    title: (localizations) => localizations.sendToAction,
    actionLabel: (localizations) => localizations.sendToActionButton,
    onSave: PlanPageController.sendDrillFileTo,
    onSuccess: (localizations, file) => localizations.sendToSuccess(file),
    onFailure: (localizations, file) => localizations.sendToFailure(file),
  );
}

Future<void> exportActivePlan(BuildContext context) async {
  await _exportSelected(
    context,
    title: (localizations) => localizations.libraryDownloadPlan,
    actionLabel: (localizations) => localizations.downloadAction,
    onSave: PlanPageController.saveDrillFile,
    onSuccess: (localizations, file) => localizations.exportSuccess(file),
    onFailure: (localizations, file) => localizations.exportFailure(file),
  );
}

Future<void> publishActivePlan(BuildContext context) async {
  final localizations = AppLocalizations.of(context)!;
  final planService = PlanService();
  final plan = planService.activePlan;
  if (plan == null) {
    _showSnackBar(context, localizations.requiresActivePlan);
    return;
  }
  final currentSlug = plan.source.whenOrNull(
    catalog: (slug, latestEtag, installedAt, latestVersion) => slug,
  );
  if (currentSlug != null) {
    // Already published — silent update.
    await runPublishPlan(
      context,
      planUuid: plan.uuid,
      slug: currentSlug,
      client: _buildPublishClient(),
    );
    return;
  }
  // First-time publish — show the dialog so the user can pick a slug.
  final input = await showPublishPlanDialog(
    context,
    plan: plan,
    mode: PublishDialogMode.firstTime,
  );
  if (input == null || !context.mounted) return;
  await runPublishPlan(
    context,
    planUuid: plan.uuid,
    slug: input.slug,
    client: _buildPublishClient(),
  );
}

Future<void> publishAsActivePlan(BuildContext context) async {
  final localizations = AppLocalizations.of(context)!;
  final planService = PlanService();
  final plan = planService.activePlan;
  if (plan == null) {
    _showSnackBar(context, localizations.requiresActivePlan);
    return;
  }
  final input = await showPublishPlanDialog(
    context,
    plan: plan,
    mode: PublishDialogMode.publishAs,
  );
  if (input == null || !context.mounted) return;
  await runPublishPlanAs(
    context,
    planUuid: plan.uuid,
    slug: input.slug,
    client: _buildPublishClient(),
  );
}

/// Builds a [DrillClient] pointed at the catalog endpoint. When the base URL
/// resolves to a local `netlify functions:serve` (no /api/* or /d/* redirects),
/// the deep-link calls are routed directly at the function path. See ADR-0013.
///
/// Exposed publicly so the library dialog, the add-exercises sheet and the
/// publish helpers all share one DrillClient construction recipe.
DrillClient buildCatalogClient() {
  final baseUrl = AppConfig.catalogBaseUrl(
    isWeb: kIsWeb,
    isRelease: kReleaseMode,
    isDebug: kDebugMode,
  );
  return DrillClient(
    baseUrl: baseUrl,
    functionsBasePath: AppConfig.functionsBasePathFor(baseUrl),
    deepLinkBasePath: AppConfig.deepLinkBasePathFor(baseUrl),
  );
}

DrillClient _buildPublishClient() => buildCatalogClient();

Future<DrillFile?> pickOpenPlanFile(BuildContext context) {
  return PlanPageController.pickOpenFile(
    context,
    _constraintsFor(context),
    AppLocalizations.of(context)!,
  );
}

/// Outcome of [installPickedPlanFile]. The caller decides where to
/// surface the message — typically inline inside the host dialog,
/// because a snackbar dispatched from inside a modal dialog ends up
/// behind the modal backdrop and the user never sees it.
class InstallPickedOutcome {
  const InstallPickedOutcome._({
    this.plan,
    this.bundle,
    this.errorMessage,
    this.isFormatError = false,
  });

  /// Set on single-`.drill` success. The plan has already been installed
  /// and activated.
  final Plan? plan;

  /// Set on drill-library success. Every contained plan has already been
  /// installed; per ADR-0045 nothing is activated.
  final BundleInstallResult? bundle;

  /// Localized, user-ready message. Null on success and on user cancel.
  final String? errorMessage;

  /// True when [errorMessage] originated from a format problem (user
  /// picked the wrong file, or a bundle had no readable entries). False
  /// for generic install failures or system-state refusals such as
  /// "cannot switch while running".
  final bool isFormatError;

  bool get isSuccess => plan != null;
  bool get isBundle => bundle != null;
  bool get isCancelled =>
      plan == null && bundle == null && errorMessage == null;
}

Future<InstallPickedOutcome> installPickedPlanFile(BuildContext context) async {
  final localizations = AppLocalizations.of(context)!;
  if (ExerciseService().isStarted) {
    return InstallPickedOutcome._(
      errorMessage: localizations.libraryCannotSwitchRunning,
    );
  }
  final drillFile = await pickOpenPlanFile(context);
  if (!context.mounted || drillFile == null) {
    return const InstallPickedOutcome._();
  }

  final kind = DrillLibrary.sniff(drillFile.content);
  if (kind == DrillArchiveKind.invalid) {
    // Same wrong-file message as the single-.drill path below: from the
    // user's perspective this is one failure mode ("picked the wrong
    // file"), regardless of which parser ultimately rejected it.
    return InstallPickedOutcome._(
      errorMessage: drillFormatMessage(
        localizations,
        drillFile.fileName,
        DrillFormatReason.notArchive,
      ),
      isFormatError: true,
    );
  }

  if (kind == DrillArchiveKind.library) {
    try {
      final result = await PlanService().installBundle(
        drillFile.content,
        sourceName: drillFile.fileName,
      );
      if (result.isEmpty) {
        return InstallPickedOutcome._(
          errorMessage: localizations.importBundleEmpty,
          isFormatError: true,
        );
      }
      return InstallPickedOutcome._(bundle: result);
    } on DrillLibraryException {
      // Container-level failure even though sniff() classified this as a
      // library — same user-input-problem rationale as DrillFormatException
      // below, so no Sentry noise.
      return InstallPickedOutcome._(
        errorMessage: localizations.importBundleEmpty,
        isFormatError: true,
      );
    } catch (e, stackTrace) {
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      return InstallPickedOutcome._(
        errorMessage: localizations.openFailure(drillFile.fileName),
      );
    }
  }

  try {
    final plan = await PlanService().installFromFile(drillFile, activate: true);
    return InstallPickedOutcome._(plan: plan);
  } on DrillFormatException catch (e) {
    // Format errors come from the user picking the wrong file, not
    // from an app bug. Surface the reason-specific localized message
    // and skip Sentry so that channel stays signal-only.
    return InstallPickedOutcome._(
      errorMessage: drillFormatMessage(
        localizations,
        drillFile.fileName,
        e.reason,
      ),
      isFormatError: true,
    );
  } catch (e, stackTrace) {
    unawaited(Sentry.captureException(e, stackTrace: stackTrace));
    return InstallPickedOutcome._(
      errorMessage: localizations.openFailure(drillFile.fileName),
    );
  }
}

typedef _SaveDrillFile =
    Future<bool> Function(
      BuildContext context,
      BoxConstraints constraints,
      AppLocalizations localizations,
      DrillFile drillFile,
    );

Future<void> _exportSelected(
  BuildContext context, {
  required String Function(AppLocalizations localizations) title,
  required String Function(AppLocalizations localizations) actionLabel,
  required _SaveDrillFile onSave,
  required String Function(AppLocalizations localizations, String fileName)
  onSuccess,
  required String Function(AppLocalizations localizations, String fileName)
  onFailure,
}) async {
  final localizations = AppLocalizations.of(context)!;
  final planService = PlanService();
  final plan = planService.activePlan;
  if (plan == null) {
    _showSnackBar(context, localizations.requiresActivePlan);
    return;
  }
  // A plan with no exercises yet is still a valid .drill (a plan shell
  // with metadata, teams, etc.) — DrillFile.fromPlan and DrillLibrary
  // both handle an empty exercises list, so there is no reason to block
  // export/send on exercise count.
  final exercises = planService.loadExercises();

  final input = await showExportPlanDialog(
    context,
    plan: plan,
    exercises: exercises,
    localizations: localizations,
    title: title(localizations),
    actionLabel: actionLabel(localizations),
  );
  if (input == null || !context.mounted) return;

  final drillFile = await planService.exportPlan(
    nanoid(10),
    input.fileName,
    input.selectedUuids,
  );
  try {
    if (!context.mounted) return;
    final result = await onSave(
      context,
      _constraintsFor(context),
      localizations,
      drillFile,
    );
    if (context.mounted && result) {
      _showSnackBar(context, onSuccess(localizations, drillFile.fileName));
    }
  } on Exception catch (e, stackTrace) {
    if (context.mounted) {
      _showSnackBar(context, onFailure(localizations, drillFile.fileName));
    }
    unawaited(Sentry.captureException(e, stackTrace: stackTrace));
  }
}

Future<String?> _promptPlanName(
  BuildContext context,
  AppLocalizations localizations,
) async {
  final name = await showAdaptiveDialog<String>(
    context: context,
    builder: (context) => _PlanNameDialog(
      title: localizations.newPlanNamePrompt,
      hintText: localizations.plan(1),
      actionLabel: localizations.create,
      cancelLabel: localizations.cancel,
    ),
  );
  if (name == null || name.isEmpty) return null;
  return name;
}

/// Single-field name prompt for both creating and renaming a plan. The
/// [TextEditingController] is owned by this widget's [State] so it is disposed
/// only when the dialog route is removed from the tree — i.e. *after* the pop
/// transition finishes. Disposing it inline right after `showAdaptiveDialog`
/// returned tore it down while the still-animating TextField was rebuilding,
/// throwing "A TextEditingController was used after being disposed."
class _PlanNameDialog extends StatefulWidget {
  const _PlanNameDialog({
    required this.title,
    required this.actionLabel,
    required this.cancelLabel,
    this.initialText,
    this.hintText,
  });

  final String title;
  final String actionLabel;
  final String cancelLabel;
  final String? initialText;
  final String? hintText;

  @override
  State<_PlanNameDialog> createState() => _PlanNameDialogState();
}

class _PlanNameDialogState extends State<_PlanNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: widget.hintText == null
            ? null
            : InputDecoration(hintText: widget.hintText),
        onSubmitted: (_) => Navigator.pop(context, _controller.text.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}

BoxConstraints _constraintsFor(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return BoxConstraints.tight(size);
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      showCloseIcon: true,
      dismissDirection: DismissDirection.endToStart,
      content: Text(message),
    ),
  );
}
