import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';

/// DESIGN-008 "Variabler" **override** section shape (as opposed to
/// [VariablesSection]'s **declaration** shape on `Program`): one row per
/// declared plan variable showing its parent-scope [inherited] value
/// (dimmed) and a local-value field backed by [overrides]. An empty local
/// field means "inherit" (the name is absent from [overrides]); typing a
/// value sets the override; clearing it reverts to inherit. No
/// add/rename/delete — a variable's identity is only ever declared on
/// `Program` (ADR-0046); this table can only override an existing value.
///
/// Presentation-only, mirroring `VariablesSection`: [variables], [inherited]
/// and [overrides] are owned by the caller, and so is [onChanged]. The
/// caller also computes [inherited] — the parent scope's effective value —
/// since that needs the whole `Program` (`effectivePlanVariables`), which
/// this widget does not have; an `Exercise` editor's inherited value is
/// simply the program's declared default (no scope between program and
/// exercise), while a `Station` editor's (follow-up 07) is the *exercise's*
/// effective value, cascading through the exercise's own overrides.
class VariableOverridesSection extends StatefulWidget {
  const VariableOverridesSection({
    super.key,
    required this.variables,
    required this.inherited,
    required this.overrides,
    required this.onChanged,
  });

  /// The plan's declared variables, read-only here.
  final List<DrillVariable> variables;

  /// Parent-scope effective value per variable name — what a row resolves
  /// to with no local override.
  final Map<String, String> inherited;

  /// This entity's current local overrides. A name absent from this map
  /// inherits; a name present in it overrides the parent-scope value.
  final Map<String, String> overrides;

  /// Called with the whole updated overrides map whenever a row's local
  /// value changes.
  final ValueChanged<Map<String, String>> onChanged;

  @override
  State<VariableOverridesSection> createState() =>
      _VariableOverridesSectionState();
}

class _VariableOverridesSectionState extends State<VariableOverridesSection> {
  // The variable list is read-only in this editor (no create/rename/delete
  // reaches it), so building the controller map once — keyed by name, seeded
  // from the working overrides — is safe: it never needs to grow, shrink or
  // re-seed for the lifetime of this widget.
  late final Map<String, TextEditingController> _controllers = {
    for (final v in widget.variables)
      v.name: TextEditingController(text: widget.overrides[v.name] ?? ''),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _handleChanged(String name, String value) {
    final trimmed = value.trim();
    final updated = {...widget.overrides};
    if (trimmed.isEmpty) {
      updated.remove(name);
    } else {
      updated[name] = trimmed;
    }
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.variables.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.variableOverridesSectionEmptyState,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final variable in widget.variables)
            _OverrideRow(
              key: ValueKey(variable.name),
              name: variable.name,
              inheritedValue: widget.inherited[variable.name] ?? '',
              controller: _controllers[variable.name]!,
              onChanged: (value) => _handleChanged(variable.name, value),
            ),
        ],
      ),
    );
  }
}

class _OverrideRow extends StatelessWidget {
  const _OverrideRow({
    super.key,
    required this.name,
    required this.inheritedValue,
    required this.controller,
    required this.onChanged,
  });

  final String name;
  final String inheritedValue;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.variableOverridesSectionInheritedValueLabel(
                    inheritedValue.isEmpty ? '—' : inheritedValue,
                  ),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: l10n.variableOverridesSectionLocalValueLabel,
              isDense: true,
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
