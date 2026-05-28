import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/brief_screen.dart';
import 'package:ringdrill/views/coordinator_screen.dart';
import 'package:ringdrill/views/roleplay_screen.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:ringdrill/views/team_exercise_screen.dart';
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
  ContextSheetBodyBuilder? _bodyBuilder;

  ValueListenable<ContextSheetTarget?> get target => _target;

  Future<void> show(BuildContext context, ContextSheetTarget target) async {
    if (_isOpen) {
      _target.value = target;
      return;
    }
    _isOpen = true;
    _target.value = target;
    _navigator = Navigator.of(context);
    _bodyBuilder = ContextSheet._bodyBuilderOf(context) ?? _bodyBuilder;
    // Brief uses its own internal wide-layout split (TOC sidebar + body) and
    // benefits from the full sheet width on large screens. Other targets keep
    // the standard 720px readability cap from _ViewerBody.
    final maxBodyWidth = target is BriefSheetTarget ? double.infinity : 720.0;
    await showRingdrillViewerSheet<void>(
      context: context,
      maxBodyWidth: maxBodyWidth,
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
    _bodyBuilder = null;
  }

  void replace(ContextSheetTarget target) {
    assert(_isOpen, 'ContextSheetController.replace requires an open sheet');
    _target.value = target;
  }

  void close() {
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
