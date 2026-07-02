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
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/services/catalog_status_service.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/context_extensions.dart';
import 'package:ringdrill/views/add_exercises_dialog.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/catalog_conflict_dialog.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/download_all_plans_dialog.dart';
import 'package:ringdrill/views/drill_format_messages.dart';
import 'package:ringdrill/views/export_plan_dialog.dart';
import 'package:ringdrill/views/library_view.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:ringdrill/views/publish_plan_dialog.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';
import 'package:ringdrill/web/trigger_download_web.dart'
    if (dart.library.io) 'package:ringdrill/web/trigger_download_stub.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> openPlan(BuildContext context) => showOpenPlanDialog(context);

/// Show the rename dialog for [program] and persist the new name. Shared
/// between the appbar title tap and the library dialog's plan actions so
/// both surfaces use exactly the same prompt.
Future<void> renamePlan(BuildContext context, Program program) async {
  final localizations = AppLocalizations.of(context)!;
  final name = await showAdaptiveDialog<String>(
    context: context,
    builder: (context) => _PlanNameDialog(
      title: localizations.libraryRename,
      initialText: program.name,
      actionLabel: localizations.save,
      cancelLabel: localizations.cancel,
    ),
  );
  if (name == null || name.isEmpty) return;
  final programService = ProgramService();
  final loaded = programService.loadProgram(program.uuid) ?? program;
  final updated = loaded.copyWith(
    name: name,
    metadata: program.metadata.copyWith(updated: DateTime.now()),
  );
  await programService.replaceProgram(updated);
}

/// Convenience wrapper that renames the currently active plan. Used by the
/// appbar title tap; shows a snackbar when there is no active plan.
Future<void> renameActivePlan(BuildContext context) async {
  final localizations = AppLocalizations.of(context)!;
  final program = ProgramService().activeProgram;
  if (program == null) {
    _showSnackBar(context, localizations.requiresActivePlan);
    return;
  }
  await renamePlan(context, program);
}

/// Show the delete-confirmation dialog for [program] and remove it from the
/// library when confirmed. Refuses with a snackbar if the program is active
/// and an exercise is currently running.
Future<void> deletePlan(BuildContext context, Program program) async {
  final localizations = context.l10n;
  final programService = ProgramService();
  if (programService.activeProgramUuid == program.uuid &&
      ExerciseService().isStarted) {
    _showSnackBar(context, localizations.libraryCannotSwitchRunning);
    return;
  }
  // Per ADR-0038 the library always keeps at least one plan around.
  // Refuse with a snackbar before the destructive-confirm dialog so
  // the user knows what they need to do instead.
  if (programService.listPrograms().length <= 1) {
    _showSnackBar(context, localizations.cannotDeleteLastPlan);
    return;
  }
  final confirmed = await confirmDestructive(
    context,
    title: localizations.confirm,
    message: localizations.confirmDeleteExercise,
    confirmLabel: localizations.delete,
  );
  if (!confirmed) return;
  await programService.deleteProgram(program.uuid);
}

/// Convenience wrapper that deletes the currently active plan. Used by the
/// drawer's delete entry; shows a snackbar when there is no active plan.
Future<void> deleteActivePlan(BuildContext context) async {
  final localizations = AppLocalizations.of(context)!;
  final program = ProgramService().activeProgram;
  if (program == null) {
    _showSnackBar(context, localizations.requiresActivePlan);
    return;
  }
  await deletePlan(context, program);
}

/// Pulls the latest version of a catalog-sourced [program] and merges it
/// into the local copy via [ProgramService.refreshCatalogItem], using the
/// shared catalog-conflict dialog to resolve any divergence. Shows a
/// snackbar when the catalog service is unreachable.
Future<void> refreshPlanFromCatalog(
  BuildContext context,
  Program program,
) async {
  final localizations = AppLocalizations.of(context)!;
  final client = _buildPublishClient();
  try {
    final outcome = await ProgramService().refreshCatalogItem(
      program.uuid,
      client,
      onConflict: (diff, {required ownedSlug, required remoteUnchanged}) {
        return showCatalogConflictDialog(
          context,
          diff: diff,
          ownedSlug: ownedSlug,
          remoteUnchanged: remoteUnchanged,
        );
      },
    );
    if (!context.mounted) return;
    final message = _catalogRefreshMessage(localizations, outcome, program);
    if (message != null) _showSnackBar(context, message);
  } catch (_) {
    if (!context.mounted) return;
    _showSnackBar(context, localizations.catalogServiceUnavailable);
  }
}

