/// Canonical `{{var.<name>}}` matching and substitution (ADR-0046) — the
/// single source for the token shape. Previously duplicated by hand across
/// `BriefRenderer`, `TokenTextEditingController` and
/// `plan_variable_refs.dart`; those now import this instead.
///
/// Pure and Flutter-free: `BriefRenderer` (and, transitively, the CLI at
/// `bin/ringdrill.dart`) depends on this, so it must never import
/// `package:flutter/*`.
library;

import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/utils/station_scenario_tokens.dart';
import 'package:ringdrill/utils/variable_values.dart';

/// Matches `{{var.<name>}}`, tolerating inner whitespace around the name,
/// with an optional dotted facet path (`.place`, `.position` — used
/// by `location`-typed variables, DESIGN-008 follow-up 11; `utm`/`latlng`
/// were renamed to `position` by ADR-0050). Capture group 1
/// is the name, group 2 the facet path including its leading dots (empty
/// for the bare token) — same shape as `stationScenarioTokenPattern`. A
/// declared variable name (ADR-0046) starts with a lowercase letter, then
/// lowercase letters/digits/underscores — see
/// `lib/views/widgets/variables_section.dart`'s `_slugPattern` for the
/// matching authoring-time validation rule (a distinct concern: validating
/// a name being typed, not matching an existing token).
final planVariableTokenPattern = RegExp(
  r'\{\{\s*var\.([a-z][a-z0-9_]*)((?:\.[a-zA-Z]+)*)\s*\}\}',
);

/// Facet path segments after the name for a [planVariableTokenPattern]
/// match, e.g. `.position` → `['position']`; empty for the bare token.
List<String> planVariableTokenFacets(Match match) =>
    (match.group(2) ?? '').split('.').where((s) => s.isNotEmpty).toList();

/// Matches `{{var.<name>}}` (with an optional facet path, captured as
/// group 1 including its leading dots) for one specific [name],
/// whitespace-tolerant — for counting or rewriting references to a single
/// declared variable (`plan_variable_refs.dart`), rather than capturing an
/// arbitrary name. A rename rewrite must carry the facet path over — see
/// `renameVariable`.
RegExp planVariableTokenPatternFor(String name) => RegExp(
  '\\{\\{\\s*var\\.${RegExp.escape(name)}((?:\\.[a-zA-Z]+)*)\\s*\\}\\}',
);

/// Replaces every `{{var.<name>}}` token in [text] with its value in
/// [vars]. For a name that is not a key of [vars] (undeclared), calls
/// [onUnknown] with the name and substitutes its result; if [onUnknown] is
/// omitted, the token is left as literal text.
///
/// This is the plain, untyped substitution: a facet path on a matched name
/// is ignored and the bare value substituted (scalar types render bare —
/// DESIGN-008 follow-up 11). Surfaces that need per-type formatting and
/// `location` facet resolution use [resolveTypedPlanVariables] instead.
String substitutePlanVariables(
  String text,
  Map<String, String> vars, {
  String Function(String name)? onUnknown,
}) {
  return text.replaceAllMapped(planVariableTokenPattern, (match) {
    final name = match.group(1)!;
    final value = vars[name];
    if (value != null) return value;
    return onUnknown == null ? match.group(0)! : onUnknown(name);
  });
}

/// Typed substitution (DESIGN-008 follow-up 11): replaces every
/// `{{var.<name>[.facet]}}` token in [text] with its display rendering —
/// each scalar formatted canonically for its type via
/// [formatVariableValue] with [format], and a `location`-typed variable
/// resolved through the shared DESIGN-009 Location facet code
/// ([resolveLocationFacet]): `.place`, `.position`, bare = place +
/// UTM. Facets on a scalar are ignored and the bare formatted value
/// substituted (scalars render bare in v1).
///
/// [locationFacetResolver] overrides the location rendering — the brief
/// renderer passes its own so `.utm` and the bare token keep the brief's
/// inline-code chip styling; the default renders plain text for editor
/// previews and live display.
String resolveTypedPlanVariables(
  String text,
  Map<String, DrillVariable> vars, {
  required VariableFormat format,
  String Function(String name)? onUnknown,
  String Function(Location location, List<String> facets)?
  locationFacetResolver,
}) {
  return text.replaceAllMapped(planVariableTokenPattern, (match) {
    final name = match.group(1)!;
    final variable = vars[name];
    if (variable == null) {
      return onUnknown == null ? match.group(0)! : onUnknown(name);
    }
    if (variable.type == VariableType.location) {
      final location = variableLocationAsLocation(variable);
      final facets = planVariableTokenFacets(match);
      if (locationFacetResolver != null) {
        return locationFacetResolver(location, facets);
      }
      return facets.isEmpty
          ? locationPlaceUtm(location)
          : resolveLocationFacet(location, facets);
    }
    return formatVariableValue(variable, format);
  });
}

/// Effective *typed* variables for a scope (ADR-0046 + DESIGN-008
/// follow-up 11): each declared [DrillVariable] with [exercise]'s then
/// [station]'s string override applied per its type
/// ([applyVariableOverride] — a location override decodes into the
/// structured value) — later scopes win. An override key that is not a
/// declared variable name is ignored, per ADR-0046's "an undeclared
/// override key is meaningless" rule.
Map<String, DrillVariable> effectiveTypedPlanVariables(
  Plan plan, {
  Exercise? exercise,
  Station? station,
}) {
  final vars = {for (final v in plan.variables) v.name: v};
  void apply(Map<String, String> overrides) {
    for (final entry in overrides.entries) {
      final declared = vars[entry.key];
      if (declared != null) {
        vars[entry.key] = applyVariableOverride(declared, entry.value);
      }
    }
  }

  if (exercise != null) apply(exercise.variableOverrides);
  if (station != null) apply(station.variableOverrides);
  return vars;
}

/// Effective variable values for a scope (ADR-0046), as display-ready
/// strings for surfaces that substitute without a locale in hand: scalar
/// types carry their canonical value; a `location`-typed variable renders
/// its bare place + UTM display (its canonical encoding is a storage
/// format, not something to show in a station name or share text).
///
/// Shared by the live views' name substitution and share text; the brief
/// renderer and the editor previews use [effectiveTypedPlanVariables] with
/// per-type formatting instead.
Map<String, String> effectivePlanVariables(
  Plan plan, {
  Exercise? exercise,
  Station? station,
}) {
  return {
    for (final entry in effectiveTypedPlanVariables(
      plan,
      exercise: exercise,
      station: station,
    ).entries)
      entry.key: entry.value.type == VariableType.location
          ? locationPlaceUtm(variableLocationAsLocation(entry.value))
          : entry.value.value,
  };
}
