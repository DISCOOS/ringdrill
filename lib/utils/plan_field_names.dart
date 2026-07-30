/// The resolvable `{{scope.facet}}` names, per scope, without Flutter.
///
/// `PlanFieldTokens` (in the views layer) pairs each of these with a localized
/// picker label; this file holds the names alone, which is all a validator needs.
/// DESIGN-014's `analyze` has to know whether `{{exercise.phaseBreakdown}}` is a
/// real facet or a typo, and it runs headless — so it cannot reach the views
/// layer, and duplicating the list there would let the two drift into disagreeing
/// about what resolves.
///
/// Each list mirrors exactly one `refContext` map that `brief_renderer.dart`
/// builds, so a name here is always one the renderer can resolve at that scope.
/// Never add a facet that is not in the matching `refContext` map;
/// `test/utils/plan_field_names_test.dart` checks the two stay in step.
///
/// Free of `package:flutter/*` (AGENTS.md rule 7).
library;

/// Where a facet resolves.
///
/// Scopes cascade downwards — a `plan.*` facet resolves in an exercise, station
/// or role play field too, because those scopes have a plan in context. The
/// reverse does not hold: `exercise.name` cannot resolve in a plan-level field,
/// there being no exercise to resolve it against.
enum PlanFieldScope {
  plan,
  exercise,
  station,
  roleplay;

  /// This scope plus every scope above it — the facets resolvable here.
  List<PlanFieldScope> get withAncestors => switch (this) {
    PlanFieldScope.plan => const [PlanFieldScope.plan],
    PlanFieldScope.exercise => const [
      PlanFieldScope.plan,
      PlanFieldScope.exercise,
    ],
    PlanFieldScope.station => const [
      PlanFieldScope.plan,
      PlanFieldScope.exercise,
      PlanFieldScope.station,
    ],
    PlanFieldScope.roleplay => const [
      PlanFieldScope.plan,
      PlanFieldScope.exercise,
      PlanFieldScope.station,
      PlanFieldScope.roleplay,
    ],
  };
}

/// Facet names by scope.
class PlanFieldNames {
  const PlanFieldNames._();

  static const plan = <String>['plan.name', 'plan.description'];

  static const exercise = <String>[
    'exercise.name',
    'exercise.numberOfTeams',
    'exercise.numberOfRounds',
    'exercise.startTime',
    'exercise.endTime',
    'exercise.timeLabel',
    'exercise.durationLabel',
    'exercise.executionTime',
    'exercise.evaluationTime',
    'exercise.rotationTime',
    'exercise.phaseBreakdown',
  ];

  /// Omits `station.description` deliberately (DESIGN-009 follow-up 4c): it *is*
  /// the free-text field an author edits in the station's own base section, so
  /// offering it there would recurse on itself through the fixpoint pass.
  static const station = <String>[
    'station.name',
    'station.stationCode',
    'station.position',
    'station.variantSuffix',
  ];

  static const roleplay = <String>[
    'roleplay.name',
    'roleplay.age',
    'roleplay.description',
    'roleplay.position',
  ];

  static List<String> of(PlanFieldScope scope) => switch (scope) {
    PlanFieldScope.plan => plan,
    PlanFieldScope.exercise => exercise,
    PlanFieldScope.station => station,
    PlanFieldScope.roleplay => roleplay,
  };

  /// Everything resolvable in a field at [scope], cascade included.
  static Set<String> resolvableAt(PlanFieldScope scope) => {
    for (final s in scope.withAncestors) ...of(s),
  };

  /// Every facet name, any scope.
  static Set<String> get all => {...plan, ...exercise, ...station, ...roleplay};
}
