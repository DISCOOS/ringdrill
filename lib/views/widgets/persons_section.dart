import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/utils/slug.dart';

/// DESIGN-009 "Personer" section: a row per station-owned [Person] with a
/// `⋮` menu for edit/delete (ADR-0031), a "+ Ny person" action, and a home
/// picker (over the station's own [locations]) live on each row.
///
/// Presentation-only, mirroring `LocationsSection`: [persons] and the
/// mutation callbacks are owned by the caller (`StationFormScreen`), which
/// persists the working list via `Station.copyWith` on save.
///
/// Scope boundary (DESIGN-009 prompt 3): this section only adds, edits
/// non-slug fields, and plain-deletes. A person's `slug` is fixed at
/// creation; renaming it and the station-and-down reference-rewrite/delete
/// guard (including a `homeSlug` pointing at a deleted location) are
/// DESIGN-009 prompt 5 — intentionally not implemented here.
class PersonsSection extends StatelessWidget {
  const PersonsSection({
    super.key,
    required this.persons,
    required this.locations,
    required this.onAdd,
    required this.onEdit,
    required this.onHomeChanged,
    required this.onDelete,
  });

  final List<Person> persons;

  /// The station's own locations, offered in the row's home picker.
  final List<Location> locations;

  /// Called with a new, validated [Person] from the "+ Ny person" dialog.
  /// The caller appends it to its own working list.
  final ValueChanged<Person> onAdd;

  /// Called with the updated [Person] (same `slug`) after the edit dialog
  /// (name/age/gender/signalement/notes) is confirmed.
  final ValueChanged<Person> onEdit;

  /// Called with a person's `slug` and the newly picked `homeSlug` (null to
  /// clear) from the row's own picker — kept separate from [onEdit] since
  /// it fires immediately from the row, not from a dialog confirm.
  final void Function(String slug, String? homeSlug) onHomeChanged;

  /// Called with the `slug` to remove. Plain delete — no reference guard
  /// yet (prompt 5).
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final person in persons)
            _PersonRow(
              key: ValueKey(person.slug),
              person: person,
              locations: locations,
              onEdit: () => _handleEdit(context, person),
              onHomeChanged: (homeSlug) =>
                  onHomeChanged(person.slug, homeSlug),
              onDelete: () => onDelete(person.slug),
            ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _handleAdd(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    l10n.personsSectionAddAction,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAdd(BuildContext context) async {
    final created = await showDialog<Person>(
      context: context,
      builder: (dialogContext) => _PersonFormDialog(
        existingSlugs: persons.map((p) => p.slug).toSet(),
      ),
    );
    if (created != null) onAdd(created);
  }

  Future<void> _handleEdit(BuildContext context, Person person) async {
    final updated = await showDialog<Person>(
      context: context,
      builder: (dialogContext) => _PersonFormDialog(
        existingSlugs: persons.map((p) => p.slug).toSet(),
        initial: person,
      ),
    );
    if (updated != null) onEdit(updated);
  }
}

enum _PersonRowAction { edit, delete }

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    super.key,
    required this.person,
    required this.locations,
    required this.onEdit,
    required this.onHomeChanged,
    required this.onDelete,
  });

  final Person person;
  final List<Location> locations;
  final VoidCallback onEdit;
  final ValueChanged<String?> onHomeChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final identityParts = [
      if (person.age != null) '${person.age}',
      if ((person.gender ?? '').isNotEmpty) person.gender!,
      if ((person.signalement ?? '').isNotEmpty) person.signalement!,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  person.name.isEmpty ? person.slug : person.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<_PersonRowAction>(
                tooltip: '',
                onSelected: (action) => switch (action) {
                  _PersonRowAction.edit => onEdit(),
                  _PersonRowAction.delete => onDelete(),
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _PersonRowAction.edit,
                    child: Text(l10n.personsSectionEditAction),
                  ),
                  PopupMenuItem(
                    value: _PersonRowAction.delete,
                    child: Text(l10n.personsSectionDeleteAction),
                  ),
                ],
              ),
            ],
          ),
          if (identityParts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                identityParts.join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if ((person.notes ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                person.notes!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          DropdownButtonFormField<String?>(
            key: const Key('home-field'),
            initialValue: person.homeSlug,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.personsSectionHomeLabel,
              isDense: true,
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(l10n.personsSectionHomeNone),
              ),
              for (final location in locations)
                DropdownMenuItem<String?>(
                  value: location.slug,
                  child: Text(
                    location.label.isEmpty ? location.slug : location.label,
                  ),
                ),
            ],
            onChanged: onHomeChanged,
          ),
        ],
      ),
    );
  }
}

/// Shared slug/name/age/gender/signalement/notes form used by both the
/// add-person and edit-person dialogs. When [initial] is given, the slug
/// field is shown read-only (a slug rename is DESIGN-009 prompt 5, not this
/// dialog) and the result carries [initial]'s slug and `homeSlug` unchanged
/// — home is set directly on the row via its own picker, not here.
class _PersonFormDialog extends StatefulWidget {
  const _PersonFormDialog({required this.existingSlugs, this.initial});

  final Set<String> existingSlugs;
  final Person? initial;

  @override
  State<_PersonFormDialog> createState() => _PersonFormDialogState();
}

class _PersonFormDialogState extends State<_PersonFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final _ageController = TextEditingController(
    text: widget.initial?.age?.toString() ?? '',
  );
  late final _genderController = TextEditingController(
    text: widget.initial?.gender ?? '',
  );
  late final _signalementController = TextEditingController(
    text: widget.initial?.signalement ?? '',
  );
  late final _notesController = TextEditingController(
    text: widget.initial?.notes ?? '',
  );

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _signalementController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _validateAge(String? value, AppLocalizations l10n) {
    if (value == null || value.isEmpty) return null;
    final age = int.tryParse(value);
    if (age == null || age < 0 || age > 120) return l10n.ageRange;
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final gender = _genderController.text.trim();
    final signalement = _signalementController.text.trim();
    final notes = _notesController.text.trim();
    final slug =
        widget.initial?.slug ??
        generateSlug(_nameController.text.trim(), widget.existingSlugs.contains);
    Navigator.of(context).pop(
      Person(
        slug: slug,
        name: _nameController.text.trim(),
        age: _ageController.text.isEmpty
            ? null
            : int.tryParse(_ageController.text),
        gender: gender.isEmpty ? null : gender,
        signalement: signalement.isEmpty ? null : signalement,
        homeSlug: widget.initial?.homeSlug,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = _isEdit
        ? l10n.personsSectionEditAction
        : l10n.personsSectionAddAction;
    return AlertDialog(
      title: Text(title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      autofocus: true,
                      decoration: InputDecoration(labelText: l10n.roleName),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(labelText: l10n.roleAge),
                      validator: (value) => _validateAge(value, l10n),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _genderController,
                decoration: InputDecoration(labelText: l10n.roleGender),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _signalementController,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.roleSignalement,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.personsSectionNotesLabel,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(title)),
      ],
    );
  }
}
