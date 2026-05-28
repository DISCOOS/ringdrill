import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/brief_screen.dart';
import 'package:ringdrill/views/roleplay_screen.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:ringdrill/views/team_exercise_screen.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';

sealed class ContextSheetTarget {
  const ContextSheetTarget();
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
    await showRingdrillViewerSheet<void>(
      context: context,
      title: null,
      onClose: close,
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
    if (ContextSheet._currentController == this) {
      ContextSheet._currentController = null;
    }
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
    _currentController = controller;
  }

  final ContextSheetController controller;
  final ContextSheetBodyBuilder? bodyBuilder;
  static ContextSheetController? _currentController;

  static ContextSheetController? get currentController => _currentController;

  static ContextSheetController of(BuildContext context) {
    final sheet = context.dependOnInheritedWidgetOfExactType<ContextSheet>();
    final controller = sheet?.controller ?? _currentController;
    assert(controller != null, 'No ContextSheet found in context');
    return controller!;
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
