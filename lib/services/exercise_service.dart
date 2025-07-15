// exercise_service.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';

enum ExercisePhase { pending, execution, evaluation, rotation, done }

class ExerciseEvent {
  final Exercise exercise;
  final ExercisePhase phase;
  final int elapsedTime; // Total elapsed time in seconds
  final int remainingTime; // Remaining time in seconds for the current phase
  final int currentRound;

  String get state => phase.name;
  bool get isRunning => !(isDone || isPending);
  bool get isPending => phase == ExercisePhase.pending;
  bool get isDone => phase == ExercisePhase.done;

  static ExerciseEvent from(Exercise exercise) => ExerciseEvent(
    phase:
        TimeOfDay.now().difference(exercise.startTime).isNegative
            ? ExercisePhase.pending
            : ExercisePhase.done,
    exercise: exercise,
    elapsedTime: 0,
    remainingTime: 0,
    currentRound: 0,
  ); // Current round index (1-based)

  ExerciseEvent({
    required this.phase,
    required this.exercise,
    required this.elapsedTime,
    required this.remainingTime,
    required this.currentRound,
  });
}

class ExerciseService {
  static final ExerciseService _instance = ExerciseService._internal();

  factory ExerciseService() => _instance;

  ExerciseService._internal();

  final StreamController<ExerciseEvent> _eventController =
      StreamController<ExerciseEvent>.broadcast();
  Timer? _timer;

  Exercise? _exercise;
  int _elapsedMinutes = 0; // Tracks total elapsed time
  int _roundIndex = 0; // Current round (0-based index)
  ExercisePhase _currentPhase = ExercisePhase.execution;

  /// Expose stream of `ExerciseEvent`s
  Stream<ExerciseEvent> get events => _eventController.stream;

  ExerciseEvent? get last => _last;
  ExerciseEvent? _last;

  int get roundIndex => _roundIndex;
  int get elapsedSeconds => _elapsedMinutes;
  Exercise? get exercise => _exercise;
  ExercisePhase get phase => _currentPhase;

  /// Start the timer for the given `Exercise`
  void start(Exercise exercise) {
    stop(); // Ensure no overlapping timers

    _exercise = exercise;
    _elapsedMinutes = 0;
    _roundIndex = 0;
    _last = ExerciseEvent.from(exercise);
    _currentPhase = _last!.phase;

    // Start imitatively
    _progress(exercise);

    // Schedule periodic updates
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _progress(exercise);
    });
  }

  void _progress(Exercise exercise) {
    final totalRounds = exercise.numberOfRounds;
    final executionTime = exercise.executionTime;
    final evaluationTime = exercise.evaluationTime;
    final rotationTime = exercise.rotationTime;

    // Total duration of a single round
    final roundDuration = executionTime + evaluationTime + rotationTime;

    final currentTimeOfDay = TimeOfDay.now();
    final totalRemainingTime = currentTimeOfDay.difference(
      _exercise!.startTime,
    );

    if (totalRemainingTime.isNegative) {
      _raise(exercise, phase, totalRemainingTime.inMinutes);
    } else {
      _elapsedMinutes = totalRemainingTime.inMinutes;

      // Determine the current round
      _roundIndex = (_elapsedMinutes ~/ roundDuration);

      if (_roundIndex >= totalRounds) {
        // Timer has completed all rounds — end the exercise
        stop();
        return;
      }

      // Calculate seconds elapsed within the current round
      final minutesInCurrentRound = _elapsedMinutes % roundDuration;

      // Determine the phase (execution, evaluation, rotation) and remaining time for the phase
      int remainingTime = 0;
      if (minutesInCurrentRound < executionTime) {
        _currentPhase = ExercisePhase.execution;
        remainingTime = executionTime - minutesInCurrentRound;
      } else if (minutesInCurrentRound < (executionTime + evaluationTime)) {
        _currentPhase = ExercisePhase.evaluation;
        remainingTime = executionTime + evaluationTime - minutesInCurrentRound;
      } else {
        _currentPhase = ExercisePhase.rotation;
        remainingTime =
            roundDuration - minutesInCurrentRound; // Remaining rotation time
      }

      // Emit the current exercise event
      _raise(_exercise!, _currentPhase, remainingTime);
    }
  }

  /// Stop the timer and emit no more events
  void stop() {
    _timer?.cancel();
    _timer = null;

    if (_exercise != null) {
      _currentPhase = ExercisePhase.done;
      // Emit a stop event with details of the last state
      _raise(_exercise!, _currentPhase, 0);
      _exercise = null;
    }
  }

  void _raise(Exercise exercise, ExercisePhase phase, int remainingTime) {
    return _eventController.add(
      _last = ExerciseEvent(
        exercise: exercise,
        phase: _currentPhase,
        elapsedTime: _elapsedMinutes,
        remainingTime: remainingTime,
        currentRound: _roundIndex,
      ),
    );
  }

  /// Clean up resources when not needed
  void dispose() {
    stop();
    _eventController.close();
  }
}
