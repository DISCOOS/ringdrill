import 'package:flutter/material.dart';

/// Labelled multi-line markdown field shared by [OptionalFieldSections] and
/// the DESIGN-008 section-navigated editor bodies, so both paths build the
/// same field the same way.
///
/// A plain [TextFormField] — no token-aware rendering. The token-aware
/// field (DESIGN-008 Stage 4) later replaces this widget's internals behind
/// the same constructor API.
///
/// [expands] makes the field fill its parent's height instead of sizing to
/// [minLines]/[maxLines] — used by a section body that gets the whole
/// screen, so it must sit inside a bounded-height ancestor (e.g. `Expanded`
/// in a `Column`).
class MarkdownSectionField extends StatelessWidget {
  const MarkdownSectionField({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.minLines = 2,
    this.maxLines = 8,
    this.expands = false,
    this.onRemove,
  });

  final TextEditingController controller;
  final String label;
  final FocusNode? focusNode;
  final int minLines;
  final int maxLines;
  final bool expands;

  /// Shows a trailing close button that calls this when pressed. Omitted
  /// (null) where removal is handled elsewhere, e.g. a section's overflow
  /// menu (ADR-0031).
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.multiline,
      minLines: expands ? null : minLines,
      maxLines: expands ? null : maxLines,
      expands: expands,
      textAlignVertical: expands ? TextAlignVertical.top : null,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        suffixIcon: onRemove == null
            ? null
            : IconButton(icon: const Icon(Icons.close), onPressed: onRemove),
      ),
    );
  }
}
