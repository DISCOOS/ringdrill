import 'package:flutter/widgets.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/drill_player_sheet.dart';

/// Owns the "open the immersive DrillPlayer" entry point + the narrow-layout
/// "upgrade from modal ContextSheet to fullscreen DrillPlayer when an
/// exercise starts" behaviour.
///
/// Both pieces lived inline in `MainScreen` and grew together as the player
/// flow evolved. Pulling them out:
/// - keeps the upgrade flag and its single-shot guard next to the open call
///   that clears it,
/// - gives a single seam any other shell ([MainScreen], a future test
///   harness, an alternative entry point) can call into without copying the
///   guard logic.
class DrillPlayerCoordinator {
  DrillPlayerCoordinator();

  // Single-shot guard for the ContextSheet → DrillPlayer upgrade. Set
  // synchronously when we schedule the upgrade and cleared when the
  // DrillPlayer route is dismissed, so the per-minute event tick can't
  // re-pop the drill player as a stale "close the context sheet" action.
  bool _upgrading = false;

  /// Opens the immersive DrillPlayer sheet on [target], defaulting to the
  /// currently-running (or last-known) exercise. No-op when no target is given
  /// and [ExerciseService] has no last event.
  ///
  /// [target] may be a station or a roleplay as readily as an exercise: the
  /// player is a host for any of them (ADR-0056), so an item opened while its
  /// exercise is live enters the player at that item rather than in a sheet
  /// beside it.
  Future<void> openDrillPlayer(
    BuildContext context, {
    ContextSheetTarget? target,
  }) {
    final initial = target ?? _lastExerciseTarget();
    if (initial == null) return Future<void>.value();
    // The player hosts its own ContextSheet, opened on the target it is
    // showing. There is only ever one drill player, so switching target from
    // inside it has to swap this body in place: with a local controller in
    // scope, `ContextSheet.of(...)` inside the player finds an *inline*
    // controller and replaces the target instead of stacking a second player
    // (or a modal sheet) over the first.
    //
    // Registering also makes this the `currentController` while the player
    // lives, and disposing unregisters it, restoring the shell's.
    final controller = ContextSheetController()..adoptInlineTarget(initial);
    return showDrillPlayerSheet<void>(
      context: context,
      builder: (_) => ContextSheet(
        controller: controller,
        child: _DrillPlayerHost(controller: controller),
      ),
    ).whenComplete(controller.dispose);
  }

  ContextSheetTarget? _lastExerciseTarget() {
    final last = ExerciseService().last;
    if (last == null) return null;
    return ExerciseSheetTarget(exerciseUuid: last.exercise.uuid);
  }

  /// Hook called from the host shell's ExerciseService listener.
  ///
  /// When an exercise transitions to started while [controller] is showing
  /// the same exercise (or a station/team/role belonging to it) inside a
  /// modal ContextSheet, the draggable bottom sheet would otherwise stay at
  /// 92% height. We close it and push the fullscreen sheet on top in the
  /// same frame, mirroring the wide-layout onPlay flow.
  ///
  /// Master-detail (wide) callers always have `controller.isModal == false`,
  /// so they fall through untouched.
  void maybeUpgradeOnExerciseEvent({
    required BuildContext context,
    required ContextSheetController controller,
    required ExerciseEvent event,
  }) {
    if (event.isDone || _upgrading) return;
    if (!ExerciseService().isStarted) return;
    if (!controller.isModal) return;
    final targetUuid = exerciseUuidOf(controller.target.value);
    if (targetUuid == null || targetUuid != event.exercise.uuid) return;
    _upgrading = true;
    controller.close();
    openDrillPlayer(context).whenComplete(() {
      _upgrading = false;
    });
  }
}

/// Renders whichever target the player's own [ContextSheetController] points
/// at, rebuilding when it is replaced.
///
/// Uses the same [defaultContextSheetBody] the shell's sheet host and the
/// master/detail pane use, so exercise, station and roleplay are peer *modes*
/// of one player rather than three separate players — and so the player never
/// diverges from what the same target renders as elsewhere.
///
/// Keyed on the target: these screens resolve their entity once, in
/// `initState`, so reusing the element across a target change would keep
/// showing the previous one. [ContextSheetTarget] has no `==`, so every
/// replacement is a distinct key and the subtree remounts.
class _DrillPlayerHost extends StatelessWidget {
  const _DrillPlayerHost({required this.controller});

  final ContextSheetController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ContextSheetTarget?>(
      valueListenable: controller.target,
      builder: (context, target, _) {
        if (target == null) return const SizedBox.shrink();
        return KeyedSubtree(
          key: ValueKey(target),
          child: defaultContextSheetBody(context, target),
        );
      },
    );
  }
}
