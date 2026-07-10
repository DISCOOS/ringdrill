import 'package:flutter/widgets.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/field_resolver.dart' as resolver;
import 'package:ringdrill/utils/exercise_share_format.dart';
import 'package:ringdrill/utils/variable_values.dart'
    show applyVariableOverride;
import 'package:ringdrill/views/widgets/exercise_scope.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
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
/// [roleplayFacets] is this roleplay's own `roleplay.*` facets
/// (name/age/signalement/`position.utm`) for a field inside the roleplay
/// editor. DESIGN-010 folds these into the field's own context rather than
/// a scope ("small enough... than a separate scope") since only the
/// currently-open `RolePlay`'s own live, unsaved identity is ever in play —
/// unlike `station.loc/person.*`, no other roleplay's fields need to read
/// it. Omitted (null) everywhere else.
///
/// A scope missing from the ancestry (no `ExerciseScope` above a
/// program-scope field, no `StationScope` above an exercise-scope field)
/// contributes nothing: its facets are simply absent from the resolution
/// context, so a reference to them resolves to the same literal, unrendered
/// token the brief shows for a genuinely missing cross-reference — honest,
/// not a crash (ADR-0048).
String? resolveScopedField(
  BuildContext context,
  String? content, {
  Map<String, String> overrides = const {},
  Map<String, dynamic>? roleplayFacets,
}) {
  if (content == null || content.isEmpty) return content;
  final l10n = AppLocalizations.of(context)!;
  final planScope = PlanScope.maybeOf(context);
  final exerciseScope = ExerciseScope.maybeOf(context);
  final stationScope = StationScope.maybeOf(context);

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
    if (exerciseScope != null) 'exercise': _exerciseFacets(exerciseScope, l10n),
    if (stationScope != null) 'station': _stationFacets(stationScope),
    'roleplay': ?roleplayFacets,
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

Map<String, dynamic> _exerciseFacets(
  ExerciseScope scope,
  AppLocalizations l10n,
) {
  final exercise = scope.exercise;
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

Map<String, dynamic> _stationFacets(StationScope scope) => {
  'name': scope.name ?? '',
  'stationCode': scope.stationCode ?? '',
  'description': scope.description ?? '',
  'variantSuffix': scope.variantSuffix,
  'position': {'utm': scope.positionUtm ?? ''},
};
