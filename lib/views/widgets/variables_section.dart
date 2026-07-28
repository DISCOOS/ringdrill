import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/services/geocoding_service.dart';
import 'package:ringdrill/utils/variable_values.dart';
import 'package:ringdrill/views/widgets/variable_type_labels.dart';
import 'package:ringdrill/views/widgets/variable_value_field.dart';

/// Slug rule for a variable's [DrillVariable.name] (ADR-0046): starts with a
/// lowercase letter, then lowercase letters/digits/underscores. Kept in
/// sync with the token-match pattern in `token_text_editing_controller.dart`
/// and `brief_renderer.dart` — this is the *authoring* constraint, those are
/// the *matching* pattern, but both describe the same name shape.
final _slugPattern = RegExp(r'^[a-z][a-z0-9_]*$');

/// The DESIGN-008 Stage 5 "Variabler" declaration section (reshaped by
/// follow-up 12 into a collapsible card per declared [DrillVariable],
/// mirroring `RolePlayFormScreen`'s "Identitet" card): a collapsed summary
/// (type icon, name, formatted value or an empty placeholder) and a
/// "Tilpass" disclosure bar that expands to the type picker plus the
/// inline value and hint fields — see [_VariableCard]. The ADR-0046
/// publish-warning note sits above the (searchable) card list; a bottom
/// search + "+ Ny variabel" bar (name + hint only; the type and value are
/// set afterward on the card itself) matches `PersonsSection`/
/// `LocationsSection`'s own bar.
///
/// Presentation-only, mirroring how `_TagsEditor` and `PlanFormScreen`'s
/// `_activeSections` are owned by the parent form: [variables] and the
/// mutation callbacks are owned by the caller. Rename and delete need
/// plan-wide knowledge (every markdown field, every `variableOverrides`
/// map) this widget doesn't have — [referenceCount] and
/// [referenceDescriptions] are injected so the caller (which holds the
/// working `Plan`) can answer "is this referenced, and where".
class VariablesSection extends StatefulWidget {
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
  /// removes it from its working list. Never called while referenced; the
  /// referenced-guard dialog is shown for both the context-menu delete and
  /// the swipe-to-dismiss gesture.
  final ValueChanged<String> onDelete;

  /// Called with the updated [DrillVariable] (same `name`; new value,
  /// location, type or hint) on every inline edit in the expanded panel —
  /// the type picker and the type-aware value/hint fields all flow through
  /// here. The caller replaces the matching entry in its working list,
  /// which refreshes any live token controllers through `PlanScope`.
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
  State<VariablesSection> createState() => _VariablesSectionState();
}

class _VariablesSectionState extends State<VariablesSection> {
  /// The one variable card allowed to be expanded at a time (DESIGN-008
  /// follow-up 12) — expanding another collapses this one, mirroring how
  /// `SectionNavigatedForm`'s own section switcher never shows two sections
  /// at once. Null when every card is collapsed.
  String? _expandedName;

  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleExpanded(String name) {
    setState(() => _expandedName = _expandedName == name ? null : name);
  }

  /// Matches on name and hint — the same two-field search Persons/Locations
  /// run against their own primary identifier plus descriptive caption.
  List<DrillVariable> get _visibleVariables {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.variables;
    return widget.variables
        .where(
          (v) =>
              v.name.toLowerCase().contains(query) ||
              (v.hint ?? '').toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visible = _visibleVariables;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _PublishNote(text: l10n.variablesSectionPublishNote),
                const SizedBox(height: 12),
                for (final variable in visible)
                  _VariableCard(
                    key: ValueKey(variable.name),
                    variable: variable,
                    geocodingService: widget.geocodingService,
                    onUpdate: widget.onUpdate,
                    expanded: _expandedName == variable.name,
                    onToggleExpanded: () => _toggleExpanded(variable.name),
                    onRename: () => _handleRename(context, l10n, variable),
                    confirmDelete: () => _handleDelete(context, l10n, variable),
                  ),
              ],
            ),
          ),
          _SearchAddRow(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            searchHint: l10n.variablesSectionSearchHint,
            addLabel: l10n.variablesSectionAddAction,
            onAdd: () => _handleAdd(context, l10n),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAdd(BuildContext context, AppLocalizations l10n) async {
    final created = await showDialog<DrillVariable>(
      context: context,
      builder: (dialogContext) => _AddVariableDialog(
        existingNames: widget.variables.map((v) => v.name).toSet(),
      ),
    );
    if (created != null) widget.onAdd(created);
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
        existingNames: widget.variables
            .where((v) => v.name != variable.name)
            .map((v) => v.name)
            .toSet(),
      ),
    );
    if (newName == null || newName == variable.name || !context.mounted) {
      return;
    }

    final count = widget.referenceCount(variable.name);
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
    if (confirmed == true) widget.onRename(variable.name, newName);
  }

  /// Shared by the context-menu "Delete" action and the swipe-to-dismiss
  /// gesture (DESIGN-008 follow-up 12): an unreferenced variable is removed
  /// immediately (`true`, so `Dismissible` completes the swipe); a
  /// referenced one shows the blocked dialog and is never removed (`false`,
  /// so a swipe snaps back).
  Future<bool> _handleDelete(
    BuildContext context,
    AppLocalizations l10n,
    DrillVariable variable,
  ) async {
    final count = widget.referenceCount(variable.name);
    if (count == 0) {
      widget.onDelete(variable.name);
      return true;
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
              for (final location in widget.referenceDescriptions(
                variable.name,
              ))
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
    return false;
  }
}

