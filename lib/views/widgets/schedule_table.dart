import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/theme.dart' show kDrillAccentFontSize;
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
///
/// [fillWidth] is the one width mode shared by the header and every row:
/// `true` (the default — the Post/Spill cards' existing look) grows the
/// title/label cell to fill the surrounding width; `false` shrink-wraps the
/// whole table to its content width, the way the coordinator round table
/// looked before it moved onto this shared widget. Driving both `PhaseHeaders`
/// and every `ScheduleRow` from the same flag keeps the header bar and the
/// rows — and their phase columns — the same width in either mode.
class ScheduleTable extends StatelessWidget {
  const ScheduleTable({
    super.key,
    required this.headerLabel,
    required this.rows,
    required this.event,
    required this.exercise,
    this.labelWidth = 90,
    this.cellSize = 56.0,
    this.bordered = false,
    this.fillWidth = true,
  });

  final String headerLabel;
  final List<ScheduleTableRow> rows;
  final ExerciseEvent event;
  final Exercise exercise;
  final double labelWidth;

  /// Width per phase column — shared by the header and every row so the
  /// DRILL/EVAL/ROLL header cells line up with the actual phase-time cells
  /// underneath them. `PhaseHeaders` and `ScheduleRow` each default to a
  /// different `cellSize` on their own (62 vs 56); passing the same value to
  /// both here is what keeps a shrink-wrapped table's header and rows at the
  /// same content width.
  final double cellSize;
  final bool bordered;
  final bool fillWidth;

  /// In shrink-wrap mode, `ScheduleRow`'s label cell auto-sizes to each
  /// row's own text — by design (`MiniRoundRow` relies on the same
  /// behaviour for its compact "R1" label) — so it can end up wider than a
  /// row label like "Runde 1"/"Runde 2" the header's fixed [labelWidth]
  /// never has to accommodate on its own (the header only ever shows
  /// [headerLabel], e.g. "Runde"). A row also spends 3 `VerticalDividerWidget`s
  /// (label|phase0|phase1|phase2) the header never renders. Widening the
  /// header's title cell to the widest row label plus that same divider
  /// budget (never narrower than [labelWidth]) keeps the header bar at
  /// least as wide as every row without forcing the rows into a fixed
  /// width of their own and losing that auto-fit.
  double _shrinkTitleWidth() {
    const dividerWidth = 8.0; // VerticalDividerWidget's default width
    const dividerCount = 3; // leading + between phase0/1 + between phase1/2
    var widestLabel = labelWidth;
    const style = TextStyle(
      fontSize: kDrillAccentFontSize,
      fontWeight: FontWeight.bold,
    );
    for (final row in rows) {
      final painter = TextPainter(
        text: TextSpan(text: row.label, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      final width = painter.width + 24;
      if (width > widestLabel) widestLabel = width;
    }
    return widestLabel + dividerCount * dividerWidth;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = PhaseHeaders(
      title: headerLabel,
      titleWidth: fillWidth ? labelWidth : _shrinkTitleWidth(),
      cellSize: cellSize,
      mainAxisAlignment: MainAxisAlignment.center,
      expandTitle: fillWidth,
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
          labelWidth: fillWidth ? labelWidth : null,
          mainAxisSize: fillWidth ? MainAxisSize.max : MainAxisSize.min,
          cellSize: cellSize,
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
