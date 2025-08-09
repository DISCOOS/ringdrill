import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
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
  });

  final String? title;
  final int roundIndex;
  final bool isPortrait;
  final Exercise exercise;
  final ExerciseEvent event;
  final TextDecoration? decoration;
  final MainAxisAlignment mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final isCurrent = event.isRunning && roundIndex == event.currentRound;
    final textStyle = TextStyle(
      fontSize: 18,
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

    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: 32,
          width: painter.width + 24,
          padding: EdgeInsets.only(left: isCurrent ? 8 : 8),
          decoration: BoxDecoration(
            color: isCurrent ? Colors.blueAccent : Colors.transparent,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(4),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: Center(child: Text(name, style: textStyle)),
        ),
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
