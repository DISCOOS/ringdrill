// exercise_service.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/utils/time_utils.dart';

enum ExercisePhase { pending, execution, evaluation, rotation, done }

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

  /// `true` when the `done` phase was reached automatically because
  /// the exercise expired — either all rounds completed or the
  /// configured `endTime` was reached. `false` for a manual stop and
  /// for every non-`done` event.
  ///
  /// Subscribers (snackbar, persistent notification) use this to tell
  /// "the user pressed stop" apart from "time ran out".
  final bool autoStopped;

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

  String getState(AppLocalizations localizations) {
    return switch (phase) {
      ExercisePhase.pending => localizations.wait,
      ExercisePhase.execution => localizations.drill,
      ExercisePhase.evaluation => localizations.eval,
      ExercisePhase.rotation => localizations.roll,
      ExercisePhase.done => localizations.done,
    }.toUpperCase();
  }

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
    this.autoStopped = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'exercise': exercise.toJson(),
      'phase': phase,
      'when': when.toIso8601String(),
      'elapsedTime': elapsedTime,
      'remainingTime': remainingTime,
      'currentRound': currentRound,
      'phaseProgress': phaseProgress,
      'roundProgress': roundProgress,
      'totalProgress': totalProgress,
      'autoStopped': autoStopped,
    };
  }
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

  bool isStartedOn(String uuid) {
    return isStarted && _exercise?.uuid == uuid;
  }

  bool isStartableOn(String uuid) {
    return exercise == null || _exercise!.uuid == uuid;
  }

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
      // Only process each time a whole minute has passed.
      // NOTE: Compare TimeOfDay by value, not by `.minute > .minute`.
      // `TimeOfDay.now()` has minute granularity, so equality flips exactly
      // once per minute. The previous `minute > minute` check failed at the
      // hour boundary (e.g. 17:59 -> 18:00 gives 0 > 59 = false) and froze
      // the timer permanently for the rest of the run.
      if (force || currentTimeOfDay != _lastTimeOfDay) {
        _lastTimeOfDay = currentTimeOfDay;

        final totalRounds = exercise.numberOfRounds;
        final executionTime = exercise.executionTime;
        final evaluationTime = exercise.evaluationTime;
        final rotationTime = exercise.rotationTime;

        // Total duration of a single round
        final roundTime = executionTime + evaluationTime + rotationTime;
        final totalTime = totalRounds * roundTime;
        final st = _exercise!.startTime.toMaterial();
        final et = _exercise!.endTime.toMaterial();

        final endTime = et.isBefore(st)
            ? et.toDateTime().add(const Duration(days: 1))
            : et.toDateTime();

        // Calculate start date and time
        final startTime = endTime.isBefore(DateTime.now())
            ? st.toDateTime().add(const Duration(days: 1))
            : st.toDateTime();

        final startTimeDelta = currentTimeOfDay
            .toDateTime()
            .difference(startTime)
            .inMinutes;

        if (isPending && startTimeDelta < 0) {
          _totalProgress = 0.0;
          _roundProgress = 0.0;
          _phaseProgress = 0.0;
          // Exercise is pending
          _raise(exercise, startTimeDelta.abs());
        } else {
          _elapsedMinutes = startTimeDelta;

          // Two independent expiry conditions trigger an auto-stop:
          //
          // 1. `_elapsedMinutes >= totalTime` — every round has run
          //    its execution + evaluation + rotation budget. This was
          //    the only auto-stop until now.
          //
          // 2. `now >= endTime` — the wall-clock end of the exercise
          //    has been reached. Whichever condition fires first wins.
          //    Without this, a plan with `endTime` shorter than the
          //    sum of round durations would run past its scheduled end.
          final reachedEndTime = !currentTimeOfDay
              .toDateTime()
              .isBefore(endTime);
          if (_elapsedMinutes >= totalTime || reachedEndTime) {
            // Clamp to `totalTime`: when the endTime branch fires past
            // the scheduled end, `_elapsedMinutes` can be negative
            // (startTime gets rolled to tomorrow). Emitting a negative
            // elapsed time would surface in the notification body and
            // in any future analytics.
            _elapsedMinutes = totalTime;
            _totalProgress = 1.0;
            _roundProgress = 1.0;
            _phaseProgress = 1.0;
            // Mark the stop as automatic so the snackbar and the
            // persistent notification know to fire — a manual stop
            // (user pressed the stop button) does not need those.
            stop(autoStopped: true);
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

          // Calculate total and round progress.
          // _totalProgress is the fraction of the exercise that has elapsed.
          // Previously this divided per-phase remaining by total duration,
          // which produced tiny values that anchored the mini-player's
          // progress strip near the left and never moved meaningfully.
          _roundProgress = minutesInCurrentRound / roundTime;
          _totalProgress = (_elapsedMinutes / totalTime).clamp(0.0, 1.0);

          // Emit the current exercise event
          _raise(_exercise!, remainingTime);
        }
      }
    }
  }

  /// Stop the timer and emit no more events.
  ///
  /// [autoStopped] is `true` when the service stopped itself because
  /// the exercise expired (all rounds completed or `endTime` reached).
  /// Manual callers (the stop button, `start()` re-entry guard) leave
  /// it at the default `false`. The emitted `done` event carries the
  /// flag so listeners can decide between "show a passive snackbar"
  /// (auto) and "stay silent" (manual).
  void stop({bool autoStopped = false}) {
    _timer?.cancel();
    _timer = null;

    if (_exercise != null) {
      _currentPhase = ExercisePhase.done;
      // Emit a stop event with details of the last state
      _raise(_exercise!, 0, autoStopped: autoStopped);
      _exercise = null;
    }
  }

  void _raise(
    Exercise exercise,
    int remainingTime, {
    bool autoStopped = false,
  }) {
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
        autoStopped: autoStopped,
      ),
    );
  }

  /// Clean up resources when not needed
  void dispose() {
    stop();
    _eventController.close();
  }
}
