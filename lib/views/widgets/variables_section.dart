import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/services/geocoding_service.dart';
import 'package:ringdrill/views/widgets/variable_type_labels.dart';
import 'package:ringdrill/views/widgets/variable_value_field.dart';

/// Slug rule for a variable's [DrillVariable.name] (ADR-0046): starts with a
/// lowercase letter, then lowercase letters/digits/underscores. Kept in
/// sync with the token-match pattern in `token_text_editing_controller.dart`
/// and `brief_renderer.dart` — this is the *authoring* constraint, those are
/// the *matching* pattern, but both describe the same name shape.
final _slugPattern = RegExp(r'^[a-z][a-z0-9_]*$');

/// The DESIGN-008 Stage 5 "Variabler" declaration section, reshaped by
/// follow-up 11 (typed variables) to a card per declared [DrillVariable]:
/// the name, a type chip that opens the type picker, a `⋮` menu for
/// rename/edit-hint/delete (ADR-0031 — never a per-row pencil), and the
/// type-aware default-value input rendered inline ([VariableValueField]).
/// A "+ Ny variabel" action and the ADR-0046 publish-warning note frame the
/// list.
///
/// Presentation-only, mirroring how `_TagsEditor` and `ProgramFormScreen`'s
/// `_activeSections` are owned by the parent form: [variables] and the
/// mutation callbacks are owned by the caller. Rename and delete need
/// plan-wide knowledge (every markdown field, every `variableOverrides`
/// map) this widget doesn't have — [referenceCount] and
/// [referenceDescriptions] are injected so the caller (which holds the
/// working `Program`) can answer "is this referenced, and where".
class VariablesSection extends StatelessWidget {
  const VariablesSection({
    super.key,
    required this.variables,
    required this.onAdd,
    required this.onRename,
    required this.onDelete,
    required this.onUpdate,
    required this.referenceCount,
    required this.referenceDescriptions,
    this.geocodingService,
  });

  final List<DrillVariable> variables;

  /// Called with a new, validated [DrillVariable] from the "+ Ny variabel"
  /// dialog. The caller appends it to its own working list.
  final ValueChanged<DrillVariable> onAdd;

  /// Called after the rename dialog (and, if referenced, its confirmation)
  /// both succeed. The caller runs the plan-wide rewrite
  /// (`renameVariable`) and refreshes any live token controllers.
  final void Function(String oldName, String newName) onRename;

  /// Called only when [referenceCount] is zero for this name — the caller
  /// removes it from its working list. Never called while referenced;
  /// this widget shows the blocked dialog itself in that case.
  final ValueChanged<String> onDelete;

  /// Called with the updated [DrillVariable] (same `name`; new value,
  /// location, type or hint) on every inline edit — the type-aware value
  /// field, the type picker and the hint dialog all flow through here. The
  /// caller replaces the matching entry in its working list, which
  /// refreshes any live token controllers through `PlanScope`.
  final ValueChanged<DrillVariable> onUpdate;

  /// Total `{{var.<name>}}` occurrences plus `variableOverrides` key hits
  /// across the whole plan (`plan_variable_refs.dart`).
  final int Function(String name) referenceCount;

  /// Localized, human-readable locations for [name] — already formatted by
  /// the caller (which has an `AppLocalizations`); this widget just lists
  /// them.
  final List<String> Function(String name) referenceDescriptions;

