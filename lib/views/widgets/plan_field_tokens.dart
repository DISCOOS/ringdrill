import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';

/// Single source of truth for the [PlanFieldToken] lists every editor's
/// token picker offers (DESIGN-009 follow-up 4b). Each list mirrors exactly
/// one `refContext` map `brief_renderer.dart` builds — [plan] the
/// `_planRefContext` facets, [exercise] the `_exerciseRefContext` facets
/// — so a token this picker offers is always one the renderer can resolve
/// at that scope. Never add a facet here that isn't already in the
/// matching `refContext` map.
class PlanFieldTokens {
  const PlanFieldTokens._();

  /// Resolvable at plan scope and, via cascade, everywhere below it
  /// (exercise, station, roleplay).
  static List<PlanFieldToken> plan(AppLocalizations l) => [
    PlanFieldToken(name: 'plan.name', label: l.planName),
    PlanFieldToken(name: 'plan.description', label: l.planDescription),
  ];

  /// Resolvable at exercise scope and, via cascade, station/roleplay scope
  /// — but never at plan scope, which has no exercise in context.
  static List<PlanFieldToken> exercise(AppLocalizations l) => [
    PlanFieldToken(name: 'exercise.name', label: l.exerciseName),
    PlanFieldToken(name: 'exercise.numberOfTeams', label: l.numberOfTeams),
    PlanFieldToken(name: 'exercise.numberOfRounds', label: l.numberOfRounds),
    PlanFieldToken(name: 'exercise.startTime', label: l.startTime),
    PlanFieldToken(name: 'exercise.endTime', label: l.endTime),
    PlanFieldToken(name: 'exercise.timeLabel', label: l.timeLabel),
    PlanFieldToken(name: 'exercise.durationLabel', label: l.durationLabel),
    PlanFieldToken(name: 'exercise.executionTime', label: l.executionTime),
    PlanFieldToken(name: 'exercise.evaluationTime', label: l.evaluationTime),
    PlanFieldToken(name: 'exercise.rotationTime', label: l.rotationTime),
    PlanFieldToken(name: 'exercise.phaseBreakdown', label: l.phaseBreakdown),
  ];

  /// Resolvable at station scope and, via cascade, roleplay scope. Omits
  /// `station.description` (DESIGN-009 follow-up 4c): it *is* the free-text
  /// field the author edits in the station's own base section — resolving
  /// through the fixpoint pass, offering it there recurses on itself.
  static List<PlanFieldToken> station(AppLocalizations l) => [
    PlanFieldToken(name: 'station.name', label: l.stationName),
    PlanFieldToken(name: 'station.stationCode', label: l.stationCode),
    PlanFieldToken(name: 'station.position', label: l.positionUtm),
    PlanFieldToken(name: 'station.variantSuffix', label: l.variantSuffix),
  ];

  /// Resolvable at roleplay scope only. `roleplay.name` is self-referential
  /// in the roleplay's own name field the same way `station.description` is
  /// (DESIGN-009 follow-up 4c) — the renderer only substitutes `{{var.*}}`
  /// in that field, never runs the cross-reference pass on it — so the
  /// caller must exclude it from that one field's own `planFields` while
  /// still offering it in the roleplay's other fields (behavior, background,
  /// propsMd). `roleplay.description` has the matching issue in the
  /// description field, but that field is never token-aware in the first
  /// place, so no caller-side filtering is needed for it.
  static List<PlanFieldToken> roleplay(AppLocalizations l) => [
    PlanFieldToken(name: 'roleplay.name', label: l.roleName),
    PlanFieldToken(name: 'roleplay.age', label: l.roleAge),
    PlanFieldToken(name: 'roleplay.description', label: l.roleDescription),
    PlanFieldToken(name: 'roleplay.position', label: l.positionUtm),
  ];
}
