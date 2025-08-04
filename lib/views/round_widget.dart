import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/views/phase_widget.dart';

class RoundWidget extends StatelessWidget {
  const RoundWidget({
    super.key,
    required this.event,
    required this.exercise,
    required this.roundIndex,
    this.isPortrait = true,
    this.mainAxisAlignment = MainAxisAlignment.center,
  });

  final int roundIndex;
  final bool isPortrait;
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

    final name =
        '${AppLocalizations.of(context)!.round(1)} ${roundIndex + 1}: ';

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
          width: painter.width + 8,
          height: 32,
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
                ),
                if (phaseIndex < phaseCount - 1)
                  Container(
                    height: 32,
                    width: 8,
                    color:
                        isCurrent
                            ? (isComplete
                                ? Colors.blueAccent
                                : Theme.of(context).colorScheme.secondary)
                            : Colors.transparent,
                    child: Center(
                      child: Text('|', style: isCurrent ? textStyle : null),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
