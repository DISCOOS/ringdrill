import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/views/widgets/app_brief_labels.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/field_resolver.dart' as resolver;
import 'package:ringdrill/utils/exercise_share_format.dart';
import 'package:ringdrill/utils/variable_values.dart'
    show applyVariableOverride;
import 'package:ringdrill/views/widgets/exercise_scope.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/roleplay_scope.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';

/// DESIGN-010's shared resolution primitive: "resolve a field string against
/// the scopes, render it read-only" — the per-section preview toggle and the
/// section rollup both call this rather than each assembling their own
/// context, so there is exactly one place that walks `PlanScope` →
/// `ExerciseScope` → `StationScope` and hands the result to
/// `lib/services/brief/field_resolver.dart` (ADR-0048). `BriefRenderer`
/// assembles the equivalent context server-side from the loaded `Plan`;
/// this is the same cascade read from the widget tree instead.
///
/// [overrides] is [content]'s own scope-level variable overrides (e.g. an
/// `Exercise`'s/`Station`'s `variableOverrides`) — same map a token-aware
/// field's own `overrides` param already carries.
///
/// The roleplay's own `roleplay.*` facets (name/age/description/`position`)
/// come from a [RoleplayScope] ancestor when one is present —
/// the viewer/editor wrap their roleplay content in `RoleplayScope.forRoleplay`
/// once, so no field has to thread the facets down itself.
///
/// A scope missing from the ancestry (no `ExerciseScope` above a
/// plan-scope field, no `StationScope` above an exercise-scope field, no
/// `RoleplayScope` outside a roleplay surface) contributes nothing: its facets
/// are simply absent from the resolution context, so a reference to them
/// resolves to the same literal, unrendered token the brief shows for a
/// genuinely missing cross-reference — honest, not a crash (ADR-0048).
String? resolveScopedField(
  BuildContext context,
  String? content, {
  Map<String, String> overrides = const {},
}) {
  if (content == null || content.isEmpty) return content;
  final l10n = AppLocalizations.of(context)!;
  final planScope = PlanScope.maybeOf(context);
  final exerciseScope = ExerciseScope.maybeOf(context);
  final stationScope = StationScope.maybeOf(context);
  final roleplayScope = RoleplayScope.maybeOf(context);

  final vars = <String, DrillVariable>{
    for (final v in planScope?.variables ?? const [])
      v.name: applyVariableOverride(v, overrides[v.name]),
  };

  final refContext = <String, dynamic>{
    // Always present: PlanScope is the mandatory (plan) level of the
    // cascade — a null planName/planDescription (a provider that
    // hasn't forwarded them) renders {{plan.*}} empty, same as the
    // brief does for an empty Plan.name/description, never a crash.
    'plan': _planFacets(planScope),
    if (exerciseScope != null)
      'exercise': _exerciseFacets(exerciseScope.exercise, l10n),
    if (stationScope != null)
      'station': _stationFacets(
        name: stationScope.name,
        stationCode: stationScope.stationCode,
        description: stationScope.description,
        variantSuffix: stationScope.variantSuffix,
        position: stationScope.position,
        // Per-round length, which is an exercise property read at station
        // scope — absent, like any other facet whose scope is missing, when
        // the field is previewed outside an ExerciseScope. The station's own
        // execution time overrides the exercise's where it has one (ADR-0062).
        exercise: exerciseScope?.exercise,
        executionTime: stationScope.executionTime,
        evaluationTime: stationScope.evaluationTime,
        rotationTime: stationScope.rotationTime,
      ),
    if (roleplayScope != null)
      'roleplay': _roleplayFacets(
        name: roleplayScope.name,
        age: roleplayScope.age,
        description: roleplayScope.description,
        position: roleplayScope.position,
      ),
  };

  // A throwaway Station carrying only what the resolver's scenario-token
  // pass reads (locations/persons by slug) — StationScope deliberately
  // stores those as plain lists rather than a whole Station (it is not the
  // model, it is the DESIGN-010 scope), so this adapts the shape rather
  // than duplicating the resolver's lookup logic. Portrayer-aware identity
  // (a roleplay overriding a person's name/age/etc.) is not reconstructed
  // here — StationScope exposes that as an opaque `portrayerOf` callback,
  // not a `RolePlay` list, so preview resolves station.person.* against the
  // Person's own bare fields; the brief itself still applies the portrayer
  // override once generated.
  final scenarioStation = stationScope == null
      ? null
      : Station(
          index: 0,
          name: stationScope.name ?? '',
          locations: stationScope.locations,
          persons: stationScope.persons,
        );

  return resolver.resolveField(
    content,
    vars: vars,
    l10n: l10n.brief,
    refContext: refContext,
    scenarioStation: scenarioStation,
    chips: const resolver.ActionChipFormatter(),
  );
}

