import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/plan_field_names.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';

/// Single source of truth for the [PlanFieldToken] lists every editor's
/// token picker offers (DESIGN-009 follow-up 4b). Each list mirrors exactly
/// one `refContext` map `brief_renderer.dart` builds — [plan] the
/// `_planRefContext` facets, [exercise] the `_exerciseRefContext` facets
/// — so a token this picker offers is always one the renderer can resolve
/// at that scope. Never add a facet here that isn't already in the
/// matching `refContext` map.
///
/// The facet *names* live in `lib/utils/plan_field_names.dart`, which is free of
/// Flutter so the CLI's `analyze` can validate a `{{exercise.phaseBreakdown}}`
/// reference headlessly (DESIGN-014). This class adds the localized picker
/// labels, and `_labelled` asserts the two lists agree — a name added there
/// without a label here, or vice versa, fails loudly rather than silently
/// dropping a token from the picker.
class PlanFieldTokens {
  const PlanFieldTokens._();

  /// Resolvable at plan scope and, via cascade, everywhere below it
  /// (exercise, station, roleplay).
  static List<PlanFieldToken> plan(AppLocalizations l) =>
      _labelled(l, PlanFieldScope.plan, {
        'plan.name': l.planName,
        'plan.description': l.planDescription,
        'plan.exerciseCount': l.exerciseCount,
        'plan.teamCount': l.teamCount,
        'plan.stationCount': l.stationCount,
      });

  /// Resolvable at exercise scope and, via cascade, station/roleplay scope
  /// — but never at plan scope, which has no exercise in context.
  static List<PlanFieldToken> exercise(AppLocalizations l) =>
      _labelled(l, PlanFieldScope.exercise, {
        'exercise.name': l.exerciseName,
        'exercise.numberOfTeams': l.numberOfTeams,
        'exercise.numberOfRounds': l.numberOfRounds,
        'exercise.startTime': l.startTime,
        'exercise.endTime': l.endTime,
        'exercise.timeLabel': l.timeLabel,
        'exercise.durationLabel': l.durationLabel,
        'exercise.executionTime': l.executionTime,
        'exercise.evaluationTime': l.evaluationTime,
        'exercise.rotationTime': l.rotationTime,
        'exercise.phaseBreakdown': l.phaseBreakdown,
        'exercise.roundTable': l.roundTable,
      });

  /// Resolvable at station scope and, via cascade, roleplay scope. Omits
  /// `station.description` (DESIGN-009 follow-up 4c): it *is* the free-text
  /// field the author edits in the station's own base section — resolving
  /// through the fixpoint pass, offering it there recurses on itself.
  static List<PlanFieldToken> station(AppLocalizations l) =>
      _labelled(l, PlanFieldScope.station, {
        'station.name': l.stationName,
        'station.stationCode': l.stationCode,
        'station.position': l.positionUtm,
        'station.variantSuffix': l.variantSuffix,
        'station.duration': l.stationDuration,
      });

  /// Resolvable at roleplay scope only. `roleplay.name` is self-referential
  /// in the roleplay's own name field the same way `station.description` is
  /// (DESIGN-009 follow-up 4c) — the renderer only substitutes `{{var.*}}`
  /// in that field, never runs the cross-reference pass on it — so the
  /// caller must exclude it from that one field's own `planFields` while
  /// still offering it in the roleplay's other fields (behavior, background,
  /// propsMd). `roleplay.description` has the matching issue in the
  /// description field, but that field is never token-aware in the first
  /// place, so no caller-side filtering is needed for it.
  static List<PlanFieldToken> roleplay(AppLocalizations l) =>
      _labelled(l, PlanFieldScope.roleplay, {
        'roleplay.name': l.roleName,
        'roleplay.age': l.roleAge,
        'roleplay.description': l.roleDescription,
        'roleplay.position': l.positionUtm,
      });

