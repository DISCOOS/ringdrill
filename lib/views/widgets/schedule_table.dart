import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/views/phase_headers.dart';
import 'package:ringdrill/views/widgets/schedule_row.dart';

/// One row of a [ScheduleTable]: the entity (round/team/post/station) shown
/// at [roundIndex], its display [label], and whether it's [muted] (this
/// round is not in use by the row's entity — rendered struck-through, never
/// current). The actual clock times come from `Exercise.schedule[roundIndex]`
/// via [ScheduleRow]/`PhasesWidget` — this row only carries what the caller
/// already resolved (label, rotation math via `Exercise.teamIndex`/
/// `stationIndex`), not a copy of the schedule data itself.
class ScheduleTableRow {
  const ScheduleTableRow({
    required this.roundIndex,
    required this.label,
    this.muted = false,
    this.onTap,
  });

  final int roundIndex;
  final String label;
  final bool muted;
  final VoidCallback? onTap;
}

/// The one round/phase-time table design shared by the coordinator round
/// table, the team schedule, and the Post/Spill viewers' schedule cards
/// (DESIGN-010 stage 3c): a [PhaseHeaders] header then one [ScheduleRow] per
/// [ScheduleTableRow], all reading the same live-or-pending [event] so the
/// current round gets the house background/progress-fill treatment only
/// while the exercise is actually running.
///
/// [bordered] draws the boxed-table chrome (outer border, per-row
/// separators) the Post/Spill cards use; the live exercise/team tables,
/// already embedded in their own surface, render without it.
class ScheduleTable extends StatelessWidget {
  const ScheduleTable({
    super.key,
    required this.headerLabel,
    required this.rows,
    required this.event,
    required this.exercise,
    this.labelWidth = 90,
    this.bordered = false,
  });

  final String headerLabel;
  final List<ScheduleTableRow> rows;
  final ExerciseEvent event;
  final Exercise exercise;
  final double labelWidth;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = PhaseHeaders(
      title: headerLabel,
      titleWidth: labelWidth,
      mainAxisAlignment: MainAxisAlignment.center,
    );
    final rowWidgets = [
      for (final row in rows)
        ScheduleRow(
          label: row.label,
          event: event,
          exercise: exercise,
          roundIndex: row.roundIndex,
          muted: row.muted,
          onTap: row.onTap,
          labelWidth: labelWidth,
        ),
    ];

    if (!bordered) {
      return Column(
        children: [header, const SizedBox(height: 8), ...rowWidgets],
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          header,
          for (final rowWidget in rowWidgets)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: rowWidget,
            ),
        ],
      ),
    );
  }
}
