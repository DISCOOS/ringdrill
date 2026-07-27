import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/brief_screen.dart';
import 'package:ringdrill/views/coordinator_screen.dart';
import 'package:ringdrill/views/roleplay_screen.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:ringdrill/views/team_exercise_screen.dart';
import 'package:ringdrill/views/team_screen.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';

sealed class ContextSheetTarget {
  const ContextSheetTarget();
}

/// Returns the exercise UUID associated with [target], if any. Station,
/// team, and role targets resolve to their parent exercise; targets that
/// span a whole plan (team overview, brief) yield null. Used by the
/// docked/embedded mini player and the auto-upgrade-to-fullscreen flow to
/// scope themselves to the selected item's owning exercise.
String? exerciseUuidOf(ContextSheetTarget? target) => switch (target) {
  ExerciseSheetTarget(:final exerciseUuid) => exerciseUuid,
  StationSheetTarget(:final exerciseUuid) => exerciseUuid,
  TeamSheetTarget(:final exerciseUuid) => exerciseUuid,
  RoleSheetTarget(:final rolePlayUuid) =>
    PlanService().getRolePlay(rolePlayUuid)?.exerciseUuid,
  _ => null,
};

class ExerciseSheetTarget extends ContextSheetTarget {
  const ExerciseSheetTarget({required this.exerciseUuid});

  final String exerciseUuid;
}

class StationSheetTarget extends ContextSheetTarget {
  const StationSheetTarget({
    required this.exerciseUuid,
    required this.stationIndex,
  });

  final String exerciseUuid;
  final int stationIndex;
}

class TeamSheetTarget extends ContextSheetTarget {
  const TeamSheetTarget({required this.exerciseUuid, required this.teamIndex});

  final String exerciseUuid;
  final int teamIndex;
}

/// Opens the team across the whole plan ([TeamScreen]), not scoped to a single
/// exercise. Used by the Lag segment and the team deep-link routes: the team's
/// rotation is a per-exercise (player) concept, so a planning-context open
/// shows the multi-exercise overview instead of guessing an exercise.
/// [TeamSheetTarget] stays for the exercise-scoped player view.
class TeamOverviewSheetTarget extends ContextSheetTarget {
  const TeamOverviewSheetTarget({required this.teamIndex});

  final int teamIndex;
}

class RoleSheetTarget extends ContextSheetTarget {
  const RoleSheetTarget({required this.rolePlayUuid});

  final String rolePlayUuid;
}

class BriefSheetTarget extends ContextSheetTarget {
  const BriefSheetTarget({this.planUuid, this.exerciseUuid, this.audience})
    : assert(
        planUuid != null || exerciseUuid != null,
        'planUuid or exerciseUuid must be provided',
      );

  final String? planUuid;
  final String? exerciseUuid;
  final BriefAudience? audience;
}

typedef ContextSheetBodyBuilder =
    Widget Function(BuildContext context, ContextSheetTarget target);

class ContextSheetController {
  ContextSheetController();

  final ValueNotifier<ContextSheetTarget?> _target =
      ValueNotifier<ContextSheetTarget?>(null);
  bool _isOpen = false;
  NavigatorState? _navigator;
  MasterDetailScope? _activeScope;
  ContextSheetBodyBuilder? _bodyBuilder;

  ValueListenable<ContextSheetTarget?> get target => _target;
  ValueNotifier<ContextSheetTarget?> get targetNotifier => _target;

  /// True while a sheet (modal or scope-mode) is presenting a target. Lets
  /// callers — chiefly [openFormSurface] — decide whether to dismiss the
  /// sheet around a form push so the sheet's keyboard-avoidance rebuilds
  /// don't tear down the form's TextInputConnection.
  bool get isOpen => _isOpen;

  /// True iff [isOpen] AND the sheet is presenting as a modal bottom sheet
  /// (not a master-detail scope). Only the modal case causes the keyboard
  /// cascade that breaks text fields on routes pushed above it.
  bool get isModal => _isOpen && _navigator != null;

  /// Adopts [target] as the wide layout's current master-detail selection
  /// without [show]'s modal-vs-scope branching, for callers that only have a
  /// [BuildContext] sitting *above* where [MasterDetailScope] lives (so
  /// `MasterDetailScope.maybeOf` can't find it) — namely `MainScreen`'s
  /// auto-select-first and per-segment selection-memory restore, both of
  /// which write the shared target from their own build/state context
  /// rather than a descendant one.
  ///
  /// Leaves [_activeScope] unset: safe because in the wide layout
  /// `MasterDetailScope`'s own notifier *is* [targetNotifier] (see
  /// `WideShell`'s `MasterDetailScope(target: contextSheetController.
  /// targetNotifier, ...)`), so the notifier write alone updates the detail
  /// pane and a later [replace]'s `_activeScope?.setTarget(...)` no-op costs
  /// nothing. Passing `null` clears the selection (segment has no
  /// remembered pick, or the tab/segment being left behind).
  void adoptWideSelection(ContextSheetTarget? target) {
    _target.value = target;
    _isOpen = target != null;
    _navigator = null;
    _activeScope = null;
  }