/// Map a [CatalogRefreshOutcome] to a user-facing message. Returns null when
/// no feedback should be shown (e.g. when the program is no longer available).
String? _catalogRefreshMessage(
  AppLocalizations localizations,
  CatalogRefreshOutcome outcome,
  Program program,
) {
  switch (outcome.kind) {
    case CatalogRefreshKind.upToDate:
      return localizations.catalogRefreshUpToDate(program.name);
    case CatalogRefreshKind.updatedSilently:
      return localizations.catalogRefreshUpdated(program.name);
    case CatalogRefreshKind.updatedAfterPrompt:
      // overwriteLocal: either applied a real catalog update or discarded
      // local-only edits. The service tells us which via remoteUnchanged.
      return outcome.remoteUnchanged
          ? localizations.catalogRefreshReverted(program.name)
          : localizations.catalogRefreshUpdated(program.name);
    case CatalogRefreshKind.cancelled:
      return localizations.catalogRefreshCancelled;
    case CatalogRefreshKind.forked:
      return localizations.catalogRefreshForked;
    case CatalogRefreshKind.published:
      return localizations.catalogRefreshPublished;
    case CatalogRefreshKind.failed:
      return null;
  }
}

/// Convenience wrapper that refreshes the currently active plan from the
/// catalog. Used by the drawer's refresh entry; shows a snackbar when
/// there is no active plan, or when the active plan isn't catalog-sourced.
Future<void> refreshActivePlanFromCatalog(BuildContext context) async {
  final localizations = AppLocalizations.of(context)!;
  final program = ProgramService().activeProgram;
  if (program == null) {
    _showSnackBar(context, localizations.requiresActivePlan);
    return;
  }
  if (!isCatalogProgram(program)) {
    _showSnackBar(context, localizations.catalogServiceUnavailable);
    return;
  }
  await refreshPlanFromCatalog(context, program);
}

/// True when [program] was installed from the online catalog (vs. local
/// or imported). Drives drawer-entry enablement for catalog-only actions.
bool isCatalogProgram(Program program) =>
    program.source.toJson()['runtimeType'] == 'catalog';

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

  final program = await ProgramService().createProgram(name: name);
  // ADR-0032 *Activation contract*: route to the new plan so the URL and
  // the in-memory active program move together. The redirect gate runs
  // `setActive` as a side effect.
  if (context.mounted) context.go(programPath(program.uuid));
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
  final programs = ProgramService()
      .listPrograms()
      .map((shell) => ProgramService().loadProgram(shell.uuid))
      .whereType<Program>()
      .toList();

  final input = await showDownloadAllPlansDialog(
    context,
    programs: programs,
    localizations: localizations,
    title: localizations.libraryDownloadAll,
    actionLabel: localizations.downloadAction,
  );
  if (input == null || !context.mounted) return;

  final fileName = '${input.fileName}.zip';
  final bytes = DrillLibrary.fromPrograms(input.programs);
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
  final choice = await showRingdrillActionSheet<String>(
    context: context,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.folder_zip_outlined),
          title: Text(localizations.libraryDownloadAll),
          onTap: () => Navigator.pop(context, 'all'),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(localizations.libraryDownloadPlan),
          onTap: () => Navigator.pop(context, 'plan'),
        ),
      ],
    ),
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
/// tile is already gated on that via [isCatalogProgram], but we re-check here
/// as a safety-net.
Future<void> shareActivePlan(BuildContext context) async {
  final localizations = AppLocalizations.of(context)!;
  final program = ProgramService().activeProgram;
  if (program == null) {
    _showSnackBar(context, localizations.requiresActivePlan);
    return;
  }
  final slug = program.source.whenOrNull(
    catalog: (slug, latestEtag, installedAt) => slug,
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
    onSave: ProgramPageController.sendDrillFileTo,
    onSuccess: (localizations, file) => localizations.sendToSuccess(file),
    onFailure: (localizations, file) => localizations.sendToFailure(file),
  );
}

