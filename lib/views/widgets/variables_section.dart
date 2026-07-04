import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';

/// Slug rule for a variable's [DrillVariable.name] (ADR-0046): starts with a
/// lowercase letter, then lowercase letters/digits/underscores. Kept in
/// sync with the token-match pattern in `token_text_editing_controller.dart`
/// and `brief_renderer.dart` — this is the *authoring* constraint, those are
/// the *matching* pattern, but both describe the same name shape.
final _slugPattern = RegExp(r'^[a-z][a-z0-9_]*$');

/// The DESIGN-008 Stage 5 "Variabler" declaration section: a row per
/// declared [DrillVariable] with a `⋮` menu for rename/delete (ADR-0031 —
/// never a per-row pencil), a "+ Ny variabel" action, and the ADR-0046
/// publish-warning note.
///
/// Presentation-only, mirroring how `_TagsEditor` and `ProgramFormScreen`'s
/// `_activeSections` are owned by the parent form: [variables] and the
/// mutation callbacks are owned by the caller. Rename and delete need
/// plan-wide knowledge (every markdown field, every `variableOverrides`
/// map) this widget doesn't have — [referenceCount] and
/// [referenceDescriptions] are injected so the caller (which holds the
/// working `Program`) can answer "is this referenced, and where".
///
/// Editing a variable's *value* after creation is out of scope for this
/// stage (not in the DESIGN-008 Stage 5 prompt) — only name (rename) and
/// existence (create/delete) are editable here today.
class VariablesSection extends StatelessWidget {
  const VariablesSection({
    super.key,
    required this.variables,
    required this.onAdd,
    required this.onRename,
    required this.onDelete,
    required this.referenceCount,
    required this.referenceDescriptions,
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

  /// Total `{{var.<name>}}` occurrences plus `variableOverrides` key hits
  /// across the whole plan (`plan_variable_refs.dart`).
  final int Function(String name) referenceCount;

  /// Localized, human-readable locations for [name] — already formatted by
  /// the caller (which has an `AppLocalizations`); this widget just lists
  /// them.
  final List<String> Function(String name) referenceDescriptions;

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
            _VariableRow(
              key: ValueKey(variable.name),
              variable: variable,
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

enum _VariableRowAction { rename, delete }

class _VariableRow extends StatelessWidget {
  const _VariableRow({
    super.key,
    required this.variable,
    required this.onRename,
    required this.onDelete,
  });

  final DrillVariable variable;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              variable.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              variable.value.isEmpty ? '—' : variable.value,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          PopupMenuButton<_VariableRowAction>(
            tooltip: '',
            onSelected: (action) => switch (action) {
              _VariableRowAction.rename => onRename(),
              _VariableRowAction.delete => onDelete(),
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _VariableRowAction.rename,
                child: Text(l10n.variablesSectionRenameAction),
              ),
              PopupMenuItem(
                value: _VariableRowAction.delete,
                child: Text(l10n.variablesSectionDeleteAction),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shared name/value/hint form used by both the add-variable and (name
/// portion of the) rename flows — actually just the add dialog; rename uses
/// [_RenameDialog], a name-only variant, since renaming has its own
/// plan-wide-rewrite confirmation step the caller handles.
class _VariableFormDialog extends StatefulWidget {
  const _VariableFormDialog({required this.existingNames});

  final Set<String> existingNames;

  @override
  State<_VariableFormDialog> createState() => _VariableFormDialogState();
}

class _VariableFormDialogState extends State<_VariableFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  final _hintController = TextEditingController();

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
    Navigator.of(context).pop(
      DrillVariable(
        name: _nameController.text.trim(),
        value: _valueController.text.trim(),
        hint: _hintController.text.trim().isEmpty
            ? null
            : _hintController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.variablesSectionAddAction),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.variablesSectionNameLabel,
              ),
              validator: (value) => _validateName(value, l10n),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _valueController,
              decoration: InputDecoration(
                labelText: l10n.variablesSectionValueLabel,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hintController,
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
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.variablesSectionAddAction),
        ),
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
