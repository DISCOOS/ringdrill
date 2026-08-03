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
import 'package:ringdrill/models/station.dart';

/// The three phase-boundary clock faces of one round.
///
/// `[roundStart, executionEnd, evaluationEnd]` — the rotation window runs from
/// `evaluationEnd` to the next round's `roundStart`, and is therefore implied
/// rather than listed. Stored on `Exercise.schedule` as a
/// `List<List<SimpleTimeOfDay>>` of exactly this shape, which predates this
/// file and is part of the `.drill` wire format (ADR-0007).
typedef RoundPhases = List<SimpleTimeOfDay>;

/// The three phase *lengths* in minutes, as opposed to [RoundPhases]' clock faces.
///
/// Describes a station's own timing and a round's timing with one type on purpose:
/// deriving the second from the first is the whole of [ExerciseSchedule.phaseMinutesFor],
/// and a round in `together` mode simply *is* a station's phases.
typedef PhaseMinutes = ({int execution, int evaluation, int rotation});

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
  /// makes rounds able to differ. [minutes] gives each round's three phase lengths;
  /// where every entry is the same this reduces exactly to the old
  /// `startTime + round * cycle`, so a ring route with no station overrides derives
  /// byte-identically to before.
  static List<RoundPhases> roundsFrom({
    required SimpleTimeOfDay startTime,
    required List<PhaseMinutes> minutes,
  }) {
    var at = startTime.inMinutes;
    final out = <RoundPhases>[];
    for (final round in minutes) {
      out.add([
        SimpleTimeOfDay.fromMinutes(at),
        SimpleTimeOfDay.fromMinutes(at + round.execution),
        SimpleTimeOfDay.fromMinutes(at + round.execution + round.evaluation),
      ]);
      at += round.execution + round.evaluation + round.rotation;
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
    minutes: List.filled(numberOfRounds, (
      execution: executionTime,
      evaluation: evaluationTime,
      rotation: rotationTime,
    )),
  );

  /// When the exercise is over: the last round's evaluation end plus the final
  /// rotation.
  ///
  /// The trailing rotation is counted deliberately — the teams still have to
  /// move off the last station.
  static SimpleTimeOfDay endTimeFrom({
    required SimpleTimeOfDay startTime,
    required List<PhaseMinutes> minutes,
  }) => SimpleTimeOfDay.fromMinutes(
    minutes.fold<int>(
      startTime.inMinutes,
      (at, round) => at + round.execution + round.evaluation + round.rotation,
    ),
  );

  static SimpleTimeOfDay endTime({
    required SimpleTimeOfDay startTime,
    required int numberOfRounds,
    required int executionTime,
    required int evaluationTime,
    required int rotationTime,
  }) => endTimeFrom(
    startTime: startTime,
    minutes: List.filled(numberOfRounds, (
      execution: executionTime,
      evaluation: evaluationTime,
      rotation: rotationTime,
    )),
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
  }) => phaseMinutesFor(
    mode: mode,
    numberOfRounds: numberOfRounds,
    fallback: (execution: executionTime, evaluation: 0, rotation: 0),
    stationMinutes: [
      for (final m in stationMinutes)
        (execution: m, evaluation: 0, rotation: 0),
    ],
    groups: groups,
  ).map((round) => round.execution).toList();

  /// Each station's effective timing, in station order: its own overrides where it has
  /// them, [fallback] — the exercise's — where it does not.
  ///
  /// Here rather than at the two call sites (`PlanService.generateSchedule` and the
  /// source builder) because resolving an override is part of the phase model, and the
  /// app and the CLI must not be able to resolve it differently.
  static List<PhaseMinutes> stationMinutesFrom({
    required List<Station> stations,
    required PhaseMinutes fallback,
  }) => [
    for (final station in stations)
      (
        execution: station.executionTime ?? fallback.execution,
        evaluation: station.evaluationTime ?? fallback.evaluation,
        rotation: station.rotationTime ?? fallback.rotation,
      ),
  ];

  /// All three phase lengths per round, from the mode and the stations.
  ///
  /// The generalisation of [executionMinutesFor] to every phase a station can own: a
  /// long post, a long debrief, and a long walk off it are the same kind of fact, and
  /// each resolves per mode the same way.
  ///
  /// * [ExerciseMode.ring] — every station is live in every round, so each phase is as
  ///   long as the **longest** station's, and all rounds are equal. Teams rotate
  ///   together, so nobody leaves before the slowest walk is done; a station with a
  ///   short phase waits rather than moving on.
  /// * [ExerciseMode.together] — a round *is* a station, so it takes that station's
  ///   own three, rotation included: the walk out of station 3 is round 3's rotation.
  /// * [ExerciseMode.split] — a round is a group running at once, so each phase is the
  ///   longest in that group.
  ///
  /// Each phase is maximised independently, which is the only honest reading: the post
  /// that runs longest is not necessarily the one furthest from the next.
  ///
  /// [stationMinutes] is each station's effective timing — its own overrides or
  /// [fallback], the exercise's — in station order. [groups] lists, per round, the
  /// station indices live in it; only `split` uses it.
  static List<PhaseMinutes> phaseMinutesFor({
    required ExerciseMode mode,
    required int numberOfRounds,
    required PhaseMinutes fallback,
    required List<PhaseMinutes> stationMinutes,
    List<List<int>> groups = const [],
  }) {
    switch (mode) {
      case ExerciseMode.ring:
        if (stationMinutes.isEmpty) {
          return List.filled(numberOfRounds, fallback);
        }
        // No floor: every entry is already a station's *effective* timing, so if they
        // all override downward the round shortens with them. Flooring at the
        // exercise's value would keep teams standing at a post nobody needs.
        return List.filled(numberOfRounds, _longest(stationMinutes, null));
      case ExerciseMode.together:
        if (stationMinutes.isEmpty) {
          return List.filled(numberOfRounds, fallback);
        }
        return List.of(stationMinutes);
      case ExerciseMode.split:
        if (groups.isEmpty) {
          return phaseMinutesFor(
            mode: ExerciseMode.together,
            numberOfRounds: numberOfRounds,
            fallback: fallback,
            stationMinutes: stationMinutes,
          );
        }
        return [
          for (final group in groups)
            _groupPhases(group, stationMinutes, fallback),
        ];
    }
  }

  /// One `split` round: the longest of each phase among the stations running in it.
  ///
  /// [fallback] is used **only** when the group names no station that exists — a stale
  /// index survives a station being deleted, and the round still has to have a length.
  /// It is deliberately not a floor: a group whose stations all set a phase *below* the
  /// exercise's must shorten with them, exactly as `ring` does. Flooring it kept a
  /// group with `rotationTime: 0` waiting out the exercise's default rotation, which
  /// made `endTime` disagree with the round table by those minutes.
  static PhaseMinutes _groupPhases(
    List<int> group,
    List<PhaseMinutes> stationMinutes,
    PhaseMinutes fallback,
  ) {
    final live = [
      for (final i in group)
        if (i >= 0 && i < stationMinutes.length) stationMinutes[i],
    ];
    return live.isEmpty ? fallback : _longest(live, null);
  }

  /// Phase-by-phase maximum.
  ///
  /// [floor] seeds the fold, so a group that names no station in range still yields
  /// something; pass null where the caller has already guaranteed [of] is not empty and
  /// a floor would be wrong.
  static PhaseMinutes _longest(Iterable<PhaseMinutes> of, PhaseMinutes? floor) {
    var longest = floor;
    for (final round in of) {
      final soFar = longest;
      longest = soFar == null
          ? round
          : (
              execution: soFar.execution > round.execution
                  ? soFar.execution
                  : round.execution,
              evaluation: soFar.evaluation > round.evaluation
                  ? soFar.evaluation
                  : round.evaluation,
              rotation: soFar.rotation > round.rotation
                  ? soFar.rotation
                  : round.rotation,
            );
    }
    return longest!;
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