  /// Geocoder handed through to the `location`-typed value input; tests
  /// inject a fake so no test hits the network.
  final GeocodingService? geocodingService;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PublishNote(text: l10n.variablesSectionPublishNote),
          const SizedBox(height: 12),
          for (final variable in variables)
            _VariableCard(
              key: ValueKey(variable.name),
              variable: variable,
              geocodingService: geocodingService,
              onUpdate: onUpdate,
              onPickType: () => _handlePickType(context, l10n, variable),
              onEditHint: () => _handleEditHint(context, variable),
              onRename: () => _handleRename(context, l10n, variable),
              onDelete: () => _handleDelete(context, l10n, variable),
            ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _handleAdd(context, l10n),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    l10n.variablesSectionAddAction,
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

  Future<void> _handleAdd(BuildContext context, AppLocalizations l10n) async {
    final created = await showDialog<DrillVariable>(
      context: context,
      builder: (dialogContext) => _VariableFormDialog(
        existingNames: variables.map((v) => v.name).toSet(),
      ),
    );
    if (created != null) onAdd(created);
  }

  Future<void> _handlePickType(
    BuildContext context,
    AppLocalizations l10n,
    DrillVariable variable,
  ) async {
    final picked = await showDialog<VariableType>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.variableTypePickerTitle(variable.name)),
        children: [
          for (final type in VariableType.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(type),
              child: Row(
                children: [
                  Icon(type.icon, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(type.label(l10n))),
                  if (type == variable.type)
                    const Icon(Icons.check, size: 18)
                  else
                    Text(
                      type.name,
                      style: Theme.of(dialogContext).textTheme.bodySmall
                          ?.copyWith(
                            fontFamily: 'monospace',
                            color: Theme.of(
                              dialogContext,
                            ).colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked == null || picked == variable.type) return;
    // The existing value/location is deliberately kept: an incompatible
    // value re-validates against the new type and surfaces as invalid
    // (blocking save) rather than being silently dropped (DESIGN-008
    // follow-up 11).
    onUpdate(variable.copyWith(type: picked));
  }

  Future<void> _handleEditHint(
    BuildContext context,
    DrillVariable variable,
  ) async {
    final updated = await showDialog<DrillVariable>(
      context: context,
      builder: (dialogContext) => _VariableFormDialog(
        existingNames: variables.map((v) => v.name).toSet(),
        initial: variable,
      ),
    );
    if (updated != null) onUpdate(updated);
  }

  Future<void> _handleRename(
    BuildContext context,
    AppLocalizations l10n,
    DrillVariable variable,
  ) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _RenameDialog(
        currentName: variable.name,
        existingNames: variables
            .where((v) => v.name != variable.name)
            .map((v) => v.name)
            .toSet(),
      ),
    );
    if (newName == null || newName == variable.name || !context.mounted) {
      return;
    }

    final count = referenceCount(variable.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.variablesSectionRenameAction),
        content: Text(l10n.variablesSectionRenameConfirmMessage(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.variablesSectionRenameAction),
          ),
        ],
      ),
    );
    if (confirmed == true) onRename(variable.name, newName);
  }

  Future<void> _handleDelete(
    BuildContext context,
    AppLocalizations l10n,
    DrillVariable variable,
  ) async {
    final count = referenceCount(variable.name);
    if (count == 0) {
      onDelete(variable.name);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.variablesSectionDeleteBlockedTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.variablesSectionDeleteBlockedMessage(variable.name)),
              const SizedBox(height: 8),
              for (final location in referenceDescriptions(variable.name))
                Text('•  $location'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }
}

class _PublishNote extends StatelessWidget {
  const _PublishNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Amber, matching the mockup's "Publiseres med planen..." note — the
    // theme has no dedicated warning color role, so this uses a fixed
    // amber tint the same way TokenTextEditingController's amber
    // (declared-but-empty) chip does.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.amber.shade900),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.amber.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _VariableCardAction { editHint, rename, delete }

/// One declaration card (DESIGN-008 follow-up 11, `typed-variables.html`):
/// name + type chip + `⋮` on top, the type-aware default-value input below,
/// and the hint (when set) as a muted caption in between.
class _VariableCard extends StatelessWidget {
  const _VariableCard({
    super.key,
    required this.variable,
    required this.onUpdate,
    required this.onPickType,
    required this.onEditHint,
    required this.onRename,
    required this.onDelete,
    this.geocodingService,
  });

