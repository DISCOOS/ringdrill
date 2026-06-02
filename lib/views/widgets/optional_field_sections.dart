import 'package:flutter/material.dart';

/// Describes one optional, addable text section in an entity form.
///
/// The parent form owns the [controller] (and any focus node), so it can both
/// seed the widget with existing content and read the values back out at save
/// time. [OptionalFieldSections] only renders.
class OptionalFieldSection<T> {
  const OptionalFieldSection({
    required this.id,
    required this.label,
    required this.controller,
    this.focusNode,
  });

  final T id;
  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
}

/// Renders the addable optional-section pattern shared by the entity forms
/// (Program, Exercise, Station, RolePlay).
///
/// Active sections render as a labelled, multi-line [TextFormField] with a
/// remove affordance. Sections not yet added render below as a wrap of
/// `Icons.add` outlined buttons. The parent owns the controllers and the
/// active set so it can build/save the entity, mirroring how
/// `RolePlayFormScreen` ships the pattern.
class OptionalFieldSections<T> extends StatelessWidget {
  const OptionalFieldSections({
    super.key,
    required this.sections,
    required this.activeIds,
    required this.onAdd,
    required this.onRemove,
    this.minLines = 2,
    this.maxLines = 8,
    this.spacing = 12,
    this.addButtonSpacing = 8,
  });

  final List<OptionalFieldSection<T>> sections;
  final Set<T> activeIds;
  final ValueChanged<T> onAdd;
  final ValueChanged<T> onRemove;
  final int minLines;
  final int maxLines;
  final double spacing;
  final double addButtonSpacing;

  @override
  Widget build(BuildContext context) {
    final missing = sections.where((s) => !activeIds.contains(s.id)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in sections)
          if (activeIds.contains(section.id)) ...[
            TextFormField(
              focusNode: section.focusNode,
              controller: section.controller,
              keyboardType: TextInputType.multiline,
              minLines: minLines,
              maxLines: maxLines,
              decoration: InputDecoration(
                labelText: section.label,
                alignLabelWithHint: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => onRemove(section.id),
                ),
              ),
            ),
            SizedBox(height: spacing),
          ],
        if (missing.isNotEmpty)
          Wrap(
            spacing: addButtonSpacing,
            runSpacing: 4,
            children: [
              for (final section in missing)
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(section.label),
                  onPressed: () => onAdd(section.id),
                ),
            ],
          ),
      ],
    );
  }
}
