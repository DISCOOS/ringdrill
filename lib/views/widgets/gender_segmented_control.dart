import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';

/// Stable wire codes for a gender identity field — `Person.gender` (this
/// prompt) and, from DESIGN-009 prompt 4, `RolePlay.gender`. Both fields
/// are plain `String?`; these are simply the values this control writes,
/// not an enum on the model (ADR-0047 keeps the field free-form so a
/// marker/author can type something else if none of the three fit).
const genderCodeWoman = 'woman';
const genderCodeMan = 'man';
const genderCodeOther = 'other';

const _genderCodes = [genderCodeWoman, genderCodeMan, genderCodeOther];

/// Localized label for [code], or null when [code] is not one of the three
/// stable codes (e.g. null, or free-form legacy text) — callers decide the
/// fallback (usually showing the raw string, or nothing).
String? genderLabelFor(String? code, AppLocalizations l10n) => switch (code) {
  genderCodeWoman => l10n.genderWomanLabel,
  genderCodeMan => l10n.genderManLabel,
  genderCodeOther => l10n.genderOtherLabel,
  _ => null,
};

/// Three-way segmented control (Kvinne / Mann / Annet) writing one of
/// [genderCodeWoman]/[genderCodeMan]/[genderCodeOther] — DESIGN-009's
/// replacement for a free-text gender field, shared so prompt 4's
/// `RolePlayFormScreen` can reuse it verbatim for `RolePlay.gender`.
///
/// [value] may be null (no selection) or any string; a value outside the
/// three known codes renders as no selection rather than asserting, so an
/// unexpected value (should one ever occur) degrades safely instead of
/// crashing the form.
class GenderSegmentedControl extends StatelessWidget {
  const GenderSegmentedControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(
          value: genderCodeWoman,
          label: Text(l10n.genderWomanLabel),
        ),
        ButtonSegment(value: genderCodeMan, label: Text(l10n.genderManLabel)),
        ButtonSegment(
          value: genderCodeOther,
          label: Text(l10n.genderOtherLabel),
        ),
      ],
      selected: _genderCodes.contains(value) ? {value!} : const {},
      emptySelectionAllowed: true,
      onSelectionChanged: (selected) =>
          onChanged(selected.isEmpty ? null : selected.first),
    );
  }
}
