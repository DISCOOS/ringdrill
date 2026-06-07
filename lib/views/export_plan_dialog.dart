import 'package:flutter/material.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
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
  required AppLocalizations localizations,
  required String title,
  required String actionLabel,
}) async {
  final initialFileName = _initialFileName(program, localizations);
  // The file-name controller is owned by [_ExportSheetContent]'s State, not
  // by this function. Disposing a locally-created controller in a `finally`
  // here tore it down while the sheet's TextField was still rebuilding during
  // the exit transition, throwing "used after being disposed". The sheet now
  // pops with both the chosen action and the trimmed file name so the
  // controller never has to outlive the sheet.
  final result = await showResponsiveSheetOrDialog<_ExportSheetResult>(
    context,
    builder: (sheetContext) => _ExportSheetContent(
      localizations: localizations,
      title: title,
      actionLabel: actionLabel,
      initialFileName: initialFileName,
    ),
  );

  if (result == null || result.action == _ExportSheetAction.cancel) return null;

  final fileName = result.fileName;
  if (fileName.isEmpty) return null;

  if (result.action == _ExportSheetAction.exportAll) {
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
    localizations,
    confirmLabel: actionLabel,
    preselectAll: true,
    showSelectAllControls: true,
  );
  if (selectedUuids.isEmpty) return null;
  return ExportPlanInput(fileName: fileName, selectedUuids: selectedUuids);
}

/// The action plus the trimmed file name entered, returned by the export
/// sheet. Bundling the text with the action lets the sheet own (and dispose)
/// its [TextEditingController] in its own [State] instead of leaking it to the
/// caller.
class _ExportSheetResult {
  const _ExportSheetResult(this.action, this.fileName);

  final _ExportSheetAction action;
  final String fileName;
}

/// Stateful body of the export sheet. Owns the file-name controller and the
/// "can submit" notifier so both are disposed only when the sheet route leaves
/// the tree — after the exit transition, never mid-animation.
class _ExportSheetContent extends StatefulWidget {
  const _ExportSheetContent({
    required this.localizations,
    required this.title,
    required this.actionLabel,
    required this.initialFileName,
  });

  final AppLocalizations localizations;
  final String title;
  final String actionLabel;
  final String initialFileName;

  @override
  State<_ExportSheetContent> createState() => _ExportSheetContentState();
}

class _ExportSheetContentState extends State<_ExportSheetContent> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialFileName,
  );
  late final ValueNotifier<bool> _canSubmit = ValueNotifier<bool>(
    widget.initialFileName.trim().isNotEmpty,
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    _canSubmit.value = _controller.text.trim().isNotEmpty;
  }

  void _pop(_ExportSheetAction action) {
    Navigator.pop(
      context,
      _ExportSheetResult(action, _controller.text.trim()),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _canSubmit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = widget.localizations;
    return Padding(
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 8.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8.0),
            TextField(
              controller: _controller,
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24.0),
            ValueListenableBuilder<bool>(
              valueListenable: _canSubmit,
              builder: (context, enabled, _) {
                return _ActionRow(
                  title: widget.title,
                  buttons: [
                    TextButton(
                      onPressed: () => _pop(_ExportSheetAction.cancel),
                      child: Text(localizations.cancel),
                    ),
                    TextButton(
                      onPressed: enabled
                          ? () => _pop(_ExportSheetAction.chooseExercises)
                          : null,
                      child: Text(localizations.selectExercisesAction),
                    ),
                    FilledButton(
                      onPressed: enabled
                          ? () => _pop(_ExportSheetAction.exportAll)
                          : null,
                      child: Text(widget.actionLabel),
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
