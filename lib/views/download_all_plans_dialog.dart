import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:ringdrill/data/bulk_export.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/views/select_plans_dialog.dart';
import 'package:ringdrill/views/widgets/name_step_sheet.dart';

/// Result returned by [showDownloadAllPlansDialog].
class DownloadPlansInput {
  const DownloadPlansInput({required this.fileName, required this.programs});

  /// The file name (without `.zip` suffix) the user wants to save as.
  final String fileName;

  /// The plans the user wants included in the bundle.
  final List<Program> programs;
}

/// Combined download-flow dialog for the whole library ("Last ned alle").
/// Mirrors [showExportPlanDialog] so downloading a single plan and
/// downloading the whole library are the same flow with a different unit:
///
/// Step 1 — [showNameStepSheet] with a file-name field pre-filled with
/// [bulkExportFileName] (minus the `.zip` suffix, which the sheet renders
/// separately).
///
/// Step 2 (only if the user picked "VELG...") — [showSelectPlansDialog],
/// opened with every plan pre-selected.
///
/// Returns `null` if the user cancels at any point or leaves the file name
/// empty. The caller is responsible for the actual encode + download (the
/// dialog only gathers user intent).
Future<DownloadPlansInput?> showDownloadAllPlansDialog(
  BuildContext context, {
  required List<Program> programs,
  required AppLocalizations localizations,
  required String title,
  required String actionLabel,
}) async {
  final initialFileName = path.basenameWithoutExtension(
    bulkExportFileName(DateTime.now()),
  );
  final result = await showNameStepSheet(
    context,
    initialFileName: initialFileName,
    fileSuffix: '.zip',
    title: title,
    actionLabel: actionLabel,
    allIncludedHint: localizations.exportAllPlansHint,
    hasItems: programs.isNotEmpty,
    chooseDisabledTooltip: localizations.selectPlansDisabledTooltip,
    localizations: localizations,
  );

  if (result == null || result.action == NameStepAction.cancel) return null;

  final fileName = result.fileName;
  if (fileName.isEmpty) return null;

  if (result.action == NameStepAction.confirmAll) {
    return DownloadPlansInput(fileName: fileName, programs: programs);
  }

  // chooseItems — show the plan picker with everything pre-selected.
  if (!context.mounted) return null;
  final selectedUuids = await showSelectPlansDialog(
    context,
    programs: programs,
    localizations: localizations,
    title: title,
    actionLabel: actionLabel,
  );
  if (selectedUuids == null || selectedUuids.isEmpty) return null;
  final selected = programs
      .where((program) => selectedUuids.contains(program.uuid))
      .toList();
  return DownloadPlansInput(fileName: fileName, programs: selected);
}
