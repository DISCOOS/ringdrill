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

/// A view-layer projection of one station-owned [Location]/[Person]
/// (ADR-0047, DESIGN-009 follow-up 4) for the insertion menu — just enough
/// to list it as a `station.loc.*`/`station.person.*` entry with a preview
/// value, mirroring [VariableToken]'s role for `var.*`. Built by
/// `StationScope` from its own `locations`/`persons`.
class StationLocationToken {
  const StationLocationToken({
    required this.slug,
    required this.label,
    required this.preview,
  });

  final String slug;

  /// Display name shown in the picker (the location's own label, falling
  /// back to its slug when blank).
  final String label;

  /// The bare-facet resolved value (place, falling back to UTM) — the same
  /// preview a `var.*` entry shows via its effective value.
  final String preview;
}

class StationPersonToken {
  const StationPersonToken({
    required this.slug,
    required this.label,
    required this.preview,
  });

  final String slug;

  /// Display name shown in the picker (the person's own name, falling back
  /// to its slug when blank).
  final String label;

  /// The bare-facet resolved (effective) name.
  final String preview;
}

/// Self-reference withholding for one leaf field (DESIGN-009's
/// self-reference rule, DESIGN-009 follow-up 4e): a field never offers the
/// token that would read back its own value, since that value contains the
/// token being typed and would recurse through the fixpoint pass. [slug] is
/// this field's own entity (null when the entity does not exist yet, e.g. a
/// new [Location]/[Person] not yet part of the ambient `StationScope`, in
/// which case there is nothing to withhold). [excludeBare] withholds the
/// bare `{{station.loc/person.<slug>}}` default only when it embeds this
/// field's own text (e.g. a location's bare default reads `place`).
/// [excludedFacet], when set, withholds just that one facet (e.g. `place`
/// or `name`) for [slug] — every other facet of the same entity, and every
/// other entity, stays offered.
class SelfTokenExclusion {
  const SelfTokenExclusion({
    required this.slug,
    this.excludeBare = false,
    this.excludedFacet,
  });

  final String slug;
  final bool excludeBare;
  final String? excludedFacet;
}
