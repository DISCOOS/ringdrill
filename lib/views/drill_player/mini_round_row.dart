import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/views/phase_widget.dart';
import 'package:ringdrill/views/vertical_divider_widget.dart';

/// Compact round-row mirroring the active row of CoordinatorScreen's round
/// table. Reuses [PhasesWidget] so completed phases stay fully filled and
/// the canonical state machine (active fill, completed fill, divider flags)
/// is not reimplemented here.
///
/// The row renders: `R{round+1} | phase0 | phase1 | phase2 | {total} runder`
///
/// When [event.currentRound] is out of range (schedule empty or exhausted)
/// the row renders as [SizedBox.shrink] so [PhasesWidget] is never given an
/// invalid roundIndex.
class MiniRoundRow extends StatelessWidget {
  const MiniRoundRow({super.key, required this.exercise, required this.event});

  final Exercise exercise;
  final ExerciseEvent event;

  @override
  Widget build(BuildContext context) {
    // Guard: PhasesWidget accesses exercise.schedule[roundIndex] directly.
    // Short-circuit if the schedule hasn't been built yet (e.g. during tests
    // with an empty schedule fixture or before the service computes it).
    if (event.currentRound >= exercise.schedule.length) {
      return const SizedBox.shrink();
    }

    final localizations = AppLocalizations.of(context)!;
    // V2: localize if a target locale needs a different round abbreviation
    final roundLabel = 'R${event.currentRound + 1}';

    final isCurrentRound =
        event.isRunning && event.currentRound < exercise.schedule.length;

    // Mirrors PhaseTile's structure: title cell carries the rounded LEFT
    // edge and the active-round fill, a single leading divider sits between
    // title and phase 0, dividers between phases use the same isComplete
    // rules, and there is NO trailing divider after phase 2 (the rounded
    // RIGHT edge lives on PhasesWidget for phaseIndex == 2). The total
    // rounds label is rendered outside this row so it doesn't inherit the
    // round-row pill geometry.
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title cell — rounded LEFT, filled blueAccent when running on
          // the current round (same treatment as PhaseTile's title cell).
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: isCurrentRound ? Colors.blueAccent : Colors.transparent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Center(
              child: Text(
                roundLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isCurrentRound ? Colors.white : null,
                ),
              ),
            ),
          ),
          // Single leading divider between title and phase 0 (matches PhaseTile)
          VerticalDividerWidget(
            isCurrent: isCurrentRound,
            isComplete: isCurrentRound,
          ),
          PhasesWidget(
            event: event,
            exercise: exercise,
            roundIndex: event.currentRound,
            phaseIndex: 0,
            cellSize: 48,
            fontSize: 14,
          ),
          // Divider between phase 0 and phase 1: complete when past execution
          VerticalDividerWidget(
            isCurrent: isCurrentRound,
            isComplete: isCurrentRound && 0 < event.phase.index - 1,
          ),
          PhasesWidget(
            event: event,
            exercise: exercise,
            roundIndex: event.currentRound,
            phaseIndex: 1,
            cellSize: 48,
            fontSize: 14,
          ),
          // Divider between phase 1 and phase 2: complete when past evaluation
          VerticalDividerWidget(
            isCurrent: isCurrentRound,
            isComplete: isCurrentRound && 1 < event.phase.index - 1,
          ),
          PhasesWidget(
            event: event,
            exercise: exercise,
            roundIndex: event.currentRound,
            phaseIndex: 2,
            cellSize: 48,
            fontSize: 14,
          ),
          // No trailing divider — phase 2 already carries the rounded RIGHT
          // edge via PhasesWidget. Total-rounds label sits outside the pill.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${exercise.numberOfRounds} ${localizations.round(exercise.numberOfRounds).toLowerCase()}',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
