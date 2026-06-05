import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/theme.dart' show kDrillAccentFontSize;
import 'package:ringdrill/views/phase_widget.dart' show PhasesWidget;
import 'package:ringdrill/views/vertical_divider_widget.dart';

class PhaseTile extends StatelessWidget {
  const PhaseTile({
    super.key,
    required this.title,
    required this.event,
    required this.exercise,
    required this.roundIndex,
    this.decoration,
    this.isPortrait = true,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.titleWidth,
  });

  final String? title;
  final int roundIndex;
  final bool isPortrait;
  final Exercise exercise;
  final ExerciseEvent event;
  final TextDecoration? decoration;
  final MainAxisAlignment mainAxisAlignment;

  /// Behaviour of the title cell:
  ///
  /// * `null` — the cell sizes itself to the text via [TextPainter] (legacy
  ///   behaviour). Fine when every tile in a list has a similar-length
  ///   title (e.g. "Round 1", "Round 2", "Lag 1" — these vary only in the
  ///   last character).
  /// * non-null — the cell uses this value as its **minimum** width and is
  ///   wrapped in [Expanded] so it grows to fill whatever space is left in
  ///   the row after the phase columns. This both (a) makes title cells in
  ///   a list line up vertically because the phase columns end up at the
  ///   same horizontal offset, and (b) uses the full available width
  ///   instead of leaving dead space on the right. Titles longer than the
  ///   available width are ellipsed.
  final double? titleWidth;

  @override
  Widget build(BuildContext context) {
    final isCurrent = event.isRunning && roundIndex == event.currentRound;
    final textStyle = TextStyle(
      fontSize: kDrillAccentFontSize,
      fontWeight:
          isCurrent // Emphasize current round
          ? FontWeight.bold
          : FontWeight.normal,
      color: isCurrent ? Colors.white : null,
      decoration: decoration,
    );

    final name = title ?? '';

    final TextPainter painter = TextPainter(
      text: TextSpan(text: name, style: textStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    final phaseCount = exercise.schedule[roundIndex].length;
    final hasFlexibleWidth = titleWidth != null;

    final titleCell = Container(
      height: 32,
      // In fixed mode, use maxWidth (not width) so the cell can shrink
      // below its natural size when the surrounding row is too narrow to
      // fit title + phase columns (e.g. station detail sheet at 314 px
      // content width). Combined with Flexible(loose) below, the cell
      // renders at painter.width + 24 when there's room and shrinks the
      // Text (already ellipsized) when there isn't.
      constraints: hasFlexibleWidth
          ? BoxConstraints(minWidth: titleWidth!)
          : BoxConstraints(maxWidth: painter.width + 24),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.blueAccent : Colors.transparent,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(4),
          bottomLeft: Radius.circular(4),
        ),
      ),
      // Centered when the cell sizes to text (legacy behaviour) so the
      // text doesn't slide left of the highlight. Left-aligned in the
      // flexible mode so multiple tiles with different title lengths line
      // up cleanly.
      child: Align(
        alignment: hasFlexibleWidth
            ? AlignmentDirectional.centerStart
            : Alignment.center,
        child: Text(
          name,
          style: textStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (hasFlexibleWidth)
          Expanded(child: titleCell)
        else
          // FlexFit.loose lets the title cell stay at its natural width
          // (painter.width + 24) when the row has room, but shrink when
          // the row is too narrow. The phase columns and dividers stay at
          // their fixed widths; only the title gives way.
          Flexible(fit: FlexFit.loose, child: titleCell),
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
  }
}
