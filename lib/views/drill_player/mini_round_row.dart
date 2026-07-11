import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/views/widgets/schedule_row.dart';

/// Compact round-row mirroring the active row of CoordinatorScreen's round
/// table. Renders via the shared [ScheduleRow] so the canonical state
/// machine (active fill, completed fill, divider flags) is defined once and
/// not reimplemented here.
///
/// The row renders: `R{round+1} | phase0 | phase1 | phase2 | {total} runder`
///
/// When [event.currentRound] is out of range (schedule empty or exhausted)
/// the row renders as [SizedBox.shrink] so [ScheduleRow] is never given an
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

    // Total-rounds label is rendered outside the row so it doesn't inherit
    // the round-row pill geometry.
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScheduleRow(
            label: roundLabel,
            event: event,
            exercise: exercise,
            roundIndex: event.currentRound,
            mainAxisSize: MainAxisSize.min,
            cellSize: 48,
            fontSize: 14,
          ),
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