  final DrillVariable variable;
  final ValueChanged<DrillVariable> onUpdate;
  final VoidCallback onPickType;
  final VoidCallback onEditHint;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final GeocodingService? geocodingService;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      variable.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _TypeChip(type: variable.type, onTap: onPickType),
                  PopupMenuButton<_VariableCardAction>(
                    tooltip: '',
                    onSelected: (action) => switch (action) {
                      _VariableCardAction.editHint => onEditHint(),
                      _VariableCardAction.rename => onRename(),
                      _VariableCardAction.delete => onDelete(),
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _VariableCardAction.editHint,
                        child: Text(l10n.variablesSectionEditHintAction),
                      ),
                      PopupMenuItem(
                        value: _VariableCardAction.rename,
                        child: Text(l10n.variablesSectionRenameAction),
                      ),
                      PopupMenuItem(
                        value: _VariableCardAction.delete,
                        child: Text(l10n.variablesSectionDeleteAction),
                      ),
                    ],
                  ),
                ],
              ),
              if (variable.hint != null && variable.hint!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    variable.hint!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: VariableValueField(
                  // Remounts on a type change so the input switches shape
                  // and re-validates the kept value against the new type.
                  key: ValueKey('${variable.name}:${variable.type.name}'),
                  type: variable.type,
                  value: variable.value,
                  location: variable.location,
                  hintText: l10n.variablesSectionValueLabel,
                  geocodingService: geocodingService,
                  // `location` stays null on scalar edits, which must not
                  // clear a location value kept from before a type change
                  // (nothing is silently dropped).
                  onChanged: (value, location) => onUpdate(
                    variable.copyWith(
                      value: value,
                      location: location ?? variable.location,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The pill-shaped type chip on a declaration card — label + chevron,
/// accent-tinted, opening the type picker.
class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type, required this.onTap});

  final VariableType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              type.label(l10n),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              size: 14,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared dialog behind "+ Ny variabel" and "Rediger hint". Creation
/// ([initial] null) takes name/value/hint and returns a new string-typed
/// [DrillVariable] — the type is changed afterward on the card's type chip
/// (DESIGN-008 follow-up 11: created variables default to `string`).
/// With [initial] this is the hint-editing dialog: name is shown read-only
/// and the value is not shown at all — it is edited inline on the card by
/// the type-aware field, never here.
/// Rename itself uses [_RenameDialog], a name-only variant, since renaming
/// has its own plan-wide-rewrite confirmation step the caller handles.
class _VariableFormDialog extends StatefulWidget {
  const _VariableFormDialog({required this.existingNames, this.initial});

  final Set<String> existingNames;
  final DrillVariable? initial;

  @override
  State<_VariableFormDialog> createState() => _VariableFormDialogState();
}

class _VariableFormDialogState extends State<_VariableFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  final _valueController = TextEditingController();
  late final _hintController = TextEditingController(
    text: widget.initial?.hint ?? '',
  );

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  String? _validateName(String? value, AppLocalizations l10n) {
    final name = value?.trim() ?? '';
    if (!_slugPattern.hasMatch(name)) {
      return l10n.variablesSectionInvalidSlugError;
    }
    if (widget.existingNames.contains(name)) {
      return l10n.variablesSectionDuplicateNameError;
    }
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final hint = _hintController.text.trim();
    Navigator.of(context).pop(
      _isEdit
          ? widget.initial!.copyWith(hint: hint.isEmpty ? null : hint)
          : DrillVariable(
              name: _nameController.text.trim(),
              value: _valueController.text.trim(),
              hint: hint.isEmpty ? null : hint,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = _isEdit
        ? l10n.variablesSectionEditHintAction
        : l10n.variablesSectionAddAction;
    return AlertDialog(
      title: Text(title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: !_isEdit,
              enabled: !_isEdit,
              decoration: InputDecoration(
                labelText: l10n.variablesSectionNameLabel,
              ),
              validator: _isEdit ? null : (value) => _validateName(value, l10n),
            ),
            if (!_isEdit) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _valueController,
                decoration: InputDecoration(
                  labelText: l10n.variablesSectionValueLabel,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _hintController,
              autofocus: _isEdit,
              decoration: InputDecoration(
                labelText: l10n.variablesSectionHintLabel,
              ),
            ),
          ],
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

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.currentName, required this.existingNames});

  final String currentName;
  final Set<String> existingNames;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.currentName);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _validateName(String? value, AppLocalizations l10n) {
    final name = value?.trim() ?? '';
    if (!_slugPattern.hasMatch(name)) {
      return l10n.variablesSectionInvalidSlugError;
    }
    if (widget.existingNames.contains(name)) {
      return l10n.variablesSectionDuplicateNameError;
    }
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_nameController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.variablesSectionRenameAction),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.variablesSectionNameLabel),
          validator: (value) => _validateName(value, l10n),
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.variablesSectionRenameAction),
        ),
      ],
    );
  }
}
