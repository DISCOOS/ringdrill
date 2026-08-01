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
  /// Within a round the boundaries are its start, the end of execution and the end
  /// of evaluation; the rotation window runs from there to the next round's start.
  /// Times wrap at midnight, matching [SimpleTimeOfDay.fromMinutes] — an exercise
  /// that runs past 00:00 is resolved onto real dates later by `ExerciseX.windowAt`,
  /// not here (DEBT-0013).
  ///
  /// A round is **as long as the stations live in it** (ADR-0062), which is what
  /// makes rounds able to differ. [executionMinutes] gives each round's execution
  /// length; where every entry is the same this reduces exactly to the old
  /// `startTime + round * cycle`, so a ring route with no station overrides derives
  /// byte-identically to before.
  static List<RoundPhases> roundsFrom({
    required SimpleTimeOfDay startTime,
    required List<int> executionMinutes,
    required int evaluationTime,
    required int rotationTime,
  }) {
    var at = startTime.inMinutes;
    final out = <RoundPhases>[];
    for (final execution in executionMinutes) {
      out.add([
        SimpleTimeOfDay.fromMinutes(at),
        SimpleTimeOfDay.fromMinutes(at + execution),
        SimpleTimeOfDay.fromMinutes(at + execution + evaluationTime),
      ]);
      at += execution + evaluationTime + rotationTime;
    }
    return out;
  }

  /// The uniform case, kept as its own entry point because it is most of them.
  static List<RoundPhases> rounds({
    required SimpleTimeOfDay startTime,
    required int numberOfRounds,
    required int executionTime,
    required int evaluationTime,
    required int rotationTime,
  }) => roundsFrom(
    startTime: startTime,
    executionMinutes: List.filled(numberOfRounds, executionTime),
    evaluationTime: evaluationTime,
    rotationTime: rotationTime,
  );

  /// When the exercise is over: the last round's evaluation end plus the final
  /// rotation.
  ///
  /// The trailing rotation is counted deliberately — the teams still have to
  /// move off the last station.
  static SimpleTimeOfDay endTimeFrom({
    required SimpleTimeOfDay startTime,
    required List<int> executionMinutes,
    required int evaluationTime,
    required int rotationTime,
  }) => SimpleTimeOfDay.fromMinutes(
    startTime.inMinutes +
        executionMinutes.fold<int>(0, (sum, e) => sum + e) +
        executionMinutes.length * (evaluationTime + rotationTime),
  );

  static SimpleTimeOfDay endTime({
    required SimpleTimeOfDay startTime,
    required int numberOfRounds,
    required int executionTime,
    required int evaluationTime,
    required int rotationTime,
  }) => endTimeFrom(
    startTime: startTime,
    executionMinutes: List.filled(numberOfRounds, executionTime),
    evaluationTime: evaluationTime,
    rotationTime: rotationTime,
  );

  /// One execution length per round, from the mode and the stations (ADR-0062).
  ///
  /// * [ExerciseMode.ring] — every station is live in every round, so each round is
  ///   as long as the **longest** of them and all rounds are equal. Unequal stations
  ///   make the whole exercise longer and leave the short ones waiting; they do not
  ///   make the rounds differ.
  /// * [ExerciseMode.together] — a round *is* a station, in list order, so there are
  ///   as many rounds as stations and each takes that station's own time.
  /// * [ExerciseMode.split] — a round is a group of stations running at once, so it
  ///   is as long as the longest station in the group. Groups are taken in order;
  ///   with none declared this degenerates to [ExerciseMode.together].
  ///
  /// [stationMinutes] is each station's effective execution time — its own override
  /// or the exercise's — in station order. [groups] lists, per round, the station
  /// indices live in it; only `split` uses it.
  static List<int> executionMinutesFor({
    required ExerciseMode mode,
    required int numberOfRounds,
    required int executionTime,
    required List<int> stationMinutes,
    List<List<int>> groups = const [],
  }) {
    switch (mode) {
      case ExerciseMode.ring:
        final longest = stationMinutes.isEmpty
            ? executionTime
            : stationMinutes.reduce((a, b) => a > b ? a : b);
        return List.filled(numberOfRounds, longest);
      case ExerciseMode.together:
        if (stationMinutes.isEmpty) {
          return List.filled(numberOfRounds, executionTime);
        }
        return List.of(stationMinutes);
      case ExerciseMode.split:
        if (groups.isEmpty) {
          return executionMinutesFor(
            mode: ExerciseMode.together,
            numberOfRounds: numberOfRounds,
            executionTime: executionTime,
            stationMinutes: stationMinutes,
          );
        }
        return [
          for (final group in groups)
            group
                .where((i) => i >= 0 && i < stationMinutes.length)
                .map((i) => stationMinutes[i])
                .fold<int>(executionTime, (a, b) => a > b ? a : b),
        ];
    }
  }

  /// How many rounds the mode implies, which is not always what was authored.
  ///
  /// In `ring` the author says; in `together` and `split` it follows from the
  /// stations or the groups, and the field is derived rather than obeyed.
  static int roundsForMode({
    required ExerciseMode mode,
    required int numberOfRounds,
    required int numberOfStations,
    int numberOfGroups = 0,
  }) => switch (mode) {
    ExerciseMode.ring => numberOfRounds,
    ExerciseMode.together =>
      numberOfStations > 0 ? numberOfStations : numberOfRounds,
    ExerciseMode.split =>
      numberOfGroups > 0
          ? numberOfGroups
          : (numberOfStations > 0 ? numberOfStations : numberOfRounds),
  };
}