  Future<void> show(BuildContext context, ContextSheetTarget target) async {
    if (target is! BriefSheetTarget) {
      final scope = MasterDetailScope.maybeOf(context);
      if (scope != null) {
        scope.setTarget(target);
        _target.value = target;
        _isOpen = true;
        _navigator = null;
        _activeScope = scope;
        _bodyBuilder = ContextSheet._bodyBuilderOf(context) ?? _bodyBuilder;
        return;
      }
      // No MasterDetailScope in this context. If we previously latched onto a
      // scope (wide layout) that has since been torn down — e.g. the window
      // was resized from wide to narrow — the "open" state is stale. Drop it
      // so we fall through to opening a modal sheet instead of silently
      // updating a detail pane that no longer exists.
      if (_activeScope != null) {
        _activeScope = null;
        _isOpen = false;
        _target.value = null;
      }
      // A non-brief target while a *modal* sheet is already open: navigate
      // within it. Gated on `_navigator` so a stale scope-mode `_isOpen`
      // (cleared just above) can't masquerade as an open modal.
      if (_isOpen && _navigator != null) {
        _target.value = target;
        return;
      }
    }
    if (target is BriefSheetTarget) {
      // BriefSheetTarget always opens its own modal surface, even when
      // _isOpen is true (e.g. brief tapped from inside a detail pane in wide
      // layout). Save prior state so the detail pane is fully restored after
      // brief closes.
      final savedTarget = _target.value;
      final savedIsOpen = _isOpen;
      final savedNavigator = _navigator;
      final savedActiveScope = _activeScope;
      final savedBodyBuilder = _bodyBuilder;

      _isOpen = true;
      // Do NOT set _target.value = BriefSheetTarget. The ValueNotifier drives
      // the master-detail detail pane, and MasterDetailScope treats
      // BriefSheetTarget as "no target", which would blank the detail pane.
      // The brief modal builds its body directly from [target] instead.
      _navigator = Navigator.of(context);
      _bodyBuilder = ContextSheet._bodyBuilderOf(context) ?? _bodyBuilder;

      Widget briefBody(
        BuildContext context,
        ScrollController? scrollController,
      ) {
        final child =
            _bodyBuilder?.call(context, target) ??
            _DefaultContextSheetBody(target: target);
        return ContextSheet(
          controller: this,
          bodyBuilder: _bodyBuilder,
          child: scrollController == null
              ? KeyedSubtree(key: ValueKey(target), child: child)
              : PrimaryScrollController(
                  key: ValueKey(target),
                  controller: scrollController,
                  child: child,
                ),
        );
      }

      if (WindowSizeClass.of(context).hasMasterDetail) {
        // Wide layout: a dialog, not a bottom sheet — mirrors every other
        // master/detail surface (showRingdrillPicker, openFormSurface).
        // Sized near-full-bleed rather than the standard 720px form-dialog
        // width, because the brief's own internal TOC sidebar only appears
        // once its body has at least ~900px of width to lay out in (see
        // _ViewerBody's maxBodyWidth: double.infinity case).
        await showRingdrillDialogShell<void>(
          context: context,
          maxWidth: MediaQuery.sizeOf(context).width,
          maxHeightFraction: 0.92,
          builder: (context) => briefBody(context, null),
        );
      } else {
        // Brief uses its own internal wide-layout split (TOC sidebar + body)
        // and benefits from the full sheet width on large screens.
        await showRingdrillViewerSheet<void>(
          context: context,
          maxBodyWidth: double.infinity,
          builder: briefBody,
        );
      }
      // Restore prior state so the detail pane re-appears.
      _target.value = savedTarget;
      _isOpen = savedIsOpen;
      _navigator = savedNavigator;
      _activeScope = savedActiveScope;
      _bodyBuilder = savedBodyBuilder;
      return;
    }

    // Non-brief target with no scope and no open sheet: open a new modal.
    _isOpen = true;
    _target.value = target;
    _navigator = Navigator.of(context);
    _bodyBuilder = ContextSheet._bodyBuilderOf(context) ?? _bodyBuilder;
    // Other targets keep the standard 720px readability cap.
    await showRingdrillViewerSheet<void>(
      context: context,
      maxBodyWidth: 720.0,
      builder: (context, scrollController) => ContextSheet(
        controller: this,
        bodyBuilder: _bodyBuilder,
        child: _ContextSheetHost(
          controller: this,
          scrollController: scrollController,
        ),
      ),
    );
    _target.value = null;
    _isOpen = false;
    _navigator = null;
    _activeScope = null;
    _bodyBuilder = null;
  }

  void replace(ContextSheetTarget target) {
    assert(_isOpen, 'ContextSheetController.replace requires an open sheet');
    _target.value = target;
    _activeScope?.setTarget(target);
  }