  /// One line per facet, saying what it resolves to (ADR-0067). Keyed by facet
  /// name and asserted complete by [_labelled], so a facet added to
  /// `PlanFieldNames` cannot reach the browser unexplained.
  static Map<String, String> _descriptions(AppLocalizations l) => {
    'plan.name': l.tokenDescPlanName,
    'plan.description': l.tokenDescPlanDescription,
    'plan.exerciseCount': l.tokenDescPlanExerciseCount,
    'plan.teamCount': l.tokenDescPlanTeamCount,
    'plan.stationCount': l.tokenDescPlanStationCount,
    'exercise.name': l.tokenDescExerciseName,
    'exercise.numberOfTeams': l.tokenDescExerciseNumberOfTeams,
    'exercise.numberOfRounds': l.tokenDescExerciseNumberOfRounds,
    'exercise.startTime': l.tokenDescExerciseStartTime,
    'exercise.endTime': l.tokenDescExerciseEndTime,
    'exercise.timeLabel': l.tokenDescExerciseTimeLabel,
    'exercise.durationLabel': l.tokenDescExerciseDurationLabel,
    'exercise.executionTime': l.tokenDescExerciseExecutionTime,
    'exercise.evaluationTime': l.tokenDescExerciseEvaluationTime,
    'exercise.rotationTime': l.tokenDescExerciseRotationTime,
    'exercise.phaseBreakdown': l.tokenDescExercisePhaseBreakdown,
    'exercise.roundTable': l.tokenDescExerciseRoundTable,
    'station.name': l.tokenDescStationName,
    'station.stationCode': l.tokenDescStationCode,
    'station.position': l.tokenDescStationPosition,
    'station.variantSuffix': l.tokenDescStationVariantSuffix,
    'station.duration': l.tokenDescStationDuration,
    'roleplay.name': l.tokenDescRoleplayName,
    'roleplay.age': l.tokenDescRoleplayAge,
    'roleplay.description': l.tokenDescRoleplayDescription,
    'roleplay.position': l.tokenDescRoleplayPosition,
  };

  /// What a facet produces, for the rows whose live value can come back empty.
  ///
  /// Deliberately partial — only a facet that can show nothing needs one — and
  /// deliberately untranslated: every one of these is a shape rather than a
  /// sentence. `roundTable` is the case that forced this to exist at all, since
  /// the editor never holds it: it is assembled when the brief renders.
  static const _examples = <String, String>{
    'exercise.roundTable':
        '| Runde | Øving | Evaluering | Rullering |  |\n'
        '|---|---|---|---|---|\n'
        '| 1 | 0900 | 0915 | 0925 | neste |\n'
        '| 2 | 0930 | 0945 | 0955 | retur |',
    'exercise.phaseBreakdown': '15 | 10 | 5',
    'exercise.timeLabel': '0900–1130',
    'exercise.durationLabel': '2 t (30 min pr oppdrag)',
    'exercise.endTime': '1130',
    'station.position': '32V 0580465E 6551894N',
    'station.stationCode': '1c',
    'station.variantSuffix': 'A',
    'station.duration': '30 min (15 | 10 | 5)',
    'roleplay.position': '32V 0580414E 6552008N',
  };

  /// Which scope a token reads from, shown as the muted hint on its entry.
  ///
  /// The scope nouns the app already has, lowercased to match the hint's muted,
  /// uncapitalised style. Reused rather than four new ARB strings, so the picker
  /// cannot drift from what the rest of the app calls these things.
  static String _scopeHint(AppLocalizations l, PlanFieldScope scope) =>
      switch (scope) {
        PlanFieldScope.plan => l.plan(1),
        PlanFieldScope.exercise => l.exercise(1),
        PlanFieldScope.station => l.station(1),
        PlanFieldScope.roleplay => l.roleplay(1),
      }.toLowerCase();

  /// Pairs [PlanFieldNames.of] with [labels] and [_descriptions], asserting all
  /// three agree.
  ///
  /// The names are the contract (they are what the renderer resolves and what
  /// `analyze` validates); the labels and descriptions are presentation. Building
  /// the list from the names rather than restating them means a facet cannot exist
  /// in the picker without existing in the validator.
  static List<PlanFieldToken> _labelled(
    AppLocalizations l,
    PlanFieldScope scope,
    Map<String, String> labels,
  ) {
    final names = PlanFieldNames.of(scope);
    assert(
      labels.keys.toSet().difference(names.toSet()).isEmpty,
      'labelled facets not in PlanFieldNames.${scope.name}: '
      '${labels.keys.toSet().difference(names.toSet())}',
    );
    // And the other direction, which the doc above always claimed but the
    // assert did not check: `_labelled` falls back to the raw name, so a facet
    // added to `PlanFieldNames` without a label here does not disappear from
    // the picker — it shows up in it as `plan.exerciseCount`, searchable but
    // untranslated. Silent, and therefore worth an assert.
    assert(
      names.toSet().difference(labels.keys.toSet()).isEmpty,
      'PlanFieldNames.${scope.name} facets with no label here: '
      '${names.toSet().difference(labels.keys.toSet())}',
    );
    final descriptions = _descriptions(l);
    // Same check again for the descriptions, for the same reason: a facet with no
    // description would reach the browser as a row that explains nothing, which is
    // the whole thing the browser exists to fix.
    assert(
      names.toSet().difference(descriptions.keys.toSet()).isEmpty,
      'PlanFieldNames.${scope.name} facets with no description here: '
      '${names.toSet().difference(descriptions.keys.toSet())}',
    );
    final hint = _scopeHint(l, scope);
    return [
      for (final name in names)
        PlanFieldToken(
          name: name,
          label: labels[name] ?? name,
          scope: scope,
          description: descriptions[name] ?? '',
          example: _examples[name],
          hint: hint,
        ),
    ];
  }
}
