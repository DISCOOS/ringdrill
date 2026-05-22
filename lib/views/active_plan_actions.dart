import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nanoid/nanoid.dart';
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/views/add_exercises_dialog.dart';
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

Future<void> shareActivePlan(BuildContext context) async {
  await _exportSelected(
    context,
    title: (localizations) => localizations.shareProgram,
    onSave: ProgramPageController.shareDrillFile,
    onSuccess: (localizations, file) => localizations.shareSuccess(file),
    onFailure: (localizations, file) => localizations.shareFailure(file),
  );
}

Future<void> sendActivePlanTo(BuildContext context) async {
  await _exportSelected(
    context,
    title: (localizations) => localizations.sendToProgram,
    onSave: ProgramPageController.sendDrillFileTo,
    onSuccess: (localizations, file) => localizations.sendToSuccess(file),
    onFailure: (localizations, file) => localizations.sendToFailure(file),
  );
}

Future<void> exportActivePlan(BuildContext context) async {
  await _exportSelected(
    context,
    title: (localizations) => localizations.exportProgram,
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
  required _SaveDrillFile onSave,
  required String Function(AppLocalizations localizations, String fileName)
  onSuccess,
  required String Function(AppLocalizations localizations, String fileName)
  onFailure,
}) async {
  final localizations = AppLocalizations.of(context)!;
  final programService = ProgramService();
  final constraints = _constraintsFor(context);
  final selected = await ProgramPageControllerBase.selectExercises(
    context,
    title(localizations),
    programService.loadExercises(),
    constraints,
    localizations,
    false,
  );
  if (selected.isEmpty || !context.mounted) return;

  final fileName = await ProgramPageControllerBase.promptFileName(
    context,
    localizations,
  );
  if (!context.mounted || fileName == null) return;

  final drillFile = await programService.exportProgram(
    nanoid(10),
    fileName,
    selected,
  );
  try {
    if (!context.mounted) return;
    final result = await onSave(context, constraints, localizations, drillFile);
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
