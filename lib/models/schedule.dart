/// Rotation-schedule derivation, free of `package:flutter/*`.
///
/// An exercise's `schedule` and `endTime` are pure functions of its
/// `startTime`, `numberOfRounds` and the three phase durations — so they are
/// *derived* fields, not authored ones (DESIGN-014, ADR-0058). This is the one
/// implementation of that derivation. `PlanService.generateSchedule` delegates
/// to it for the app, and the source-format builder
/// (`lib/data/source/plan_builder.dart`) calls it for the CLI, which cannot
/// reach `PlanService` at all: that method's signature is `TimeOfDay`
/// (`package:flutter/material.dart`), which the CLI must not import (AGENTS.md
/// rule 7, ADR-0005).
///
/// Before this file existed the math lived in two places —
/// `PlanService.generateSchedule` and a hand-rolled copy in
/// `tools/generate_example_drills.dart` — and the compiler would have been a
/// third. If you change the phase model here, that is the whole change: there
/// is nothing else to keep in step.
library;

import 'package:ringdrill/models/exercise.dart';

/// The three phase-boundary clock faces of one round.
///
/// `[roundStart, executionEnd, evaluationEnd]` — the rotation window runs from
/// `evaluationEnd` to the next round's `roundStart`, and is therefore implied
/// rather than listed. Stored on `Exercise.schedule` as a
/// `List<List<SimpleTimeOfDay>>` of exactly this shape, which predates this
/// file and is part of the `.drill` wire format (ADR-0007).
typedef RoundPhases = List<SimpleTimeOfDay>;

/// Derives `Exercise.schedule` and `Exercise.endTime`.
class ExerciseSchedule {
  const ExerciseSchedule._();

  /// Phase boundaries for every round, in order.
  ///
  /// Each round occupies `executionTime + evaluationTime + rotationTime`
  /// minutes; within it the boundaries are the round's start, the end of
  /// execution and the end of evaluation. Times wrap at midnight, matching
  /// [SimpleTimeOfDay.fromMinutes] — an exercise that runs past 00:00 is
  /// resolved onto real dates later by `ExerciseX.windowAt`, not here
  /// (DEBT-0013).
  static List<RoundPhases> rounds({
    required SimpleTimeOfDay startTime,
    required int numberOfRounds,
    required int executionTime,
    required int evaluationTime,
    required int rotationTime,
  }) {
    final cycle = executionTime + evaluationTime + rotationTime;
    final start = startTime.inMinutes;
    return [
      for (var round = 0; round < numberOfRounds; round++)
        [
          SimpleTimeOfDay.fromMinutes(start + round * cycle),
          SimpleTimeOfDay.fromMinutes(start + round * cycle + executionTime),
          SimpleTimeOfDay.fromMinutes(
            start + round * cycle + executionTime + evaluationTime,
          ),
        ],
    ];
  }

  /// When the exercise is over: the last round's evaluation end plus the final
  /// rotation.
  ///
  /// The trailing rotation is counted deliberately — the teams still have to
  /// move off the last station — and it is what makes `endTime` equal
  /// `startTime + numberOfRounds * cycle`.
  static SimpleTimeOfDay endTime({
    required SimpleTimeOfDay startTime,
    required int numberOfRounds,
    required int executionTime,
    required int evaluationTime,
    required int rotationTime,
  }) {
    final cycle = executionTime + evaluationTime + rotationTime;
    return SimpleTimeOfDay.fromMinutes(
      startTime.inMinutes + numberOfRounds * cycle,
    );
  }
}