  /// Navigates to [target] whether or not a sheet is currently open.
  ///
  /// [replace] alone asserts on a closed sheet, and it has no [BuildContext] to
  /// recover with — which is why it cannot. But its callers can reach a closed
  /// controller legitimately: [ContextSheet.of] falls back to the static
  /// [currentController] when there is no `ContextSheet` ancestor, so a screen
  /// pushed as a plain route (a cold deep link to `/plan/:uuid/exercise/:id`,
  /// say) hands `replace` a controller that was never opened. That is how
  /// picking an exercise in the docked mini player could crash.
  ///
  /// Keeps [replace]'s exact behaviour while open — deliberately *not* just
  /// delegating to [show], which in the wide layout would also re-latch
  /// `_activeScope` and null `_navigator`, losing a modal sitting above a
  /// detail pane.
  Future<void> showOrReplace(
    BuildContext context,
    ContextSheetTarget target,
  ) async {
    if (_isOpen) {
      replace(target);
      return;
    }
    await show(context, target);
  }

  void close() {
    // In master-detail the controller's _isOpen can desync with the UI
    // (e.g. exercise lifecycle events manipulate state without calling
    // close). Always clear an active scope so the detail pane resets.
    if (_activeScope != null) {
      _activeScope!.setTarget(null);
      _target.value = null;
      _isOpen = false;
      _activeScope = null;
      return;
    }
    if (!_isOpen) return;
    _navigator?.pop();
  }

  void dispose() {
    ContextSheet._unregisterController(this);
    _target.dispose();
  }
}

class ContextSheet
    extends InheritedNotifier<ValueNotifier<ContextSheetTarget?>> {
  ContextSheet({
    super.key,
    required ContextSheetController controller,
    required super.child,
    ContextSheetBodyBuilder? bodyBuilder,
  }) : controller = controller,
       bodyBuilder = bodyBuilder,
       super(notifier: controller._target) {
    controller._bodyBuilder = bodyBuilder;
    _registerController(controller);
  }

  final ContextSheetController controller;
  final ContextSheetBodyBuilder? bodyBuilder;
  static final List<ContextSheetController> _controllerStack =
      <ContextSheetController>[];

  static ContextSheetController? get currentController =>
      _controllerStack.isEmpty ? null : _controllerStack.last;

  static ContextSheetController of(BuildContext context) {
    final sheet = context.dependOnInheritedWidgetOfExactType<ContextSheet>();
    final controller = sheet?.controller ?? currentController;
    assert(controller != null, 'No ContextSheet found in context');
    return controller!;
  }

  /// Non-asserting variant. Walks the inherited widget tree without
  /// registering a dependency (so callers don't get rebuilt on target
  /// changes) and returns null when no [ContextSheet] is in scope.
  static ContextSheetController? maybeOf(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<ContextSheet>();
    final sheet = element?.widget as ContextSheet?;
    return sheet?.controller;
  }

  static void _registerController(ContextSheetController controller) {
    _controllerStack.remove(controller);
    _controllerStack.add(controller);
  }

  static void _unregisterController(ContextSheetController controller) {
    _controllerStack.remove(controller);
  }

  static ContextSheetBodyBuilder? _bodyBuilderOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ContextSheet>()
        ?.bodyBuilder;
  }
}

class _ContextSheetHost extends StatelessWidget {
  const _ContextSheetHost({
    required this.controller,
    required this.scrollController,
  });

  final ContextSheetController controller;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ContextSheetTarget?>(
      valueListenable: controller.target,
      builder: (context, target, _) {
        if (target == null) return const SizedBox.shrink();
        final body =
            controller._bodyBuilder?.call(context, target) ??
            _DefaultContextSheetBody(target: target);
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 120),
          child: PrimaryScrollController(
            key: ValueKey(target),
            controller: scrollController,
            child: body,
          ),
        );
      },
    );
  }
}

class _DefaultContextSheetBody extends StatelessWidget {
  const _DefaultContextSheetBody({required this.target});

  final ContextSheetTarget target;

  @override
  Widget build(BuildContext context) {
    final body = switch (target) {
      ExerciseSheetTarget(:final exerciseUuid) => CoordinatorScreen(
        uuid: exerciseUuid,
      ),
      StationSheetTarget(:final exerciseUuid, :final stationIndex) =>
        StationScreen(uuid: exerciseUuid, stationIndex: stationIndex),
      TeamSheetTarget(:final exerciseUuid, :final teamIndex) => _teamBody(
        exerciseUuid,
        teamIndex,
      ),
      TeamOverviewSheetTarget(:final teamIndex) => TeamScreen(
        teamIndex: teamIndex,
      ),
      RoleSheetTarget(:final rolePlayUuid) => RolePlayScreen(
        uuid: rolePlayUuid,
      ),
      BriefSheetTarget(:final exerciseUuid, :final planUuid, :final audience) =>
        BriefSheetBody(
          exerciseUuid: exerciseUuid,
          planUuid: planUuid,
          audience: audience,
        ),
    };
    return body;
  }

  Widget _teamBody(String exerciseUuid, int teamIndex) {
    final exercise = PlanService().getExercise(exerciseUuid);
    if (exercise == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return TeamExerciseScreen(teamIndex: teamIndex, exercise: exercise);
  }
}

Widget defaultContextSheetBody(
  BuildContext context,
  ContextSheetTarget target,
) {
  return _DefaultContextSheetBody(target: target);
}
