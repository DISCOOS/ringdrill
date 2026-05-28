import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/drill_player/mini_round_row.dart';
import 'package:ringdrill/views/drill_player/phase_colors.dart';
import 'package:ringdrill/views/widgets/exercise_number_badge.dart';
import 'package:ringdrill/views/widgets/live_accent.dart';

class DrillMiniPlayer extends StatefulWidget {
  const DrillMiniPlayer({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  State<DrillMiniPlayer> createState() => _DrillMiniPlayerState();
}

class _DrillMiniPlayerState extends State<DrillMiniPlayer> {
  ExerciseEvent? _event;
  StreamSubscription<ExerciseEvent>? _sub;
  // Per-second ticker interpolates between minute-granular service events so
  // the countdown reads mm:ss and the progress bar moves smoothly.
  // The service still emits per minute — see V1 followup-01 Gap 2.
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _event = ExerciseService().last;
    _sub = ExerciseService().events.listen((event) {
      if (!mounted) return;
      setState(() => _event = event);
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    if (event == null || !ExerciseService().isStarted) {
      return const SizedBox.shrink();
    }

    final localizations = AppLocalizations.of(context)!;
    final phase = event.phase;
    final color = colorForPhase(phase);

    final secondsSinceEvent =
        _now.difference(event.when).inSeconds.clamp(0, 1 << 30);
    final remainingSeconds =
        (event.remainingTime * 60 - secondsSinceEvent).clamp(0, 1 << 30);
    final mm = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (remainingSeconds % 60).toString().padLeft(2, '0');
    final countdown = event.isPending
        ? localizations.drillPlayerStartingInWithCountdown('$mm:$ss')
        : '$mm:$ss';

    final phaseDurationSeconds =
        (event.currentDuration * 60).clamp(1, 1 << 30);
    final smoothedProgress =
        (event.phaseProgress + secondsSinceEvent / phaseDurationSeconds)
            .clamp(0.0, 1.0);

    final accent = LiveAccent.of(context, isLive: true);

    final program = ProgramService().activeProgram;
    final exerciseNumber = program == null
        ? 1
        : program.exercises
                .indexWhere((e) => e.uuid == event.exercise.uuid)
                .clamp(0, 1 << 30) +
            1;

    // The rounded shape is owned by the parent (MainScreen._buildBottomChrome).
    // This Material just fills the clipped area with the LiveAccent background.
    return Material(
      color: accent.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: widget.onOpen,
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  ExerciseNumberBadge(number: exerciseNumber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MiniRoundRow(
                      exercise: event.exercise,
                      event: event,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    countdown,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: accent.foreground,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                  const SizedBox(width: 8),
                  // V2: stop button — see DESIGN-001 "V1 scope" parked list
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 3,
            child: LinearProgressIndicator(
              value: smoothedProgress,
              backgroundColor: color.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