/// [resolveScopedField]'s eager, model-driven twin: resolves [content]
/// against cross-reference facets built from explicitly passed models rather
/// than from the widget tree. For a label computed imperatively per item —
/// a map marker's or search result's caption, built in a `.map()` over many
/// different roleplays/stations, where there is no per-item scoped subtree to
/// read from — so `{{exercise.*}}`/`{{station.*}}`/`{{roleplay.*}}` in a name
/// resolve the same way they do in a scoped surface and the brief, instead of
/// the mustache pass throwing on the first absent scope and dragging the whole
/// label back to literal.
///
/// The plan level and the declared variables still come from the ambient
/// [PlanScope] (every map/search surface has one); [overrides] shadows a
/// declared value the same way [resolveScopedField]'s does.
///
/// [selfScope] says that [content] *is* one entity's name (`exercise`,
/// `station`, `roleplay`, `plan`), so that scope's own `name` facet is withheld
/// and a name referencing itself stays a visible token instead of expanding into
/// repeated copies of itself — see [resolver.refContextForName], which the
/// brief's names share.
String? resolveModelField(
  BuildContext context,
  String? content, {
  Exercise? exercise,
  Station? station,
  RolePlay? roleplay,
  Map<String, String> overrides = const {},
  String? selfScope,
}) {
  if (content == null || content.isEmpty) return content;
  final l10n = AppLocalizations.of(context)!;
  final planScope = PlanScope.maybeOf(context);

  final vars = <String, DrillVariable>{
    for (final v in planScope?.variables ?? const [])
      v.name: applyVariableOverride(v, overrides[v.name]),
  };

  final refContext = <String, dynamic>{
    'plan': _planFacets(planScope),
    if (exercise != null) 'exercise': _exerciseFacets(exercise, l10n),
    if (station != null)
      'station': _stationFacets(
        name: station.name,
        description: station.description,
        variantSuffix: station.variantSuffix,
        position: station.position,
        exercise: exercise,
        executionTime: station.executionTime,
        evaluationTime: station.evaluationTime,
        rotationTime: station.rotationTime,
      ),
    if (roleplay != null)
      'roleplay': _roleplayFacets(
        name: roleplay.name,
        age: roleplay.age,
        description: roleplay.description,
        position: roleplay.position,
      ),
  };

  final scenarioStation = station == null
      ? null
      : Station(
          index: 0,
          name: station.name,
          locations: station.locations,
          persons: station.persons,
        );

  return resolver.resolveField(
    content,
    vars: vars,
    l10n: l10n.brief,
    refContext: selfScope == null
        ? refContext
        : resolver.refContextForName(refContext, selfScope),
    scenarioStation: scenarioStation,
    chips: const resolver.ActionChipFormatter(),
  );
}

// The facet builders take plain fields, not scope objects, so the two
// resolution entry points share one source of the `{{exercise/station/
// roleplay.*}}` shape (ADR-0048 — no drift): [resolveScopedField] feeds them
// from the ancestor scopes, [resolveModelField] from explicit models.

Map<String, dynamic> _planFacets(PlanScope? scope) => {
  'name': scope?.planName,
  'description': scope?.planDescription,
  // Null when the provider has no plan to count, so `{{plan.teamCount}}`
  // renders empty rather than a confident "0".
  'exerciseCount': scope?.planCounts?.exercises,
  'teamCount': scope?.planCounts?.teams,
  'stationCount': scope?.planCounts?.stations,
};

Map<String, dynamic> _exerciseFacets(Exercise exercise, AppLocalizations l10n) {
  return {
    'name': exercise.name,
    'numberOfTeams': exercise.numberOfTeams,
    'numberOfRounds': exercise.numberOfRounds,
    'startTime': exercise.startTime.toString(),
    'endTime': exercise.endTime.toString(),
    'executionTime': exercise.executionTime,
    'evaluationTime': exercise.evaluationTime,
    'rotationTime': exercise.rotationTime,
    'timeLabel': exerciseTimeLabel(exercise),
    'durationLabel': exerciseDurationLabel(exercise, l10n.brief),
    'phaseBreakdown': rotationPhaseBreakdown(exercise),
    'roundTable': rotationRoundTable(exercise, l10n.brief),
  };
}

Map<String, dynamic> _stationFacets({
  String? name,
  String? stationCode,
  String? description,
  String? variantSuffix,
  LatLng? position,
  Exercise? exercise,
  int? executionTime,
  int? evaluationTime,
  int? rotationTime,
}) => {
  'name': name ?? '',
  'stationCode': stationCode ?? '',
  'description': description ?? '',
  'variantSuffix': variantSuffix,
  'position': const resolver.ActionChipFormatter().position(
    resolver.formatUtm(position),
    position,
  ),
  'duration': exercise == null
      ? null
      : stationDurationLabel(
          exercise,
          executionTime: executionTime,
          evaluationTime: evaluationTime,
          rotationTime: rotationTime,
        ),
};

Map<String, dynamic> _roleplayFacets({
  required String name,
  int? age,
  String? description,
  LatLng? position,
}) => {
  'name': name,
  'age': age,
  'description': description ?? '',
  'position': const resolver.ActionChipFormatter().position(
    resolver.formatUtm(position),
    position,
  ),
};
