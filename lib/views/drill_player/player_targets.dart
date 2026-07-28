import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';

/// The exercise the player must stay on, or null when no session is live.
///
/// The single statement of ADR-0056's "cannot switch the live exercise" rule.
/// Both surfaces that could move the player between exercises read it — the
/// picker (which then lists only that one) and the swipe pager (whose exercise
/// sequence then has one entry, so there is nothing to swipe to). Keeping it in
/// one place is deliberate: the last time this rule lived in a single surface,
/// widening another one silently became a way around it.
String? lockedExerciseUuid() {
  final service = ExerciseService();
  if (!service.isStarted) return null;
  return service.last?.exercise.uuid;
}

/// The ordered peers of [target] within its own kind — the sequence a swipe in
/// the player moves along.
///
/// Deliberately *within* kind: the picker's list spans kinds, so paging through
/// it flat would cross a boundary and change the player's mode mid-gesture. A
/// swipe moves between siblings; changing kind stays an explicit act (the picker,
/// or tapping content).
///
/// Ordering mirrors the picker's groups exactly, via the same sources, so the
/// row the picker shows next is the page a swipe lands on. Returns a single-entry
/// list when there is nowhere to go, which the pager renders as an unswipeable
/// page.
List<ContextSheetTarget> playerSiblingTargets(ContextSheetTarget target) {
  final service = PlanService();
  switch (target) {
    case ExerciseSheetTarget():
      final locked = lockedExerciseUuid();
      if (locked != null) {
        return [ExerciseSheetTarget(exerciseUuid: locked)];
      }
      final exercises = service.activePlan?.exercises ?? const <Exercise>[];
      if (exercises.isEmpty) return [target];
      return [
        for (final exercise in exercises)
          ExerciseSheetTarget(exerciseUuid: exercise.uuid),
      ];
    case StationSheetTarget(:final exerciseUuid):
      final stations = service.getExercise(exerciseUuid)?.stations ?? const [];
      if (stations.isEmpty) return [target];
      return [
        for (final station in stations)
          StationSheetTarget(
            exerciseUuid: exerciseUuid,
            stationIndex: station.index,
          ),
      ];
    case RoleSheetTarget(:final rolePlayUuid):
      final parent = service.getRolePlay(rolePlayUuid)?.exerciseUuid;
      if (parent == null) return [target];
      final roles = service.rolePlaysOf(parent);
      if (roles.isEmpty) return [target];
      return [
        for (final role in roles) RoleSheetTarget(rolePlayUuid: role.uuid),
      ];
    case TeamSheetTarget(:final exerciseUuid):
      final count = service.getExercise(exerciseUuid)?.numberOfTeams ?? 0;
      if (count <= 0) return [target];
      return [
        for (var index = 0; index < count; index++)
          TeamSheetTarget(exerciseUuid: exerciseUuid, teamIndex: index),
      ];
    // Not player modes (ADR-0056), so they have no sibling sequence.
    case TeamOverviewSheetTarget():
    case BriefSheetTarget():
      return [target];
  }
}

/// Where [target] sits in [siblings], or 0 when it is not found — a target whose
/// entity was deleted while the player was showing it still has to render
/// somewhere, and its own screen owns the gone-state message.
int playerSiblingIndex(
  List<ContextSheetTarget> siblings,
  ContextSheetTarget target,
) {
  final index = siblings.indexWhere((s) => sameTarget(s, target));
  return index < 0 ? 0 : index;
}
