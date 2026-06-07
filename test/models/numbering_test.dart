import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/numbering.dart';

void main() {
  group('Numbering.alpha', () {
    test('0 → a', () => expect(Numbering.alpha(0), 'a'));
    test('25 → z', () => expect(Numbering.alpha(25), 'z'));
    test('26 → aa (first overflow)', () => expect(Numbering.alpha(26), 'aa'));
    test('27 → ab', () => expect(Numbering.alpha(27), 'ab'));
    test('51 → az', () => expect(Numbering.alpha(51), 'az'));
    test('52 → ba', () => expect(Numbering.alpha(52), 'ba'));
  });

  group('Numbering.exercise', () {
    test('hash format renders #N', () {
      expect(Numbering.exercise(ExerciseNumberFormat.hash, 1), '#1');
      expect(Numbering.exercise(ExerciseNumberFormat.hash, 42), '#42');
    });
  });

  group('Numbering.station — dotted', () {
    test('exercise 1, first station → 1.1', () {
      expect(
        Numbering.station(
          StationNumberFormat.dotted,
          exerciseNumber: 1,
          stationIndex: 0,
        ),
        '1.1',
      );
    });

    test('exercise 3, fifth station → 3.5', () {
      expect(
        Numbering.station(
          StationNumberFormat.dotted,
          exerciseNumber: 3,
          stationIndex: 4,
        ),
        '3.5',
      );
    });
  });

  group('Numbering.station — alpha', () {
    test('exercise 1, first station → 1a', () {
      expect(
        Numbering.station(
          StationNumberFormat.alpha,
          exerciseNumber: 1,
          stationIndex: 0,
        ),
        '1a',
      );
    });

    test('exercise 2, 26th station (index 25) → 2z', () {
      expect(
        Numbering.station(
          StationNumberFormat.alpha,
          exerciseNumber: 2,
          stationIndex: 25,
        ),
        '2z',
      );
    });

    test('exercise 1, 27th station (index 26) → 1aa (overflow)', () {
      expect(
        Numbering.station(
          StationNumberFormat.alpha,
          exerciseNumber: 1,
          stationIndex: 26,
        ),
        '1aa',
      );
    });
  });

  group('Numbering.role — station code + markør number', () {
    test('dotted: exercise 1, station 1, markør 1 → 1.1-1', () {
      expect(
        Numbering.role(
          StationNumberFormat.dotted,
          exerciseNumber: 1,
          stationIndex: 0,
          roleNumber: 1,
        ),
        '1.1-1',
      );
    });

    test('dotted: exercise 1, station 1, markør 2 → 1.1-2', () {
      expect(
        Numbering.role(
          StationNumberFormat.dotted,
          exerciseNumber: 1,
          stationIndex: 0,
          roleNumber: 2,
        ),
        '1.1-2',
      );
    });

    test('alpha: exercise 1, station a, markør 1 → 1a-1', () {
      expect(
        Numbering.role(
          StationNumberFormat.alpha,
          exerciseNumber: 1,
          stationIndex: 0,
          roleNumber: 1,
        ),
        '1a-1',
      );
    });

    test('alpha: exercise 2, station c, markør 3 → 2c-3', () {
      expect(
        Numbering.role(
          StationNumberFormat.alpha,
          exerciseNumber: 2,
          stationIndex: 2,
          roleNumber: 3,
        ),
        '2c-3',
      );
    });
  });
}
