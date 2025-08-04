import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/utils/time_utils.dart';

class PhasesWidget extends StatelessWidget {
  const PhasesWidget({
    super.key,
    required this.event,
    required this.exercise,
    required this.roundIndex,
    required this.phaseIndex,
    this.isPortrait = true,
    this.mainAxisAlignment = MainAxisAlignment.center,
  });

  final int roundIndex;
  final int phaseIndex;
  final bool isPortrait;
  final Exercise exercise;
  final ExerciseEvent event;
  final MainAxisAlignment mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final cellSize =
        phaseIndex < ExercisePhase.rotation.index - 1 ? 56.0 : 52.0;
    final isCurrentRound = event.isRunning && roundIndex == event.currentRound;
    final isCurrentPhase =
        isCurrentRound && phaseIndex == event.phase.index - 1;
    final isComplete = isCurrentRound && event.phase.index > phaseIndex + 1;
    final textStyle = TextStyle(
      fontSize: 18,
      fontWeight:
          isCurrentRound
              ? FontWeight.bold
              : FontWeight.normal, // Emphasize current round
      color:
          isCurrentRound
              ? Colors.white
              : Colors.black, // Contrast for visibility
    );

    final width = cellSize;

    return SizedBox(
      height: 24,
      width: width,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Background progress bar
          SizedBox(
            height: 24,
            width: width,
            child: Container(
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color:
                    isCurrentRound
                        ? Theme.of(context).colorScheme.secondary
                        : Colors.transparent,
                borderRadius:
                    phaseIndex == 2
                        ? BorderRadius.only(
                          topRight: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        )
                        : null,
              ),
            ),
          ),
          SizedBox(
            height: 24,
            width: width,
            child: FractionallySizedBox(
              widthFactor:
                  isComplete
                      ? 1.0
                      : isCurrentPhase
                      ? event.phaseProgress
                      : 0.0,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color:
                      isCurrentRound ? Colors.blueAccent : Colors.transparent,
                  borderRadius:
                      phaseIndex == 2
                          ? BorderRadius.only(
                            topRight: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          )
                          : null,
                ),
              ),
            ),
          ),

          // Phase info
          SizedBox(
            height: 24,
            width: width,
            child: Center(
              child: Text(
                exercise.schedule[roundIndex][phaseIndex].formal(),
                style: textStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
