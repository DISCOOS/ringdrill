import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/brief_screen.dart';
import 'package:ringdrill/views/coordinator_screen.dart';
import 'package:ringdrill/views/roleplay_screen.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:ringdrill/views/team_exercise_screen.dart';
import 'package:ringdrill/views/team_screen.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';

sealed class ContextSheetTarget {
  const ContextSheetTarget();
}

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
  const BriefSheetTarget({this.programUuid, this.exerciseUuid, this.audience})
    : assert(
        programUuid != null || exerciseUuid != null,
        'programUuid or exerciseUuid must be provided',
      );

  final String? programUuid;
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
      // BriefSheetTarget always opens its own modal sheet, even when _isOpen is
      // true (e.g. brief tapped from inside a detail pane in wide layout).
      // Save prior state so the detail pane is fully restored after brief closes.
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
      // Brief uses its own internal wide-layout split (TOC sidebar + body) and
      // benefits from the full sheet width on large screens.
      await showRingdrillViewerSheet<void>(
        context: context,
        maxBodyWidth: double.infinity,
        builder: (context, scrollController) => ContextSheet(
          controller: this,
          bodyBuilder: _bodyBuilder,
          child: PrimaryScrollController(
            key: ValueKey(target),
            controller: scrollController,
            child: _bodyBuilder?.call(context, target) ??
                _DefaultContextSheetBody(target: target),
          ),
        ),
      );
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
      ExerciseSheetTarget(:final exerciseUuid) => _ExerciseSheetBody(
        exerciseUuid: exerciseUuid,
      ),
      StationSheetTarget(:final exerciseUuid, :final stationIndex) =>
        StationExerciseScreen(uuid: exerciseUuid, stationIndex: stationIndex),
      TeamSheetTarget(:final exerciseUuid, :final teamIndex) => _teamBody(
        exerciseUuid,
        teamIndex,
      ),
      TeamOverviewSheetTarget(:final teamIndex) => TeamScreen(
        teamIndex: teamIndex,
      ),
      RoleSheetTarget(:final rolePlayUuid) => RolePlayScreen(
        rolePlayUuid: rolePlayUuid,
      ),
      BriefSheetTarget(
        :final exerciseUuid,
        :final programUuid,
        :final audience,
      ) =>
        BriefSheetBody(
          exerciseUuid: exerciseUuid,
          programUuid: programUuid,
          audience: audience,
        ),
    };
    return body;
  }

  Widget _teamBody(String exerciseUuid, int teamIndex) {
    final exercise = ProgramService().getExercise(exerciseUuid);
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

/// Wraps [CoordinatorScreen] for an [ExerciseSheetTarget] and auto-closes
/// the [ContextSheet] when the exercise transitions to live, so the
/// DrillMiniPlayer in MainScreen becomes visible without a manual close.
class _ExerciseSheetBody extends StatefulWidget {
  const _ExerciseSheetBody({required this.exerciseUuid});

  final String exerciseUuid;

  @override
  State<_ExerciseSheetBody> createState() => _ExerciseSheetBodyState();
}

class _ExerciseSheetBodyState extends State<_ExerciseSheetBody> {
  StreamSubscription<ExerciseEvent>? _sub;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _sub = ExerciseService().events.listen((event) {
      if (!mounted || _closed) return;
      if (event.exercise.uuid == widget.exerciseUuid &&
          ExerciseService().isStarted) {
        // In master-detail the coordinator stays in the detail pane when the
        // exercise starts. Closing would clear the scope target and prevent
        // the play bar from reappearing when the exercise stops.
        if (MasterDetailScope.maybeOf(context) != null) return;
        _closed = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ContextSheet.of(context).close();
        });
      }
    });
    // Guard against the race where the exercise is already live when the
    // sheet opens (e.g. deep-link into a running exercise).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _closed) return;
      final last = ExerciseService().last;
      if (last != null &&
          last.exercise.uuid == widget.exerciseUuid &&
          ExerciseService().isStarted) {
        if (MasterDetailScope.maybeOf(context) != null) return;
        _closed = true;
        ContextSheet.of(context).close();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CoordinatorScreen(uuid: widget.exerciseUuid);
  }
}
