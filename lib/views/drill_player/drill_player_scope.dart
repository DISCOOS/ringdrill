import 'package:flutter/widgets.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/drill_player/drill_player_coordinator.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';

/// Makes the shell's [DrillPlayerCoordinator] reachable from the planning
/// lists, so tapping an item whose exercise is *live* can enter the player at
/// that item instead of opening a surface beside it (ADR-0056).
///
/// Mounted by `MainScreen` above its [ContextSheet]. Anything outside that
/// subtree — a modal route's body, a cold deep link — finds no scope and falls
/// back to the ordinary sheet flow, which is the correct behaviour there:
/// inside the player the controller is already inline, so `show()` swaps the
/// player's body without needing this at all.
class DrillPlayerScope extends InheritedWidget {
  const DrillPlayerScope({
    super.key,
    required this.coordinator,
    required super.child,
  });

  final DrillPlayerCoordinator coordinator;

  static DrillPlayerCoordinator? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DrillPlayerScope>()
      ?.coordinator;

  @override
  bool updateShouldNotify(DrillPlayerScope oldWidget) =>
      coordinator != oldWidget.coordinator;
}

/// Opens [target] on whichever surface owns it right now: the fullscreen drill
/// player while its exercise is live, the ordinary context sheet otherwise.
///
/// Use this from "the user tapped an item in a planning list" call sites.
/// Deliberately *not* an intercept inside [ContextSheetController.show]:
/// - `showOrReplace`/`replace` would bypass it, so behaviour would depend on
///   which widget was tapped, and `replace` has no [BuildContext] with which to
///   push a route even if it wanted to;
/// - `StationsView` keys its map-detail toggle off its own target and would
///   regress; and
/// - it would invert the dependency direction into a global hook that leaks
///   between tests.
Future<void> openContextTarget(
  BuildContext context,
  ContextSheetTarget target,
) async {
  final coordinator = DrillPlayerScope.maybeOf(context);
  if (coordinator != null && shouldHostInPlayer(context, target)) {
    await coordinator.openDrillPlayer(context, target: target);
    return;
  }
  await ContextSheet.of(context).showOrReplace(context, target);
}

/// Whether [target] belongs in the player rather than in a sheet or detail
/// pane.
///
/// Only the player's declared modes qualify. A brief is a modal surface by
/// definition. A *plan-wide* team ([TeamOverviewSheetTarget]) spans every
/// exercise, so it is not an item of the running one and has no place in a
/// player scoped to it — the exercise-scoped [TeamSheetTarget] is the team mode.
bool shouldHostInPlayer(BuildContext context, ContextSheetTarget target) {
  switch (target) {
    case BriefSheetTarget():
    case TeamOverviewSheetTarget():
      return false;
    case ExerciseSheetTarget():
    case StationSheetTarget():
    case RoleSheetTarget():
    case TeamSheetTarget():
      break;
  }
  final exerciseService = ExerciseService();
  if (!exerciseService.isStarted) return false;
  final uuid = exerciseUuidOf(target);
  if (uuid == null) return false;
  // Only the *running* exercise's own items. A station of some other exercise
  // opens the ordinary surface, so the player never shows something the
  // operator is not actually running.
  if (exerciseService.last?.exercise.uuid != uuid) return false;
  // Uuid equality alone does not rule out a stale target left over from
  // another plan — the entity has to still exist in the active one.
  if (PlanService().getExercise(uuid) == null) return false;
  // Already inside the player: its own controller is inline, and letting
  // showOrReplace swap the body in place is both correct and cheaper than
  // opening a second player over the first.
  if (ContextSheet.maybeOf(context)?.isInline ?? false) return false;
  return true;
}
