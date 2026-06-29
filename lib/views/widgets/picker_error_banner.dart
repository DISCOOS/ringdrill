import 'package:flutter/material.dart';

/// Inline error banner used by the From-File tabs in the library and
/// add-exercises dialogs.
///
/// Snackbars dispatched from inside a modal dialog land behind the
/// modal backdrop and never reach the user, so format-error and
/// import-failure messages are rendered inline above the action
/// button instead. The shape mirrors a [MaterialBanner] but is light
/// enough to drop into a [Column] without owning a scaffold slot.
class PickerErrorBanner extends StatelessWidget {
  const PickerErrorBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: colors.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: colors.onErrorContainer),
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
