import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';

/// The exercise the player must stay on, or null when no session is live.
///
/// The single statement of ADR-0056's "cannot switch the live exercise" rule,
/// read by the picker, which then lists only that one. The swipe pager cannot
/// breach it by construction: exercise mode has no sibling sequence at all
/// ([playerSiblingTargets]), so there is nothing to swipe to in any state.
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
/// A single-entry result means "nowhere to swipe", and the host then renders the
/// target on its own — no pager at all, which is both simpler and what makes the
/// player's entry animation clean (a `PageView` laid out during the route's
/// transition settles its offset over the following frames).
///
/// Ordering mirrors the picker's groups exactly, via the same sources, so the
/// row the picker shows next is the page a swipe lands on. Returns a single-entry
/// list when there is nowhere to go, which the pager renders as an unswipeable
/// page.
List<ContextSheetTarget> playerSiblingTargets(ContextSheetTarget target) {
  final service = PlanService();
  switch (target) {
    // The exercise is the player's *root*, not one of a series: the player is
    // scoped to an exercise, and its stations, markers and teams are what you
    // leaf through inside it. Moving to another exercise is a jump between
    // scopes, which belongs to the picker — and it is disallowed outright while
    // one is running. So exercise mode has no sequence, and the host renders it
    // directly rather than wrapping a single view in a pager.
    case ExerciseSheetTarget():
      return [target];
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