/// Card-based bottom row with a search field and an add-action button,
/// matching the map search field's no-border Card idiom (DESIGN-009
/// follow-up 3c) and the same bar `PersonsSection`/`LocationsSection` use.
/// Duplicated rather than shared — those two are presentation-only leaf
/// widgets with no shared library; a shared helper would need its own file
/// and import cycle. Three similar lines beats a premature abstraction for
/// three callers, same reasoning as the persons/locations pair.
class _SearchAddRow extends StatelessWidget {
  const _SearchAddRow({
    required this.controller,
    required this.onChanged,
    required this.searchHint,
    required this.addLabel,
    required this.onAdd,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String searchHint;
  final String addLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  hintText: searchHint,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const VerticalDivider(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(addLabel),
            ),
          ],
        ),
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

enum _VariableCardAction { rename, delete }

/// One declaration card (DESIGN-008 follow-up 12), mirroring
/// `RolePlayFormScreen`'s "Identitet" card: a collapsed summary (a type-icon
/// avatar, the name, and the formatted value or an empty placeholder), and
/// a "Tilpass" disclosure bar that expands to a `⋮` menu (rename/delete —
/// ADR-0031, never a per-row pencil) in the header plus the inline
/// type-aware value field (with its type dropdown alongside) and the hint
/// field. Swiping the card also deletes it, through the same
/// referenced-guard [confirmDelete] the `⋮` menu uses.
///
/// [expanded] and [onToggleExpanded] are owned by the caller
/// ([VariablesSection]), not this card, so only one card is ever expanded
/// at a time — expanding one collapses whichever other was open.
class _VariableCard extends StatefulWidget {
  const _VariableCard({
    super.key,
    required this.variable,
    required this.onUpdate,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onRename,
    required this.confirmDelete,
    this.geocodingService,
  });

  final DrillVariable variable;
  final ValueChanged<DrillVariable> onUpdate;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onRename;

  /// Returns `true` once the variable is actually gone (immediate for an
  /// unreferenced one) — Dismissible's contract for whether to complete or
  /// cancel the swipe animation.
  final Future<bool> Function() confirmDelete;
  final GeocodingService? geocodingService;

  @override
  State<_VariableCard> createState() => _VariableCardState();
}

class _VariableCardState extends State<_VariableCard> {
  /// Owned here, not by [VariableValueField]: the hint is a plain string
  /// field with no canonical/typed encoding, edited only from this card, so
  /// there is no "outside change" to resync against — unlike
  /// [VariableValueField]'s own value/location, which a type change can
  /// also touch.
  late final _hintController = TextEditingController(
    text: widget.variable.hint ?? '',
  );

  @override
  void dispose() {
    _hintController.dispose();
    super.dispose();
  }

