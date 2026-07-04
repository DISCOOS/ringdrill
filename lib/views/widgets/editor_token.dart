/// A view-layer projection of one declared plan variable (ADR-0046) — just
/// enough for [TokenTextEditingController] to resolve a `{{var.<name>}}`
/// chip's state and for the insertion menu to show its effective value.
/// Deliberately not coupled to `BriefRenderer` or the `Program` model: the
/// caller (e.g. `ProgramFormScreen`) builds this list from whichever scope
/// it is editing.
class VariableToken {
  const VariableToken({
    required this.name,
    required this.effectiveValue,
    this.declared = true,
  });

  final String name;
  final String effectiveValue;

  /// Always true for tokens built from the registry today; reserved for a
  /// later stage that may want to represent a not-yet-declared candidate
  /// alongside real entries in the same list.
  final bool declared;

  bool get isEmpty => effectiveValue.isEmpty;
}

/// A derived, read-only plan field the insertion menu can offer alongside
/// variables (e.g. `exercise.name`). Inserted as a literal `{{name}}`
/// cross-reference for `BriefRenderer`'s existing mustache pass to resolve
/// — it never participates in the `var.*` registry or its validation
/// (ADR-0046), so it is never chipped or shown red.
class PlanFieldToken {
  const PlanFieldToken({required this.name, required this.label, this.hint});

  /// The mustache path, e.g. `program.name` or `exercise.name`.
  final String name;

  /// Localized label shown in the picker.
  final String label;

  /// Optional extra detail shown in the picker instead of a value (plan
  /// fields show a muted "planfelt" hint, never a resolved value).
  final String? hint;
}
