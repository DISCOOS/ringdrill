// The one place that knows how to say who is at a station in a round (ADR-0062).
//
// Thirteen call sites used to format this themselves from `teamIndex`, which returns
// one team because a ring route only ever has one. The formatting is here now, so the
// modes are got right once.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/round_occupancy.dart';

Exercise _exercise({
  required ExerciseMode mode,
  int numberOfTeams = 4,
  int stations = 4,
  List<ExerciseGroup> groups = const [],
}) => Exercise(
  uuid: 'e',
  name: 'E',
  startTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 11, minute: 0),
  numberOfTeams: numberOfTeams,
  numberOfRounds: stations,
  executionTime: 15,
  evaluationTime: 10,
  rotationTime: 5,
  mode: mode,
  groups: groups,
  stations: [for (var i = 0; i < stations; i++) Station(index: i, name: 'S$i')],
  schedule: const [],
);

void main() {
  late AppLocalizations l;
  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('numbers', () {
    test('one-based, because every other team label in the app is', () {
      expect(RoundOccupancy.numbers([0]), '1');
    });

    test('nobody is × — the label the schedule rows already used', () {
      expect(RoundOccupancy.numbers([]), '×');
    });

    test('a pair reads as a pair, not a range', () {
      // "1–2" and "1,2" cost the same width and the comma is plainer.
      expect(RoundOccupancy.numbers([0, 1]), '1,2');
    });

    test('a contiguous run collapses to a range', () {
      // The `together` case: every team on one station. "1–6" fits where
      // "1,2,3,4,5,6" does not.
      expect(RoundOccupancy.numbers([0, 1, 2, 3, 4, 5]), '1–6');
    });

    test('gaps split into several parts', () {
      expect(RoundOccupancy.numbers([0, 1, 3]), '1,2,4');
      expect(RoundOccupancy.numbers([0, 1, 2, 5, 6, 7]), '1–3,6–8');
    });

    test('unsorted input still reads in order', () {
      // An authored group's teams are in whatever order the author placed them.
      expect(RoundOccupancy.numbers([3, 0, 2, 1]), '1–4');
    });
  });

  group('label', () {
    test('ring: one team per station, as before', () {
      final exercise = _exercise(mode: ExerciseMode.ring);
      expect(RoundOccupancy.label(l, exercise, 0, 0), '${l.team(1)} 1');
      expect(RoundOccupancy.label(l, exercise, 1, 0), '${l.team(1)} 2');
    });

    test('ring: a station no team has reached reads ×', () {
      // Three teams, four stations: one position is empty every round.
      final exercise = _exercise(mode: ExerciseMode.ring, numberOfTeams: 3);
      final labels = [
        for (var s = 0; s < 4; s++) RoundOccupancy.label(l, exercise, s, 0),
      ];
      expect(labels.where((t) => t.endsWith('×')), hasLength(1));
    });

    test('together: every team on the round station, nobody on the others', () {
      final exercise = _exercise(mode: ExerciseMode.together, stations: 2);
      expect(RoundOccupancy.label(l, exercise, 0, 0), '${l.team(1)} 1–4');
      expect(RoundOccupancy.label(l, exercise, 1, 0), '${l.team(1)} ×');
      // Round 2 is the second station.
      expect(RoundOccupancy.label(l, exercise, 1, 1), '${l.team(1)} 1–4');
    });

    test('split: the authored assignment, uneven groups included', () {
      // 2 + 1 + 1 across three stations, which is the mockup's own example.
      final exercise = _exercise(
        mode: ExerciseMode.split,
        stations: 3,
        groups: const [
          ExerciseGroup(
            stations: [
              GroupSlot(stationIndex: 0, teams: [0, 1]),
              GroupSlot(stationIndex: 1, teams: [2]),
              GroupSlot(stationIndex: 2, teams: [3]),
            ],
          ),
        ],
      );
      expect(RoundOccupancy.label(l, exercise, 0, 0), '${l.team(1)} 1,2');
      expect(RoundOccupancy.label(l, exercise, 1, 0), '${l.team(1)} 3');
      expect(RoundOccupancy.label(l, exercise, 2, 0), '${l.team(1)} 4');
    });
  });

  group('isActive', () {
    test('true only where somebody is', () {
      final exercise = _exercise(mode: ExerciseMode.together, stations: 2);
      expect(RoundOccupancy.isActive(exercise, 0, 0), isTrue);
      expect(RoundOccupancy.isActive(exercise, 1, 0), isFalse);
    });
  });

  group('stationOf', () {
    test('ring: the rotation position', () {
      final exercise = _exercise(mode: ExerciseMode.ring);
      expect(RoundOccupancy.stationOf(exercise, 0, 0), 0);
      expect(RoundOccupancy.stationOf(exercise, 0, 1), 1);
    });

    test('split: null for a team held back, never -1', () {
      // -1 has been rendering as station "0" and indexing one before the first
      // station wherever a caller added 1 without checking.
      final exercise = _exercise(
        mode: ExerciseMode.split,
        stations: 2,
        groups: const [
          ExerciseGroup(
            stations: [
              GroupSlot(stationIndex: 0, teams: [0, 1]),
            ],
          ),
        ],
      );
      expect(RoundOccupancy.stationOf(exercise, 0, 0), 0);
      expect(RoundOccupancy.stationOf(exercise, 3, 0), isNull);
    });
  });
}
