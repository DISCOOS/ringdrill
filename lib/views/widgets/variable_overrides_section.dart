import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/services/geocoding_service.dart';
import 'package:ringdrill/utils/variable_values.dart';
import 'package:ringdrill/views/widgets/variable_type_labels.dart';
import 'package:ringdrill/views/widgets/variable_value_field.dart';

/// DESIGN-008 "Variabler" **override** section shape (as opposed to
/// [VariablesSection]'s **declaration** shape on `Program`), reshaped by
/// follow-up 11 (`variable-overrides.html`): a card per declared plan
/// variable with the name, the parent-scope default in parentheses after it
/// — formatted for the variable's type (a time as `12:00`, a location as
/// its UTM) — and the type-aware local-value input below, backed by
/// [overrides]. An empty local value means "inherit" (the name is absent
/// from [overrides]); setting one overrides for this subtree; the
/// "Tilbakestill" action clears it back to inherit. No add/rename/delete —
/// a variable's identity (and its type) is only ever declared on `Program`
/// (ADR-0046); this table can only override an existing value.
///
/// Presentation-only, mirroring `VariablesSection`: [variables], [inherited]
/// and [overrides] are owned by the caller, and so is [onChanged]. The
/// caller also computes [inherited] — the parent scope's effective value —
/// since that needs the whole `Program` (`effectivePlanVariables`), which
/// this widget does not have; an `Exercise` editor's inherited value is
/// simply the program's declared default (no scope between program and
/// exercise), while a `Station` editor's (follow-up 07) is the *exercise's*
/// effective value, cascading through the exercise's own overrides.
class VariableOverridesSection extends StatelessWidget {
  const VariableOverridesSection({
    super.key,
    required this.variables,
    required this.inherited,
    required this.overrides,
    required this.onChanged,
    this.geocodingService,
  });

  /// The plan's declared variables, read-only here. The declared [type]
  /// drives each card's input and the formatting of its default.
  final List<DrillVariable> variables;

  /// Parent-scope effective value per variable name, in the type's
  /// canonical string encoding (`canonicalVariableValue` /
  /// `encodeLocationValue`) — what a card resolves to with no local
  /// override.
  final Map<String, String> inherited;

  /// This entity's current local overrides. A name absent from this map
  /// inherits; a name present in it overrides the parent-scope value.
  final Map<String, String> overrides;

  /// Called with the whole updated overrides map whenever a card's local
  /// value changes.
  final ValueChanged<Map<String, String>> onChanged;

  /// Geocoder handed through to `location`-typed value inputs; tests
  /// inject a fake so no test hits the network.
  final GeocodingService? geocodingService;

  void _handleChanged(String name, String encoded) {
    final updated = {...overrides};
    if (encoded.trim().isEmpty) {
      updated.remove(name);
    } else {
      updated[name] = encoded;
    }
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (variables.isEmpty) {
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
          for (final variable in variables)
            _OverrideCard(
              key: ValueKey(variable.name),
              variable: variable,
              inheritedValue: inherited[variable.name] ?? '',
              overrideValue: overrides[variable.name],
              geocodingService: geocodingService,
              onChanged: (encoded) => _handleChanged(variable.name, encoded),
            ),
        ],
      ),
    );
  }
}

class _OverrideCard extends StatelessWidget {
  const _OverrideCard({
    super.key,
    required this.variable,
    required this.inheritedValue,
    required this.overrideValue,
    required this.onChanged,
    this.geocodingService,
  });

  final DrillVariable variable;

  /// Parent-scope effective value in the type's canonical string encoding.
  final String inheritedValue;

  /// This scope's local override (canonical string encoding), or null when
  /// the card inherits.
  final String? overrideValue;

  /// Reports the new local value in its canonical string encoding; empty
  /// means "revert to inherit".
  final ValueChanged<String> onChanged;
  final GeocodingService? geocodingService;

  bool get _isOverridden => overrideValue != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // The parenthesized default reads formatted for its type — a time as
    // `12:00`, a location as its UTM (DESIGN-008 follow-up 11). Empty
    // default → no parenthesis at all.
    final formattedDefault = formatVariableValue(
      applyVariableOverride(variable, inheritedValue),
      variableFormatOf(l10n),
    );
    final localOverride = overrideValue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    variable.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      formattedDefault.isEmpty ? '' : '($formattedDefault)',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (_isOverridden)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onChanged(''),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.restart_alt,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              l10n.variableOverridesSectionResetAction,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              VariableValueField(
                // Keyed by name + declared type only: a reset flows through
                // the field's own outside-change sync (so the first
                // keystroke of an override never remounts the field under
                // the caret), while a (rare) declared-type change reshapes
                // the input by remounting.
                key: ValueKey('${variable.name}:${variable.type.name}'),
                type: variable.type,
                value: variable.type == VariableType.location
                    ? ''
                    : localOverride ?? '',
                location: variable.type == VariableType.location
                    ? (localOverride == null
                          ? null
                          : decodeLocationValue(localOverride))
                    : null,
                hintText: l10n.variableOverridesSectionLocalValueLabel,
                accent: _isOverridden,
                geocodingService: geocodingService,
                onChanged: (value, location) => onChanged(
                  variable.type == VariableType.location
                      ? encodeLocationValue(
                          location ?? const VariableLocation(),
                        )
                      : value,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
