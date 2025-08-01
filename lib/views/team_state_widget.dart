import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/views/phase_widget.dart';

class TeamStateWidget extends StatelessWidget {
  const TeamStateWidget({
    super.key,
    required this.event,
    required this.exercise,
    required this.roundIndex,
    required this.teamIndex,
    this.isPortrait = true,
    this.mainAxisAlignment = MainAxisAlignment.center,
  });

  final bool isPortrait;
  final int roundIndex;
  final int teamIndex;
  final Exercise exercise;
  final ExerciseEvent event;
  final MainAxisAlignment mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final isCurrent = event.isRunning && roundIndex == event.currentRound;
    final textStyle = TextStyle(
      fontSize: 18,
      fontWeight:
          isCurrent
              ? FontWeight.bold
              : FontWeight.normal, // Emphasize current round
      color: isCurrent ? Colors.white : Colors.black, // Contrast for visibility
    );

    final name = 'Team ${teamIndex + 1}: ';

    final TextPainter painter = TextPainter(
      text: TextSpan(text: name, style: textStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: mainAxisAlignment,
      children: [
        Container(
          width: painter.width + 6,
          height: 24,
          padding: EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: isCurrent ? Colors.blueAccent : Colors.transparent,
            borderRadius:
                isCurrent
                    ? BorderRadius.only(
                      topLeft: Radius.circular(4),
                      bottomLeft: Radius.circular(4),
                    )
                    : null,
          ),
          child: Text(name, style: textStyle),
        ),
        ...List<Widget>.generate(exercise.schedule[roundIndex].length, (
          phaseIndex,
        ) {
          return PhasesWidget(
            event: event,
            exercise: exercise,
            roundIndex: roundIndex,
            phaseIndex: phaseIndex,
          );
        }),
      ],
    );
  }
}
