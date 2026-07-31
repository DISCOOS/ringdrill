/// ADR-0067's token browser: the whole token inventory for one field, with a
/// description and a live resolved value per row.
///
/// The caret menu (`token_insertion_menu.dart`) stays the fast path — three
/// keystrokes and take the first hit — and this is the other half: what to do when
/// you do not already know the token's name. A caret-anchored 360x240 card has
/// three slots per row and no room to say what a token *means*; a picker row has
/// as many lines as it needs.
///
/// Not a new surface. [showRingdrillPicker] (ADR-0049) is the app's "pick one from
/// a list" primitive and already provides the bottom-sheet-on-compact,
/// dialog-on-medium/expanded split, the search field, the section headers computed
/// over the filtered list, and pop-with-the-chosen-item.
library;

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/plan_field_names.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';
import 'package:ringdrill/views/widgets/resolve_scoped_field.dart';
import 'package:ringdrill/views/widgets/ringdrill_picker.dart';

/// The kinds of token the browser groups by, in the order it shows them.
///
/// The four scopes come first in cascade order, then the registries. Same order in
/// the sections and in the filter, so the two read as one list.
enum TokenCategory {
  plan,
  exercise,
  station,
  roleplay,
  variable,
  location,
  person,
}

/// One row in the browser: either an insertable token, or a note explaining why a
/// category has nothing in it.
///
/// A note rather than a disabled row: the primitive has no concept of a row that
/// cannot be chosen, and teaching it one to say "no roleplay here" would be a lot
/// of machinery for a sentence.
sealed class TokenBrowserEntry {
  const TokenBrowserEntry(this.category);

  final TokenCategory category;

  /// What the search field matches against.
  String get searchText;
}

/// An insertable token.
class TokenBrowserToken extends TokenBrowserEntry {
  const TokenBrowserToken({
    required TokenCategory category,
    required this.token,
    required this.label,
    required this.description,
    this.value,
    this.example,
  }) : super(category);

  /// The text inserted at the caret, braces included.
  final String token;

  /// The human name for the row's first line.
  final String label;

  final String description;

  /// What it resolves to right now in this field's scope, or null when there is
  /// nothing to show and [example] should stand in for it.
  final String? value;

  /// What the token produces, shown when [value] is null.
  final String? example;

  @override
  String get searchText => '$label $token $description';
}

/// A muted note standing in for an empty category.
class TokenBrowserNote extends TokenBrowserEntry {
  const TokenBrowserNote({required TokenCategory category, required this.note})
    : super(category);

  final String note;

  /// Deliberately not searchable: a note is not a thing the author is looking
  /// for, and matching it would leave a header over a row that cannot be chosen.
  @override
  String get searchText => '';
}

/// Builds the entries for a field, resolving every value against [context]'s
/// scopes.
///
/// Called from inside the field's own scopes — the picker mounts on a modal route
/// where `PlanScope` and friends are out of reach (DESIGN-008 follow-up 11), so the
/// values have to be resolved before it opens, not inside its builder.
///
/// The inputs are exactly what the caret menu already receives, so the browser
/// cannot offer a token the menu does not, or miss one it does.
List<TokenBrowserEntry> buildTokenBrowserEntries(
  BuildContext context, {
  required List<PlanFieldToken> planFields,
  required List<VariableToken> variables,
  required List<StationLocationToken> stationLocations,
  required List<StationPersonToken> stationPersons,
}) {
  final l10n = AppLocalizations.of(context)!;
  final entries = <TokenBrowserEntry>[];

  // Scope rows, in cascade order rather than the order the caller happened to
  // concatenate them in.
  for (final scope in PlanFieldScope.values) {
    final fields = planFields.where((f) => f.scope == scope);
    for (final field in fields) {
      final value = _resolved(context, field.name);
      entries.add(
        TokenBrowserToken(
          category: _categoryOf(scope),
          token: '{{${field.name}}}',
          label: field.label,
          description: field.description,
          value: value,
          example: value == null ? field.example : null,
        ),
      );
    }
  }

  // Variables always get a section: a plan with none declared is a plan whose
  // author may not know they exist, and the note says where to make one.
  if (variables.isEmpty) {
    entries.add(
      TokenBrowserNote(
        category: TokenCategory.variable,
        note: l10n.tokenBrowserNoVariables,
      ),
    );
  } else {
    for (final v in variables) {
      entries.add(
        TokenBrowserToken(
          category: TokenCategory.variable,
          token: '{{var.${v.name}}}',
          label: v.name,
          description: l10n.tokenBrowserVariableDescription,
          value: v.effectiveValue.isEmpty ? null : v.effectiveValue,
        ),
      );
    }
  }

  // Locations and persons belong to a station, so they appear only for a field
  // that has one in scope — and then they appear even when the station owns
  // none, because "you could add one" is worth saying where "this does not
  // apply" is not.
  final hasStation = planFields.any(
    (f) =>
        f.scope == PlanFieldScope.station || f.scope == PlanFieldScope.roleplay,
  );
  if (hasStation) {
    if (stationLocations.isEmpty) {
      entries.add(
        TokenBrowserNote(
          category: TokenCategory.location,
          note: l10n.tokenBrowserNoLocations,
        ),
      );
    } else {
      for (final loc in stationLocations) {
        entries.add(
          TokenBrowserToken(
            category: TokenCategory.location,
            token: '{{station.loc.${loc.slug}}}',
            label: loc.label,
            description: l10n.tokenBrowserLocationDescription,
            value: loc.preview.isEmpty ? null : loc.preview,
          ),
        );
      }
    }
    if (stationPersons.isEmpty) {
      entries.add(
        TokenBrowserNote(
          category: TokenCategory.person,
          note: l10n.tokenBrowserNoPersons,
        ),
      );
    } else {
      for (final p in stationPersons) {
        entries.add(
          TokenBrowserToken(
            category: TokenCategory.person,
            token: '{{station.person.${p.slug}}}',
            label: p.label,
            description: l10n.tokenBrowserPersonDescription,
            value: p.preview.isEmpty ? null : p.preview,
          ),
        );
      }
    }
  }

  return entries;
}

