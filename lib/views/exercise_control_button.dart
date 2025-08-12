import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';

class ExerciseControlButton extends StatelessWidget {
  const ExerciseControlButton({
    super.key,
    required Exercise exercise,
    required ExerciseService service,
    required AppLocalizations localizations,
    this.isFAB = true,
  }) : _service = service,
       _exercise = exercise,
       _localizations = localizations;

  final bool isFAB;
  final Exercise _exercise;
  final ExerciseService _service;
  final AppLocalizations _localizations;

  @override
  Widget build(BuildContext context) {
    final isStarted = _service.isStartedOn(_exercise.uuid);
    final icon = Icon(isStarted ? Icons.stop : Icons.play_arrow);
    final enabled =
        !_service.isStarted ||
        _service.isStarted && _service.isStartableOn(_exercise.uuid);
    return isFAB
        ? FloatingActionButton(
            backgroundColor: enabled
                ? (isStarted ? Colors.redAccent : Colors.greenAccent)
                : Colors.grey.shade300,
            foregroundColor: enabled ? null : Colors.grey.shade400,
            onPressed: () => onPressed(context),
            child: icon,
          )
        : IconButton(
            style: IconButton.styleFrom(
              elevation: 4,
              backgroundColor: isStarted
                  ? Colors.redAccent
                  : Colors.greenAccent,
            ),
            onPressed: enabled ? () => onPressed(context) : null,
            icon: icon,
          );
  }

  void onPressed(BuildContext context) {
    if (!_service.isStartableOn(_exercise.uuid)) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          showCloseIcon: true,
          dismissDirection: DismissDirection.endToStart,
          content: Text(
            _localizations.stopExerciseFirst(_service.exercise!.name),
          ),
        ),
      );
      return;
    }
    if (_service.isStartedOn(_exercise.uuid)) {
      // Stop the exercise
      _service.stop();
    } else {
      // Start the exercise
      _service.start(_exercise);
    }
  }
}
