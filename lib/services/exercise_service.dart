// exercise_service.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/utils/time_utils.dart';

enum ExercisePhase {
  pending('WAIT'),
  execution('EXEC'),
  evaluation('EVAL'),
  rotation('ROLL'),
  done('DONE');

  final String abbr;
  const ExercisePhase(this.abbr);
}

class ExerciseEvent {
  final Exercise exercise;
  final ExercisePhase phase;
  final DateTime when;
  final int elapsedTime; // Total elapsed time in seconds
  final int remainingTime; // Remaining time in minutes for the current phase
  final int currentRound;
  final double phaseProgress;
  final double roundProgress;
  final double totalProgress;

  int get currentDuration {
    return switch (phase) {
      ExercisePhase.pending => remainingTime,
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

  static ExerciseEvent pending(Exercise exercise) => ExerciseEvent(
    phase: ExercisePhase.pending,
    exercise: exercise,
    elapsedTime: 0,
    remainingTime: 0,
    currentRound: 0,
    phaseProgress: 0,
    roundProgress: 0,
    totalProgress: 0,
    when: DateTime.now(),
  ); // Current round index (1-based)

  ExerciseEvent({
    required this.when,
    required this.phase,
    required this.exercise,
    required this.elapsedTime,
    required this.remainingTime,
    required this.currentRound,
    required this.phaseProgress,
    required this.roundProgress,
    required this.totalProgress,
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
  double _phaseProgress = 0.0;
  double _roundProgress = 0.0;
  double _totalProgress = 0.0;
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

  bool get isStarted => isPending || isRunning;
  bool get isPending => _exercise != null && last?.isPending == true;
  bool get isRunning => _exercise != null && last?.isRunning == true;

  /// Start the timer for the given `Exercise`
  void start(Exercise exercise) {
    stop(); // Ensure no overlapping timers

    _exercise = exercise;
    _elapsedMinutes = 0;
    _roundIndex = 0;
    _totalProgress = 0.0;
    _roundProgress = 0.0;
    _phaseProgress = 0.0;
    _last = ExerciseEvent.pending(exercise);
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
    if (_exercise != null) {
      final currentTimeOfDay = TimeOfDay.now();
      // Only process each time a whole minute has passed
      if (force || currentTimeOfDay.minute > _lastTimeOfDay.minute) {
        _lastTimeOfDay = currentTimeOfDay;

        final totalRounds = exercise.numberOfRounds;
        final executionTime = exercise.executionTime;
        final evaluationTime = exercise.evaluationTime;
        final rotationTime = exercise.rotationTime;

        // Total duration of a single round
        final roundTime = executionTime + evaluationTime + rotationTime;
        final totalTime = totalRounds * roundTime;

        final endTime =
            _exercise!.endTime.isBefore(_exercise!.startTime)
                ? _exercise!.endTime.toDateTime().add(const Duration(days: 1))
                : _exercise!.endTime.toDateTime();

        // Calculate start date and time
        final startTime =
            endTime.isBefore(DateTime.now())
                ? _exercise!.startTime.toDateTime().add(const Duration(days: 1))
                : _exercise!.startTime.toDateTime();

        final startTimeDelta =
            currentTimeOfDay.toDateTime().difference(startTime).inMinutes;

        if (isPending && startTimeDelta < 0) {
          _totalProgress = 0.0;
          _roundProgress = 0.0;
          _phaseProgress = 0.0;
          // Exercise is pending
          _raise(exercise, startTimeDelta.abs());
        } else {
          _elapsedMinutes = startTimeDelta;

          if (_elapsedMinutes >= totalTime) {
            _totalProgress = 1.0;
            _roundProgress = 1.0;
            _phaseProgress = 1.0;
            // Timer has completed all rounds — end the exercise
            stop();
            return;
          }

          // Determine the current round
          _roundIndex = (_elapsedMinutes ~/ roundTime);

          // Calculate minutes elapsed within the current round
          final minutesInCurrentRound = _elapsedMinutes % roundTime;

          // Calculate progress indicators
          int remainingTime = 0;
          if (minutesInCurrentRound < executionTime) {
            _currentPhase = ExercisePhase.execution;
            remainingTime = executionTime - minutesInCurrentRound;
            if (executionTime < 2) {
              _phaseProgress = remainingTime > 0 ? 0.5 : 1.0;
            } else {
              _phaseProgress = (executionTime - remainingTime) / executionTime;
            }
          } else if (minutesInCurrentRound < (executionTime + evaluationTime)) {
            _currentPhase = ExercisePhase.evaluation;
            remainingTime =
                executionTime + evaluationTime - minutesInCurrentRound;
            if (evaluationTime < 2) {
              _phaseProgress = remainingTime > 0 ? 0.5 : 1.0;
            } else {
              _phaseProgress =
                  (evaluationTime - remainingTime) / evaluationTime;
            }
          } else {
            _currentPhase = ExercisePhase.rotation;
            remainingTime =
                roundTime - minutesInCurrentRound; // Remaining rotation time
            if (rotationTime < 2) {
              _phaseProgress = remainingTime > 0 ? 0.5 : 1.0;
            } else {
              _phaseProgress = (rotationTime - remainingTime) / rotationTime;
            }
          }

          // Calculate total and round progress
          _roundProgress = minutesInCurrentRound / roundTime;
          _totalProgress = remainingTime / totalTime;

          // Emit the current exercise event
          _raise(_exercise!, remainingTime);
        }
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
      _raise(_exercise!, 0);
      _exercise = null;
    }
  }

  void _raise(Exercise exercise, int remainingTime) {
    return _eventController.add(
      _last = ExerciseEvent(
        exercise: exercise,
        when: DateTime.now(),
        phase: _currentPhase,
        elapsedTime: _elapsedMinutes,
        remainingTime: remainingTime,
        currentRound: _roundIndex,
        phaseProgress: _phaseProgress,
        roundProgress: _roundProgress,
        totalProgress: _totalProgress,
      ),
    );
  }

  /// Clean up resources when not needed
  void dispose() {
    stop();
    _eventController.close();
  }
}
