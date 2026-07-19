import 'package:flutter/widgets.dart';
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
/// assembles the equivalent context server-side from the loaded `Program`;
/// this is the same cascade read from the widget tree instead.
///
/// [overrides] is [content]'s own scope-level variable overrides (e.g. an
/// `Exercise`'s/`Station`'s `variableOverrides`) — same map a token-aware
/// field's own `overrides` param already carries.
///
/// The roleplay's own `roleplay.*` facets (name/age/signalement/
/// `position.utm`) come from a [RoleplayScope] ancestor when one is present —
/// the viewer/editor wrap their roleplay content in `RoleplayScope.forRoleplay`
/// once, so no field has to thread the facets down itself.
///
/// A scope missing from the ancestry (no `ExerciseScope` above a
/// program-scope field, no `StationScope` above an exercise-scope field, no
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
    // Always present: PlanScope is the mandatory (program) level of the
    // cascade — a null programName/programDescription (a provider that
    // hasn't forwarded them) renders {{program.*}} empty, same as the
    // brief does for an empty Program.name/description, never a crash.
    'program': {
      'name': planScope?.programName,
      'description': planScope?.programDescription,
    },
    if (exerciseScope != null)
      'exercise': _exerciseFacets(exerciseScope.exercise, l10n),
    if (stationScope != null)
      'station': _stationFacets(
        name: stationScope.name,
        stationCode: stationScope.stationCode,
        description: stationScope.description,
        variantSuffix: stationScope.variantSuffix,
        positionUtm: stationScope.positionUtm,
      ),
    if (roleplayScope != null)
      'roleplay': _roleplayFacets(
        name: roleplayScope.name,
        age: roleplayScope.age,
        signalement: roleplayScope.signalement,
        positionUtm: roleplayScope.positionUtm,
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
    l10n: l10n,
    refContext: refContext,
    scenarioStation: scenarioStation,
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
/// The program level and the declared variables still come from the ambient
/// [PlanScope] (every map/search surface has one); [overrides] shadows a
/// declared value the same way [resolveScopedField]'s does.
String? resolveModelField(
  BuildContext context,
  String? content, {
  Exercise? exercise,
  Station? station,
  RolePlay? roleplay,
  Map<String, String> overrides = const {},
}) {
  if (content == null || content.isEmpty) return content;
  final l10n = AppLocalizations.of(context)!;
  final planScope = PlanScope.maybeOf(context);

  final vars = <String, DrillVariable>{
    for (final v in planScope?.variables ?? const [])
      v.name: applyVariableOverride(v, overrides[v.name]),
  };

  final refContext = <String, dynamic>{
    'program': {
      'name': planScope?.programName,
      'description': planScope?.programDescription,
    },
    if (exercise != null) 'exercise': _exerciseFacets(exercise, l10n),
    if (station != null)
      'station': _stationFacets(
        name: station.name,
        description: station.description,
        variantSuffix: station.variantSuffix,
        positionUtm: resolver.formatUtm(station.position),
      ),
    if (roleplay != null)
      'roleplay': _roleplayFacets(
        name: roleplay.name,
        age: roleplay.age,
        signalement: roleplay.signalement,
        positionUtm: resolver.formatUtm(roleplay.position),
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
    l10n: l10n,
    refContext: refContext,
    scenarioStation: scenarioStation,
  );
}

// The facet builders take plain fields, not scope objects, so the two
// resolution entry points share one source of the `{{exercise/station/
// roleplay.*}}` shape (ADR-0048 — no drift): [resolveScopedField] feeds them
// from the ancestor scopes, [resolveModelField] from explicit models.

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
    'durationLabel': exerciseDurationLabel(exercise, l10n),
    'phaseBreakdown': rotationPhaseBreakdown(exercise),
  };
}

Map<String, dynamic> _stationFacets({
  String? name,
  String? stationCode,
  String? description,
  String? variantSuffix,
  String? positionUtm,
}) => {
  'name': name ?? '',
  'stationCode': stationCode ?? '',
  'description': description ?? '',
  'variantSuffix': variantSuffix,
  'position': {'utm': resolver.briefCopyChip(positionUtm ?? '')},
};

Map<String, dynamic> _roleplayFacets({
  required String name,
  int? age,
  String? signalement,
  String? positionUtm,
}) => {
  'name': name,
  'age': age,
  'signalement': signalement ?? '',
  'position': {'utm': resolver.briefCopyChip(positionUtm ?? '')},
};
