import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/theme.dart' show kDrillAccentFontSize;
import 'package:ringdrill/views/phase_widget.dart' show PhasesWidget;
import 'package:ringdrill/views/vertical_divider_widget.dart';

/// One row of a round/phase-time table — DESIGN-010 stage 3c: a label cell
/// (round, team, post or station name) followed by the three phase cells
/// (drill/eval/roll), built on [PhasesWidget] so the house "current round"
/// treatment — blueAccent background, white bold text, live progress fill —
/// lives in one place and is shared by every schedule table in the app
/// (coordinator round table, team schedule, Post "Tidsplan", Spill "Når
/// aktiv") as well as [MiniRoundRow] in the drill player mini-bar.
///
/// [muted] marks a row whose entity isn't in use this round (e.g. a post no
/// team visits) — it renders struck-through and never takes the current-round
/// treatment, even if [roundIndex] happens to equal [event]'s running round.
class ScheduleRow extends StatelessWidget {
  const ScheduleRow({
    super.key,
    required this.label,
    required this.event,
    required this.exercise,
    required this.roundIndex,
    this.muted = false,
    this.mainAxisSize = MainAxisSize.max,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.labelWidth,
    this.cellSize = 56.0,
    this.fontSize = kDrillAccentFontSize,
    this.onTap,
  });

  final String label;
  final ExerciseEvent event;
  final Exercise exercise;
  final int roundIndex;

  /// This round is not in use by the row's entity — rendered muted and
  /// struck-through, and never eligible for the current-round treatment.
  final bool muted;

  final MainAxisSize mainAxisSize;
  final MainAxisAlignment mainAxisAlignment;

  /// See `PhaseTile.titleWidth`: `null` sizes the label cell to its text
  /// (rows with similar-length labels, e.g. "Runde 1"/"Runde 2"); non-null
  /// makes it an [Expanded] minimum width so labels of varying length (team
  /// or station names) line up across rows.
  final double? labelWidth;

  /// Width per phase cell — 56 matches the round-table cell width; the
  /// drill-player mini-bar passes a smaller value.
  final double cellSize;

  /// Font size for the label and phase-time text.
  final double fontSize;

  /// Opens the row's detail sheet — omitted (row not tappable) for muted
  /// rows.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCurrent = !muted && event.isRunning && roundIndex == event.currentRound;
    final decoration = muted ? TextDecoration.lineThrough : null;
    final mutedColor = muted ? theme.colorScheme.onSurfaceVariant : null;

    final textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
      color: isCurrent ? Colors.white : mutedColor,
      decoration: decoration,
    );

    final TextPainter painter = TextPainter(
      text: TextSpan(text: label, style: textStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    final phaseCount = exercise.schedule[roundIndex].length;
    final hasFlexibleWidth = labelWidth != null;

    final labelCell = Container(
      height: 32,
      constraints: hasFlexibleWidth
          ? BoxConstraints(minWidth: labelWidth!)
          : BoxConstraints(maxWidth: painter.width + 24),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.blueAccent : Colors.transparent,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          bottomLeft: Radius.circular(4),
        ),
      ),
      child: Align(
        alignment: hasFlexibleWidth
            ? AlignmentDirectional.centerStart
            : Alignment.center,
        child: Text(
          label,
          style: textStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    final row = Row(
      mainAxisSize: mainAxisSize,
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (hasFlexibleWidth)
          Expanded(child: labelCell)
        else
          Flexible(fit: FlexFit.loose, child: labelCell),
        VerticalDividerWidget(isCurrent: isCurrent, isComplete: isCurrent),
        ...List<Widget>.generate(phaseCount, (phaseIndex) {
          final isComplete = isCurrent && phaseIndex < event.phase.index - 1;
          return Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                PhasesWidget(
                  event: event,
                  exercise: exercise,
                  roundIndex: roundIndex,
                  phaseIndex: phaseIndex,
                  decoration: decoration,
                  active: !muted,
                  color: mutedColor,
                  cellSize: cellSize,
                  fontSize: fontSize,
                ),
                if (phaseIndex < phaseCount - 1)
                  VerticalDividerWidget(
                    isCurrent: isCurrent,
                    isComplete: isComplete,
                  ),
              ],
            ),
          );
        }),
      ],
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
