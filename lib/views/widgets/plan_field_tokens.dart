import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';

/// Single source of truth for the [PlanFieldToken] lists every editor's
/// token picker offers (DESIGN-009 follow-up 4b). Each list mirrors exactly
/// one `refContext` map `brief_renderer.dart` builds — [program] the
/// `_programRefContext` facets, [exercise] the `_exerciseRefContext` facets
/// — so a token this picker offers is always one the renderer can resolve
/// at that scope. Never add a facet here that isn't already in the
/// matching `refContext` map.
class PlanFieldTokens {
  const PlanFieldTokens._();

  /// Resolvable at program scope and, via cascade, everywhere below it
  /// (exercise, station, roleplay).
  static List<PlanFieldToken> program(AppLocalizations l) => [
    PlanFieldToken(name: 'program.name', label: l.programName),
    PlanFieldToken(name: 'program.description', label: l.programDescription),
  ];

  /// Resolvable at exercise scope and, via cascade, station/roleplay scope
  /// — but never at program scope, which has no exercise in context.
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
}
