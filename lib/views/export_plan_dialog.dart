import 'package:flutter/material.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:ringdrill/views/widgets/name_step_sheet.dart';

/// Result returned by [showExportPlanDialog].
class ExportPlanInput {
  const ExportPlanInput({required this.fileName, required this.selectedUuids});

  /// The file name (without `.drill` suffix) the user wants to save as.
  final String fileName;

  /// UUIDs of the exercises the user wants included in the export.
  final List<String> selectedUuids;
}

/// Combined export-flow dialog for a single plan ("Last ned plan").
///
/// Step 1 — [showNameStepSheet] with a file-name field pre-filled with
/// `sanitizeSlug(program.name)`, falling back to
/// [AppLocalizations.fileNameHint] if the slug is empty.
///
/// Step 2 (only if the user picked "VELG...") — the existing
/// [ProgramPageControllerBase.selectExercises] bottom sheet, opened with
/// every exercise pre-selected, a "VELG ALLE"/"VELG INGEN" header row, and
/// the [actionLabel] on the primary button.
///
/// Returns `null` if the user cancels at any point or leaves the file name
/// empty. The caller is responsible for the actual save (the dialog only
/// gathers user intent).
Future<ExportPlanInput?> showExportPlanDialog(
  BuildContext context, {
  required Program program,
  required List<Exercise> exercises,
  required AppLocalizations localizations,
  required String title,
  required String actionLabel,
}) async {
  final initialFileName = _initialFileName(program, localizations);
  final result = await showNameStepSheet(
    context,
    initialFileName: initialFileName,
    fileSuffix: '.drill',
    title: title,
    actionLabel: actionLabel,
    allIncludedHint: localizations.exportAllExercisesHint,
    hasItems: exercises.isNotEmpty,
    chooseDisabledTooltip: localizations.selectExercisesDisabledTooltip,
    localizations: localizations,
  );

  if (result == null || result.action == NameStepAction.cancel) return null;

  final fileName = result.fileName;
  if (fileName.isEmpty) return null;

  if (result.action == NameStepAction.confirmAll) {
    return ExportPlanInput(
      fileName: fileName,
      selectedUuids: exercises.map((e) => e.uuid).toList(),
    );
  }

  // chooseItems — show the exercise picker with everything pre-selected.
  if (!context.mounted) return null;
  final selectedUuids = await ProgramPageControllerBase.selectExercises(
    context,
    title,
    exercises,
    localizations,
    confirmLabel: actionLabel,
    preselectAll: true,
    showSelectAllControls: true,
    program: program,
  );
  if (selectedUuids.isEmpty) return null;
  return ExportPlanInput(fileName: fileName, selectedUuids: selectedUuids);
}

/// Default file name for the export dialog. Falls back to the localized hint
/// when the active plan's name slugifies to an empty string (e.g. all-symbol
/// names like "🚓").
String _initialFileName(Program program, AppLocalizations localizations) {
  final slug = sanitizeSlug(program.name);
  return slug.isEmpty ? localizations.fileNameHint : slug;
}
