import 'package:flutter/material.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/views/program_view.dart';

/// Result returned by [showExportPlanDialog].
class ExportPlanInput {
  const ExportPlanInput({required this.fileName, required this.selectedUuids});

  /// The file name (without `.drill` suffix) the user wants to save as.
  final String fileName;

  /// UUIDs of the exercises the user wants included in the export.
  final List<String> selectedUuids;
}

/// Sheet actions a single bottom sheet can produce. Not exported.
enum _ExportSheetAction { cancel, chooseExercises, exportAll }

/// Combined export-flow dialog.
///
/// Step 1 — bottom sheet with:
///   * a file-name field pre-filled with `sanitizeSlug(program.name)`,
///     falling back to [AppLocalizations.fileNameHint] if the slug is empty,
///   * a hint line explaining what the buttons do,
///   * three buttons: cancel · "VELG ØVELSER..." · primary action label.
///     The title (e.g. "Eksporter som .drill") is rendered next to the
///     buttons rather than as a tall centered header, on the same line when
///     there is room.
///
/// Step 2 (only if the user picked "VELG ØVELSER...") — the existing
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
  required BoxConstraints constraints,
  required AppLocalizations localizations,
  required String title,
  required String actionLabel,
}) async {
  final initialFileName = _initialFileName(program, localizations);
  final controller = TextEditingController(text: initialFileName);
  // Track current text to enable/disable the primary buttons.
  final canSubmit = ValueNotifier<bool>(initialFileName.trim().isNotEmpty);
  void onTextChanged() {
    canSubmit.value = controller.text.trim().isNotEmpty;
  }

  controller.addListener(onTextChanged);

  try {
    final action = await showModalBottomSheet<_ExportSheetAction>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20.0,
            right: 20.0,
            top: 8.0,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20.0,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8.0),
                TextField(
                  controller: controller,
                  autofocus: false,
                  decoration: InputDecoration(
                    labelText: localizations.enterFileName,
                    hintText: localizations.fileNameHint,
                    suffixText: '.drill',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20.0),
                Text(
                  localizations.exportAllExercisesHint,
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      sheetContext,
                    ).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24.0),
                ValueListenableBuilder<bool>(
                  valueListenable: canSubmit,
                  builder: (context, enabled, _) {
                    return _ActionRow(
                      title: title,
                      buttons: [
                        TextButton(
                          onPressed: () => Navigator.pop(
                            sheetContext,
                            _ExportSheetAction.cancel,
                          ),
                          child: Text(localizations.cancel),
                        ),
                        TextButton(
                          onPressed: enabled
                              ? () => Navigator.pop(
                                  sheetContext,
                                  _ExportSheetAction.chooseExercises,
                                )
                              : null,
                          child: Text(localizations.selectExercisesAction),
                        ),
                        FilledButton(
                          onPressed: enabled
                              ? () => Navigator.pop(
                                  sheetContext,
                                  _ExportSheetAction.exportAll,
                                )
                              : null,
                          child: Text(actionLabel),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8.0),
              ],
            ),
          ),
        );
      },
    );

    if (action == null || action == _ExportSheetAction.cancel) return null;

    final fileName = controller.text.trim();
    if (fileName.isEmpty) return null;

    if (action == _ExportSheetAction.exportAll) {
      return ExportPlanInput(
        fileName: fileName,
        selectedUuids: exercises.map((e) => e.uuid).toList(),
      );
    }

    // chooseExercises — show the picker with everything pre-selected.
    if (!context.mounted) return null;
    final selectedUuids = await ProgramPageControllerBase.selectExercises(
      context,
      title,
      exercises,
      constraints,
      localizations,
      false,
      confirmLabel: actionLabel,
      preselectAll: true,
      showSelectAllControls: true,
    );
    if (selectedUuids.isEmpty) return null;
    return ExportPlanInput(fileName: fileName, selectedUuids: selectedUuids);
  } finally {
    controller.removeListener(onTextChanged);
    controller.dispose();
    canSubmit.dispose();
  }
}

/// Default file name for the export dialog. Falls back to the localized hint
/// when the active plan's name slugifies to an empty string (e.g. all-symbol
/// names like "🚓").
String _initialFileName(Program program, AppLocalizations localizations) {
  final slug = sanitizeSlug(program.name);
  return slug.isEmpty ? localizations.fileNameHint : slug;
}

/// Lays out the inline title + action buttons on a single row. With only two
/// buttons (cancel + primary) the title plus buttons fit comfortably on a
/// phone — the title takes the remaining width and ellipsizes if necessary.
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.title, required this.buttons});

  final String title;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            style: titleStyle,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 12),
        ...List.generate(
          buttons.length,
          (i) => Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
            child: buttons[i],
          ),
        ),
      ],
    );
  }
}
