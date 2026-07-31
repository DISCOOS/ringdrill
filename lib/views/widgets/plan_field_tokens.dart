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

  /// Pairs [PlanFieldNames.of] with [labels], asserting the two agree.
  ///
  /// The names are the contract (they are what the renderer resolves and what
  /// `analyze` validates); the labels are presentation. Building the list from
  /// the names rather than restating them means a facet cannot exist in the
  /// picker without existing in the validator.
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
    final hint = _scopeHint(l, scope);
    return [
      for (final name in names)
        PlanFieldToken(name: name, label: labels[name] ?? name, hint: hint),
    ];
  }
}
