// exercise_service.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/utils/time_utils.dart';

enum ExercisePhase {
  pending('wait'),
  execution('exec'),
  evaluation('eval'),
  rotation('roll'),
  done('done');

  final String abbr;
  const ExercisePhase(this.abbr);
}

class ExerciseEvent {
  final Exercise exercise;
  final ExercisePhase phase;
  final DateTime when;
  final int elapsedTime; // Total elapsed time in seconds
  final int remainingTime; // Remaining time in seconds for the current phase
  final int currentRound;

  int get currentDuration {
    return switch (phase) {
      ExercisePhase.pending => remainingTime.abs(),
      ExercisePhase.execution => exercise.executionTime,
      ExercisePhase.evaluation => exercise.evaluationTime,
      ExercisePhase.rotation => exercise.rotationTime,
      ExercisePhase.done => elapsedTime,
    };
  }

  TimeOfDay get nextTimeOfDay {
    final t = TimeOfDayX.fromMinutes(remainingTime);
    return t;
  }

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
    when: DateTime.now(),
  ); // Current round index (1-based)

  ExerciseEvent({
    required this.when,
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
  TimeOfDay _lastTimeOfDay = TimeOfDay.now();

  int get roundIndex => _roundIndex;
  int get elapsedSeconds => _elapsedMinutes;
  Exercise? get exercise => _exercise;
  ExercisePhase get phase => _currentPhase;

  bool get isStarted => _exercise != null && last?.isDone != true;

  /// Start the timer for the given `Exercise`
  void start(Exercise exercise) {
    stop(); // Ensure no overlapping timers

    _exercise = exercise;
    _elapsedMinutes = 0;
    _roundIndex = 0;
    _last = ExerciseEvent.from(exercise);
    _currentPhase = _last!.phase;

    // Start immediately
    _progress(exercise, true);

    // Schedule periodic updates each second
    // Why each second? Because we need high
    // resolution than minutes to track actual time.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _progress(exercise, false);
    });
  }

  void _progress(Exercise exercise, bool force) {
    final currentTimeOfDay = TimeOfDay.now();
    // Only process each time a whole minute has passed
    if (force || currentTimeOfDay.minute > _lastTimeOfDay.minute) {
      _lastTimeOfDay = currentTimeOfDay;

      final totalRounds = exercise.numberOfRounds;
      final executionTime = exercise.executionTime;
      final evaluationTime = exercise.evaluationTime;
      final rotationTime = exercise.rotationTime;

      // Total duration of a single round
      final roundDuration = executionTime + evaluationTime + rotationTime;

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
          remainingTime =
              executionTime + evaluationTime - minutesInCurrentRound;
        } else {
          _currentPhase = ExercisePhase.rotation;
          remainingTime =
              roundDuration - minutesInCurrentRound; // Remaining rotation time
        }

        // Emit the current exercise event
        _raise(_exercise!, _currentPhase, remainingTime);
      }
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
        when: DateTime.now(),
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
