import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/program_repository.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _station = Station(index: 0, name: 'Post 1');
final _schedule = [
  [
    SimpleTimeOfDay(hour: 9, minute: 0),
    SimpleTimeOfDay(hour: 9, minute: 15),
    SimpleTimeOfDay(hour: 9, minute: 20),
  ],
];
final _end = SimpleTimeOfDay(hour: 9, minute: 22);

Exercise _ex(String uuid, String name, {int index = 0}) => Exercise(
  uuid: uuid,
  index: index,
  name: name,
  startTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 15,
  evaluationTime: 5,
  rotationTime: 2,
  stations: [_station],
  schedule: _schedule,
  endTime: _end,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ProgramRepository._normaliseExerciseOrder', () {
    test('legacy plan (all index 0, n>1) loads in name order with indices 0..n-1', () {
      final items = [
        _ex('c', 'Zebra', index: 0),
        _ex('a', 'Alpha', index: 0),
        _ex('b', 'Mango', index: 0),
      ];
      final result = ProgramRepository.normaliseExerciseOrderForTest(items);
      expect(result.map((e) => e.name).toList(), ['Alpha', 'Mango', 'Zebra']);
      expect(result.map((e) => e.index).toList(), [0, 1, 2]);
    });

    test('valid permutation loads in index order, untouched', () {
      final items = [
        _ex('a', 'Zebra', index: 2),
        _ex('b', 'Alpha', index: 0),
        _ex('c', 'Mango', index: 1),
      ];
      final result = ProgramRepository.normaliseExerciseOrderForTest(items);
      expect(result.map((e) => e.name).toList(), ['Alpha', 'Mango', 'Zebra']);
      // Indices preserved exactly as stored.
      expect(result.map((e) => e.index).toList(), [0, 1, 2]);
    });

    test('hand-edited plan with duplicate indices is renormalised by name', () {
      final items = [
        _ex('a', 'Beta', index: 2),
        _ex('b', 'Alpha', index: 2), // duplicate → invalid
        _ex('c', 'Gamma', index: 2),
      ];
      final result = ProgramRepository.normaliseExerciseOrderForTest(items);
      expect(result.map((e) => e.name).toList(), ['Alpha', 'Beta', 'Gamma']);
      expect(result.map((e) => e.index).toList(), [0, 1, 2]);
    });

    test('hand-edited plan with gaps is renormalised by name', () {
      final items = [
        _ex('a', 'Beta', index: 0),
        _ex('b', 'Alpha', index: 5), // gap → invalid
      ];
      final result = ProgramRepository.normaliseExerciseOrderForTest(items);
      expect(result.map((e) => e.name).toList(), ['Alpha', 'Beta']);
      expect(result.map((e) => e.index).toList(), [0, 1]);
    });

    test('single-exercise plan with index 0 is treated as already valid', () {
      final items = [_ex('a', 'Solo', index: 0)];
      final result = ProgramRepository.normaliseExerciseOrderForTest(items);
      expect(result.length, 1);
      expect(result.first.name, 'Solo');
      expect(result.first.index, 0);
    });

    test('empty list returns empty', () {
      final result = ProgramRepository.normaliseExerciseOrderForTest([]);
      expect(result, isEmpty);
    });
  });
}
