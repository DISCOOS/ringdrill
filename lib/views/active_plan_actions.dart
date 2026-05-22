import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoid/nanoid.dart';
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/services/catalog_status_service.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/views/add_exercises_dialog.dart';
import 'package:ringdrill/views/catalog_conflict_dialog.dart';
import 'package:ringdrill/views/export_plan_dialog.dart';
import 'package:ringdrill/views/library_view.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:ringdrill/views/publish_plan_dialog.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> openPlan(BuildContext context) => showOpenPlanDialog(context);

/// Show the rename dialog for [program] and persist the new name. Shared
/// between the appbar title tap and the library dialog's plan actions so
/// both surfaces use exactly the same prompt.
Future<void> renamePlan(BuildContext context, Program program) async {
  final localizations = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: program.name);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(localizations.libraryRename),
      content: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => Navigator.pop(context, controller.text.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localizations.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text(localizations.save),
        ),
      ],
    ),
  );
  controller.dispose();
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
  final localizations = AppLocalizations.of(context)!;
  final programService = ProgramService();
  if (programService.activeProgramUuid == program.uuid &&
      ExerciseService().isStarted) {
    _showSnackBar(context, localizations.libraryCannotSwitchRunning);
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(localizations.confirm),
      content: Text(localizations.confirmDeleteExercise),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(localizations.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(localizations.delete),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
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
    await ProgramService().refreshCatalogItem(
      program.uuid,
      client,
      onConflict: (diff, {required ownedSlug}) {
        return showCatalogConflictDialog(
          context,
          diff: diff,
          ownedSlug: ownedSlug,
        );
      },
    );
  } catch (_) {
    if (!context.mounted) return;
    _showSnackBar(context, localizations.catalogServiceUnavailable);
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
  await ProgramService().setActive(program.uuid);
}

Future<void> addExercises(BuildContext context) =>
    showAddExercisesDialog(context);

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
    title: (localizations) => localizations.exportAsDrill,
    actionLabel: (localizations) => localizations.exportAction,
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
      tags: const [],
      client: _buildPublishClient(),
    );
    return;
  }
  // First-time publish — show the dialog.
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
    tags: input.tags,
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
    tags: input.tags,
    client: _buildPublishClient(),
  );
}

DrillClient _buildPublishClient() {
  final baseUrl = AppConfig.catalogBaseUrl(
    isWeb: kIsWeb,
    isRelease: kReleaseMode,
    isDebug: kDebugMode,
  );
  return DrillClient(
    baseUrl: baseUrl,
    deepLinkBasePath: AppConfig.deepLinkBasePathFor(baseUrl),
  );
}

Future<DrillFile?> pickOpenPlanFile(BuildContext context) {
  return ProgramPageController.pickOpenFile(
    context,
    _constraintsFor(context),
    AppLocalizations.of(context)!,
  );
}

Future<void> installPickedPlanFile(BuildContext context) async {
  final localizations = AppLocalizations.of(context)!;
  if (ExerciseService().isStarted) {
    _showSnackBar(context, localizations.libraryCannotSwitchRunning);
    return;
  }
  final drillFile = await pickOpenPlanFile(context);
  if (!context.mounted || drillFile == null) return;

  try {
    final program = await ProgramService().installFromFile(
      drillFile,
      activate: true,
    );
    if (context.mounted) {
      _showSnackBar(context, localizations.openedAndActivated(program.name));
    }
  } catch (e, stackTrace) {
    if (context.mounted) {
      _showSnackBar(context, localizations.openFailure(drillFile.fileName));
    }
    unawaited(Sentry.captureException(e, stackTrace: stackTrace));
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
  final exercises = programService.loadExercises();
  if (exercises.isEmpty) {
    _showSnackBar(context, localizations.noExercisesYet);
    return;
  }

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
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(localizations.newPlanNamePrompt),
      content: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(hintText: localizations.program(1)),
        onSubmitted: (_) => Navigator.pop(context, controller.text.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localizations.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text(localizations.create),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null || name.isEmpty) return null;
  return name;
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