  void _updateHint(String value) {
    final trimmed = value.trim();
    widget.onUpdate(
      widget.variable.copyWith(hint: trimmed.isEmpty ? null : trimmed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final variable = widget.variable;
    final formattedValue = formatVariableValue(
      variable,
      variableFormatOf(l10n),
    );
    final panelSurfaceColor = theme.colorScheme.surfaceContainerHighest
        .withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        // Distinct from the outer `_VariableCard`'s own `ValueKey(name)`
        // (set by the caller, for list reconciliation) so `find.byKey` in
        // tests can target one or the other unambiguously.
        key: ValueKey('dismiss-${variable.name}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => widget.confirmDelete(),
        background: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.error,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Icon(Icons.delete, color: theme.colorScheme.onError),
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        variable.type.icon,
                        size: 18,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            variable.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            formattedValue.isEmpty
                                ? l10n.variablesSectionNoValuePlaceholder
                                : formattedValue,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Rename/delete sit in the header, not gated behind the
                    // expanded panel's fields — but only once "Tilpass" is
                    // open, so the collapsed row stays a plain summary.
                    // Explicit Icons.more_vert rather than
                    // PopupMenuButton's platform-adaptive default, which
                    // renders horizontal dots on iOS/macOS-style platforms.
                    if (widget.expanded)
                      PopupMenuButton<_VariableCardAction>(
                        tooltip: '',
                        icon: const Icon(Icons.more_vert),
                        onSelected: (action) => switch (action) {
                          _VariableCardAction.rename => widget.onRename(),
                          _VariableCardAction.delete => widget.confirmDelete(),
                        },
                        itemBuilder: (context) => [
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
              ),
              InkWell(
                onTap: widget.onToggleExpanded,
                child: Container(
                  color: panelSurfaceColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tune,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const Expanded(child: SizedBox.shrink()),
                      Text(
                        l10n.variablesSectionCustomizeAction,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        widget.expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.expanded)
                Container(
                  color: panelSurfaceColor,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: VariableValueField(
                              // Remounts on a type change so the input
                              // switches shape and re-validates the kept
                              // value against the new type.
                              key: ValueKey(
                                '${variable.name}:${variable.type.name}',
                              ),
                              type: variable.type,
                              value: variable.value,
                              location: variable.location,
                              hintText: l10n.variablesSectionValueLabel,
                              geocodingService: widget.geocodingService,
                              // `location` stays null on scalar edits,
                              // which must not clear a location value kept
                              // from before a type change (nothing is
                              // silently dropped).
                              onChanged: (value, location) => widget.onUpdate(
                                variable.copyWith(
                                  value: value,
                                  location: location ?? variable.location,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _TypeDropdown(
                            type: variable.type,
                            onChanged: (picked) {
                              if (picked == variable.type) return;
                              // The existing value/location is deliberately
                              // kept: an incompatible value re-validates
                              // against the new type and surfaces as
                              // invalid (blocking save) rather than being
                              // silently dropped (DESIGN-008 follow-up 11).
                              widget.onUpdate(variable.copyWith(type: picked));
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _hintController,
                        decoration: InputDecoration(
                          labelText: l10n.variablesSectionHintLabel,
                        ),
                        onChanged: _updateHint,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The type selector beside a declaration card's value field — a standard
/// [DropdownButtonFormField], sized and aligned to match the value field's
/// own height (a bespoke pill button previously sat noticeably smaller and
/// misaligned against it). [IntrinsicWidth] keeps it sized to its content
/// in the surrounding `Row`, matching `plan_form_screen.dart`'s
/// `_LanguagePicker` — the same pattern already used for a compact,
/// content-sized dropdown beside another field.
class _TypeDropdown extends StatelessWidget {
  const _TypeDropdown({required this.type, required this.onChanged});

  final VariableType type;
  final ValueChanged<VariableType> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return IntrinsicWidth(
      child: DropdownButtonFormField<VariableType>(
        initialValue: type,
        items: [
          for (final t in VariableType.values)
            DropdownMenuItem(
              value: t,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(t.icon, size: 18),
                  const SizedBox(width: 8),
                  Text(t.label(l10n)),
                ],
              ),
            ),
        ],
        onChanged: (picked) {
          if (picked != null) onChanged(picked);
        },
      ),
    );
  }
}

/// The "+ Ny variabel" creation dialog (DESIGN-008 follow-up 12): name and
/// hint only — the type stays `string` and the value stays empty, both set
/// afterward on the declaration card itself (its "Tilpass" panel).
/// Rename uses [_RenameDialog], a name-only variant with its own
/// plan-wide-rewrite confirmation step the caller handles.
class _AddVariableDialog extends StatefulWidget {
  const _AddVariableDialog({required this.existingNames});

  final Set<String> existingNames;

  @override
  State<_AddVariableDialog> createState() => _AddVariableDialogState();
}

class _AddVariableDialogState extends State<_AddVariableDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hintController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
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
      DrillVariable(
        name: _nameController.text.trim(),
        hint: hint.isEmpty ? null : hint,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = l10n.variablesSectionAddAction;
    return AlertDialog(
      title: Text(title),
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
          decoration: InputDecoration(
            labelText: l10n.variablesSectionNameLabel,
          ),
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
