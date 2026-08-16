import 'package:flutter/material.dart';

/// How an [InlineMessage] reads: something went wrong, or something is worth
/// knowing.
///
/// Two tones and no more. A third ("warning") sounds useful and is not: the
/// only question a reader has is whether they must act, and anything that is
/// not an error is context they may act on. Adding a middle makes every author
/// guess which side a given sentence falls on.
enum MessageTone { error, info }

/// A message with an icon, sized to sit in a [Column] rather than own a
/// scaffold slot.
///
/// The icon is the point. A sentence in red is a colour, and colour alone is
/// not available to everyone reading it — a symbol says "this is a problem"
/// without depending on hue, and it does the same job for anyone skimming.
///
/// [PickerErrorBanner] is this with a dismiss button; it delegates here rather
/// than keeping its own copy of the shape.
class InlineMessage extends StatelessWidget {
  const InlineMessage({
    super.key,
    required this.message,
    this.tone = MessageTone.error,
    this.trailing,
  });

  final String message;
  final MessageTone tone;

  /// An action belonging to the message — the picker's dismiss button. Left
  /// null everywhere the message simply goes away when the state that caused
  /// it does.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isError = tone == MessageTone.error;

    final background = isError
        ? colors.errorContainer
        : colors.surfaceContainerHighest;
    final foreground = isError
        ? colors.onErrorContainer
        : colors.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.fromLTRB(12, 8, trailing == null ? 12 : 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            color: foreground,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
