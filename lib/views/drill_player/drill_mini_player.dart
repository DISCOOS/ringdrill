import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/views/drill_player/phase_colors.dart';

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
    final icon = iconForPhase(phase);

    final secondsSinceEvent =
        _now.difference(event.when).inSeconds.clamp(0, 1 << 30);
    final remainingSeconds =
        (event.remainingTime * 60 - secondsSinceEvent).clamp(0, 1 << 30);
    final mm = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (remainingSeconds % 60).toString().padLeft(2, '0');
    final countdown =
        event.isPending ? localizations.drillPlayerStartingIn : '$mm:$ss';

    final phaseDurationSeconds = (event.currentDuration * 60).clamp(1, 1 << 30);
    final smoothedProgress = (event.phaseProgress +
            secondsSinceEvent / phaseDurationSeconds)
        .clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: widget.onOpen,
          child: SizedBox(
            height: 53,
            child: Row(
              children: [
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    event.getState(localizations),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  localizations.drillPlayerRoundOf(
                    event.currentRound + 1,
                    event.exercise.numberOfRounds,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.exercise.name,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  countdown,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
                // V2: stop button — see DESIGN-001 "V1 scope" parked list
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
    );
  }
}
