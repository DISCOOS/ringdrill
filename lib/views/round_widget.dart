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
          width: painter.width + 16,
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
        ...List<Widget>.generate(phaseCount, (phaseIndex) {
          return Row(
            children: [
              PhasesWidget(
                event: event,
                exercise: exercise,
                roundIndex: roundIndex,
                phaseIndex: phaseIndex,
              ),
              if (phaseIndex < phaseCount - 1) Text(' | '),
            ],
          );
        }),
      ],
    );
  }
}