TokenCategory _categoryOf(PlanFieldScope scope) => switch (scope) {
  PlanFieldScope.plan => TokenCategory.plan,
  PlanFieldScope.exercise => TokenCategory.exercise,
  PlanFieldScope.station => TokenCategory.station,
  PlanFieldScope.roleplay => TokenCategory.roleplay,
};

/// Resolves `{{<name>}}` against the ambient scopes, as plain text.
///
/// Null when it resolves to nothing, or to itself — an unresolvable reference comes
/// back as the literal token, and printing that as the value would claim the token
/// produces its own source.
String? _resolved(BuildContext context, String name) {
  final raw = resolveScopedField(context, '{{$name}}');
  if (raw == null) return null;
  final plain = _plain(raw).trim();
  if (plain.isEmpty || plain.contains('{{')) return null;
  return plain;
}

/// A position resolves as a tappable chip — `[32V …](ringdrill://chip?…)`
/// (ADR-0050) — and a location's place as inline code. Neither belongs in a value
/// line that is read rather than rendered.
final _link = RegExp(r'\[([^\]]*)\]\([^)]*\)');
String _plain(String text) =>
    text.replaceAllMapped(_link, (m) => m.group(1) ?? '').replaceAll('`', '');

/// Opens the browser and resolves with the token to insert, or null if dismissed.
Future<String?> showTokenBrowser({
  required BuildContext context,
  required List<TokenBrowserEntry> entries,
  String? subtitle,
}) async {
  final l10n = AppLocalizations.of(context)!;

  // Only the categories this field actually has, in enum order — the same rule
  // the sections follow, so the filter and the list cannot disagree.
  final present = TokenCategory.values
      .where((c) => entries.any((e) => e.category == c))
      .toList();

  final chosen = await showRingdrillPicker<TokenBrowserEntry>(
    context: context,
    title: l10n.tokenBrowserTitle,
    subtitle: subtitle,
    items: entries,
    searchText: (e) => e.searchText,
    searchHint: l10n.tokenBrowserSearchHint,
    // Always: the inventory is tens of rows even for a plan-scope field.
    searchThreshold: 0,
    sectionLabel: (e) => _categoryLabel(l10n, e.category),
    allFilterLabel: l10n.tokenBrowserFilterAll,
    filters: [
      for (final c in present)
        PickerFilter<TokenBrowserEntry>(
          label: _categoryLabel(l10n, c),
          matches: (e) => e.category == c,
        ),
    ],
    itemBuilder: (context, entry, onTap) => switch (entry) {
      TokenBrowserNote(note: final note) => _NoteRow(note: note),
      TokenBrowserToken() => _TokenRow(token: entry, onTap: onTap),
    },
  );
  return switch (chosen) {
    TokenBrowserToken(token: final t) => t,
    _ => null,
  };
}

/// Singular throughout: a filter and a section header name a category, they do not
/// count one.
///
/// `roleplay` reads as the plan tab's own segment name ("Spill" / "Script") rather
/// than `l.roleplay(1)` ("Markør"), which names the roles inside that segment
/// rather than the layer the tokens belong to.
String _categoryLabel(AppLocalizations l10n, TokenCategory category) =>
    switch (category) {
      TokenCategory.plan => l10n.plan(1),
      TokenCategory.exercise => l10n.exercise(1),
      TokenCategory.station => l10n.station(1),
      TokenCategory.roleplay => l10n.scriptSegment,
      TokenCategory.variable => l10n.tokenBrowserCategoryVariable,
      TokenCategory.location => l10n.tokenBrowserCategoryLocation,
      TokenCategory.person => l10n.tokenBrowserCategoryPerson,
    };

/// Three lines: what it is called with the token beside it, what it resolves to,
/// and what it means.
///
/// No leading icon. The scope is already in the section header and in the token's
/// own prefix, so an icon would only push every line in and take that width off
/// the long values — which is the failure this row exists to avoid.
class _TokenRow extends StatelessWidget {
  const _TokenRow({required this.token, required this.onTap});

  final TokenBrowserToken token;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    token.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                // The full string on hover or long-press. Truncation is from the
                // right, and the right is exactly where a chained token differs
                // from its neighbours: `…anne.loc.position` and `…anne.loc.name`
                // are the same row until the tail.
                Flexible(
                  child: Tooltip(
                    message: token.token,
                    child: Text(
                      token.token,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: muted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _value(context),
            const SizedBox(height: 4),
            Text(
              token.description,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }

  /// The resolved value, or the example marked as one.
  ///
  /// A wrapping block rather than a trailing slot: an unbounded trailing string is
  /// what consumed the caret menu's rows whole, and a value with room to wrap is
  /// the reason this surface exists.
  Widget _value(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final value = token.value;
    if (value != null) {
      return Text(
        value,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      );
    }
    final example = token.example;
    if (example == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.tokenBrowserExample,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            example,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Text(
        note,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
