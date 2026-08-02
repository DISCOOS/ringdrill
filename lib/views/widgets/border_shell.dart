import 'package:flutter/material.dart';

/// The editors' card treatment: flat, an [ColorScheme.outlineVariant] hairline, an 8px
/// radius, and content clipped to it.
///
/// No elevation anywhere in an editor — a form is a flat surface with things enclosed on
/// it, and a raised card among underlined fields reads as something that could be
/// dragged. The station editor's placement card is the reference.
class BorderShell extends StatelessWidget {
  const BorderShell({super.key, required this.child, this.color});

  final Widget child;

  /// Fill behind [child]. Null leaves it transparent, which is what a shell holding
  /// something opaque (a map, an image) wants.
  ///
  /// Set it when the shell sits on a surface that must not show through — a
  /// `Dismissible`'s reveal, for instance, would otherwise be visible *behind* the
  /// content as the card slides rather than only in the space it vacates.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      ),
    );
  }
}