Future<void> exportActivePlan(BuildContext context) async {
  await _exportSelected(
    context,
    title: (localizations) => localizations.libraryDownloadPlan,
    actionLabel: (localizations) => localizations.downloadAction,
    onSave: ProgramPageController.saveDrillFile,
    onSuccess: (localizations, file) => localizations.exportSuccess(file),
    onFailure: (localizations, file) => localizations.exportFailure(file),
  );
}

Future<void> publishActivePlan(BuildContext context) async {
  final localizations = AppLocalizations.of(context)!;
  final programService = ProgramService();
  final program = programService.activeProgram;
  if (program == null) {
    _showSnackBar(context, localizations.requiresActivePlan);
    return;
  }
  final currentSlug = program.source.whenOrNull(
    catalog: (slug, latestEtag, installedAt) => slug,
  );
  if (currentSlug != null) {
    // Already published — silent update.
    await runPublishProgram(
      context,
      programUuid: program.uuid,
      slug: currentSlug,
      client: _buildPublishClient(),
    );
    return;
  }
  // First-time publish — show the dialog so the user can pick a slug.
  final input = await showPublishPlanDialog(
    context,
    program: program,
    mode: PublishDialogMode.firstTime,
  );
  if (input == null || !context.mounted) return;
  await runPublishProgram(
    context,
    programUuid: program.uuid,
    slug: input.slug,
    client: _buildPublishClient(),
  );
}

Future<void> publishAsActivePlan(BuildContext context) async {
  final localizations = AppLocalizations.of(context)!;
  final programService = ProgramService();
  final program = programService.activeProgram;
  if (program == null) {
    _showSnackBar(context, localizations.requiresActivePlan);
    return;
  }
  final input = await showPublishPlanDialog(
    context,
    program: program,
    mode: PublishDialogMode.publishAs,
  );
  if (input == null || !context.mounted) return;
  await runPublishProgramAs(
    context,
    programUuid: program.uuid,
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
  return ProgramPageController.pickOpenFile(
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
    this.program,
    this.bundle,
    this.errorMessage,
    this.isFormatError = false,
  });

  /// Set on single-`.drill` success. The plan has already been installed
  /// and activated.
  final Program? program;

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

  bool get isSuccess => program != null;
  bool get isBundle => bundle != null;
  bool get isCancelled =>
      program == null && bundle == null && errorMessage == null;
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
        DrillFormatException(
          DrillFormatReason.notArchive,
          'Invalid file: not a .drill or drill-library archive.',
        ),
      ),
      isFormatError: true,
    );
  }

  if (kind == DrillArchiveKind.library) {
    try {
      final result = await ProgramService().installBundle(
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
    final program = await ProgramService().installFromFile(
      drillFile,
      activate: true,
    );
    return InstallPickedOutcome._(program: program);
  } on DrillFormatException catch (e) {
    // Format errors come from the user picking the wrong file, not
    // from an app bug. Surface the reason-specific localized message
    // and skip Sentry so that channel stays signal-only.
    return InstallPickedOutcome._(
      errorMessage: drillFormatMessage(localizations, drillFile.fileName, e),
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
  final programService = ProgramService();
  final program = programService.activeProgram;
  if (program == null) {
    _showSnackBar(context, localizations.requiresActivePlan);
    return;
  }
  // A plan with no exercises yet is still a valid .drill (a program shell
  // with metadata, teams, etc.) — DrillFile.fromProgram and DrillLibrary
  // both handle an empty exercises list, so there is no reason to block
  // export/send on exercise count.
  final exercises = programService.loadExercises();

  final input = await showExportPlanDialog(
    context,
    program: program,
    exercises: exercises,
    localizations: localizations,
    title: title(localizations),
    actionLabel: actionLabel(localizations),
  );
  if (input == null || !context.mounted) return;

  final drillFile = await programService.exportProgram(
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
      hintText: localizations.program(1),
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
