import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/dialog_widgets.dart';

/// What the user chose in [showNameStepSheet].
enum NameStepAction { cancel, chooseItems, confirmAll }

/// The action plus the trimmed file name entered, returned by
/// [showNameStepSheet]. Bundling the text with the action lets the sheet
/// own (and dispose) its [TextEditingController] in its own [State]
/// instead of leaking it to the caller.
class NameStepResult {
  const NameStepResult(this.action, this.fileName);

  final NameStepAction action;
  final String fileName;
}

/// First step shared by every "name a file, then either pick specific
/// items or take everything" flow: "Last ned plan" (choose exercises,
/// `export_plan_dialog.dart`) and "Last ned alle" (choose plans,
/// `download_all_plans_dialog.dart`). Both present the same shape so
/// downloading a single plan and downloading the whole library feel
/// like the same feature:
///
///   * a file-name field pre-filled with [initialFileName],
///   * a hint line explaining what happens by default,
///   * three buttons: cancel · "VELG..." (disabled with
///     [chooseDisabledTooltip] when [hasItems] is false) · [actionLabel].
///     [title] renders next to the buttons rather than as a tall centered
///     header, on the same line when there is room.
///
/// Returns `null` if the user cancels. Leaves validating a non-empty file
/// name to the caller, same as before — this sheet only pops the raw
/// trimmed text.
Future<NameStepResult?> showNameStepSheet(
  BuildContext context, {
  required String initialFileName,
  required String fileSuffix,
  required String title,
  required String actionLabel,
  required String allIncludedHint,
  required bool hasItems,
  required String chooseDisabledTooltip,
  required AppLocalizations localizations,
}) {
  return showResponsiveSheetOrDialog<NameStepResult>(
    context,
    builder: (sheetContext) => _NameStepContent(
      localizations: localizations,
      title: title,
      actionLabel: actionLabel,
      initialFileName: initialFileName,
      fileSuffix: fileSuffix,
      allIncludedHint: allIncludedHint,
      hasItems: hasItems,
      chooseDisabledTooltip: chooseDisabledTooltip,
    ),
  );
}

class _NameStepContent extends StatefulWidget {
  const _NameStepContent({
    required this.localizations,
    required this.title,
    required this.actionLabel,
    required this.initialFileName,
    required this.fileSuffix,
    required this.allIncludedHint,
    required this.hasItems,
    required this.chooseDisabledTooltip,
  });

  final AppLocalizations localizations;
  final String title;
  final String actionLabel;
  final String initialFileName;
  final String fileSuffix;
  final String allIncludedHint;

  /// False when there is nothing to pick from (e.g. a plan with no
  /// exercises yet) — "VELG..." is disabled rather than opening an empty
  /// picker that can only ever be confirmed with zero selected.
  final bool hasItems;
  final String chooseDisabledTooltip;

  @override
  State<_NameStepContent> createState() => _NameStepContentState();
}

class _NameStepContentState extends State<_NameStepContent> {
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

  void _pop(NameStepAction action) {
    Navigator.pop(context, NameStepResult(action, _controller.text.trim()));
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
                suffixText: widget.fileSuffix,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20.0),
            Text(
              widget.allIncludedHint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24.0),
            ValueListenableBuilder<bool>(
              valueListenable: _canSubmit,
              builder: (context, enabled, _) {
                final canChooseItems = enabled && widget.hasItems;
                final chooseItemsButton = TextButton(
                  onPressed: canChooseItems
                      ? () => _pop(NameStepAction.chooseItems)
                      : null,
                  child: Text(localizations.selectExercisesAction),
                );
                return _ActionRow(
                  title: widget.title,
                  buttons: [
                    TextButton(
                      onPressed: () => _pop(NameStepAction.cancel),
                      child: Text(localizations.cancel),
                    ),
                    widget.hasItems
                        ? chooseItemsButton
                        : Tooltip(
                            message: widget.chooseDisabledTooltip,
                            child: chooseItemsButton,
                          ),
                    FilledButton(
                      onPressed: enabled
                          ? () => _pop(NameStepAction.confirmAll)
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

/// Lays out the inline title + action buttons on a single row. With only
/// two or three buttons, the title plus buttons fit comfortably on a
/// phone — the title takes the remaining width and ellipsizes if
/// necessary.
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
