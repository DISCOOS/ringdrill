import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/vertical_divider_widget.dart';

/// Compact round-row mirroring the active row of CoordinatorScreen's round
/// table. Sized for the mini-bar strip height (32 px) rather than PhaseTile's
/// full-table height. The active-cell treatment (blue background, white bold
/// text) borrows the same visual language as PhaseTile without depending on
/// its constructor.
///
/// The row renders: `R{round+1}/{total} | start0 | start1 | start2`
class MiniRoundRow extends StatelessWidget {
  const MiniRoundRow({
    super.key,
    required this.exercise,
    required this.event,
  });

  final Exercise exercise;
  final ExerciseEvent event;

  @override
  Widget build(BuildContext context) {
    // V2: localize if a target locale needs a different round abbreviation
    final roundLabel =
        'R${event.currentRound + 1}/${exercise.numberOfRounds}';

    // schedule[round] has three entries: execution start, evaluation start,
    // rotation start (indices 0, 1, 2).
    // ExercisePhase enum: pending=0, execution=1, evaluation=2, rotation=3, done=4
    // Active schedule index = phase.index - 1 (execution→0, eval→1, rotation→2)
    final scheduleIndex = event.phase.index - 1;
    final roundSchedule = event.currentRound < exercise.schedule.length
        ? exercise.schedule[event.currentRound]
        : null;

    // No cell highlighted when pending, done, or schedule unavailable.
    final hasActiveCell =
        !event.isPending && !event.isDone && roundSchedule != null;

    Widget phaseCell(int index) {
      final isActive = hasActiveCell && scheduleIndex == index;
      final time = roundSchedule != null && index < roundSchedule.length
          ? roundSchedule[index].toMaterial().formal()
          : '--:--';
      return Container(
        constraints: const BoxConstraints(minWidth: 40),
        alignment: Alignment.center,
        color: isActive ? Colors.blueAccent : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          time,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive
                ? Colors.white
                : Theme.of(context).colorScheme.onPrimaryContainer,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    }

    return SizedBox(
      height: 32,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              roundLabel,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          VerticalDividerWidget(isCurrent: true),
          phaseCell(0),
          VerticalDividerWidget(
            isCurrent: hasActiveCell && scheduleIndex >= 1,
            isComplete: hasActiveCell && scheduleIndex > 1,
          ),
          phaseCell(1),
          VerticalDividerWidget(
            isCurrent: hasActiveCell && scheduleIndex >= 2,
            isComplete: false,
          ),
          phaseCell(2),
        ],
      ),
    );
  }
}
