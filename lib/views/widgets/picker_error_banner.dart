import 'package:flutter/material.dart';
import 'package:ringdrill/views/widgets/inline_message.dart';

/// Inline error banner used by the From-File tabs in the library and
/// add-exercises dialogs.
///
/// Snackbars dispatched from inside a modal dialog land behind the
/// modal backdrop and never reach the user, so format-error and
/// import-failure messages are rendered inline above the action
/// button instead.
///
/// The shape lives in [InlineMessage] — this is that plus a dismiss button.
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
    return InlineMessage(
      message: message,
      trailing: IconButton(
        icon: Icon(Icons.close, color: colors.onErrorContainer),
        iconSize: 20,
        visualDensity: VisualDensity.compact,
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        onPressed: onDismiss,
      ),
    );
  }
}
