import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations_en.dart';
import 'package:ringdrill/l10n/app_localizations_nb.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/utils/exercise_share_format.dart';

void main() {
  group('formatExerciseForShare', () {
    test('matches the agreed Norwegian share format exactly', () {
      // Golden mirrors the format the user signed off on: header,
      // meta line, station list, rotation block. The rotation block
      // itself is locked to the historical manual template observers
      // paste into Slack/Teams today.
      final exercise = _exerciseTwo();
      final actual = formatExerciseForShare(exercise, AppLocalizationsNb());

      const expected = 'Øvelse 2\n'
          '09:30-12:30 | 6 runder | 3 lag | 3 poster\n'
          '\n'
          'Poster\n'
          '1. Stasjon A\n'
          '2. Stasjon B\n'
          '3. Stasjon C\n'
          '\n'
          'Generelt hver runde: 15 | 10 | 5 '
          '(øve | evaluere | rullere / inntransport)\n'
          '\n'
          'Rullering (klokkeslett)\n'
          'Runde 1: 0930 | 0945 | 0955 (neste)\n'
          'Runde 2: 1000 | 1015 | 1025 (neste)\n'
          'Runde 3: 1030 | 1045 | 1055 (neste)\n'
          'Runde 4: 1100 | 1115 | 1125 (neste)\n'
          'Runde 5: 1130 | 1145 | 1155 (neste)\n'
          'Runde 6: 1200 | 1215 | 1225 (retur)';

      expect(actual, expected);
    });

    test('marks last round with rotationShareReturn, others with next', () {
      final exercise = _exerciseTwo();
      final actual = formatExerciseForShare(exercise, AppLocalizationsNb());

      expect(actual, contains('Runde 6: 1200 | 1215 | 1225 (retur)'));
      expect(actual, contains('Runde 1: 0930 | 0945 | 0955 (neste)'));
      // Only one "(retur)" anywhere in the output.
      expect('(retur)'.allMatches(actual).length, 1);
    });

    test('English locale uses translated meta, headers and suffixes', () {
      final exercise = _exerciseTwo();
      final actual = formatExerciseForShare(exercise, AppLocalizationsEn());

      expect(actual.startsWith('Øvelse 2\n'), isTrue);
      expect(actual, contains('6 rounds | 3 teams | 3 stations'));
      expect(actual, contains('\nStations\n1. Stasjon A\n'));
      expect(
        actual,
        contains(
          'Each round: 15 | 10 | 5 (drill | eval | roll / inbound)',
        ),
      );
      expect(actual, contains('Rotation (time of day)'));
      expect(actual, contains('Round 1: 0930 | 0945 | 0955 (next)'));
      expect(actual, contains('Round 6: 1200 | 1215 | 1225 (return)'));
    });

    test('does not end with a trailing newline', () {
      final exercise = _exerciseTwo();
      final actual = formatExerciseForShare(exercise, AppLocalizationsNb());

      // Chat clients show a dangling empty line when the pasted text
      // ends in \n, which observers found ugly in early prototypes.
      expect(actual.endsWith('\n'), isFalse);
    });

    test('station list numbers from 1 and uses station.name verbatim', () {
      final exercise = _exerciseTwo();
      final actual = formatExerciseForShare(exercise, AppLocalizationsNb());

      // The shared text lists stations in declaration order, one per
      // line, with no coordinates. Confirms the deliberate omission
      // documented in the formatter's dartdoc.
      expect(actual, contains('\n1. Stasjon A\n2. Stasjon B\n3. Stasjon C\n'));
      expect(actual, isNot(contains('LatLng')));
    });
  });
}

/// Builds the exact exercise that produced the user's signed-off
/// template: six rounds, 15/10/5 phase split, starting at 09:30, three
/// stations named "Stasjon A/B/C".
Exercise _exerciseTwo() {
  final schedule = <List<SimpleTimeOfDay>>[];
  var startMinutes = 9 * 60 + 30; // 09:30
  for (var r = 0; r < 6; r++) {
    schedule.add([
      SimpleTimeOfDay.fromMinutes(startMinutes), // drill start
      SimpleTimeOfDay.fromMinutes(startMinutes + 15), // eval start
      SimpleTimeOfDay.fromMinutes(startMinutes + 25), // roll start
    ]);
    startMinutes += 30;
  }

  return Exercise(
    uuid: 'exercise-2',
    name: 'Øvelse 2',
    startTime: const SimpleTimeOfDay(hour: 9, minute: 30),
    numberOfTeams: 3,
    numberOfRounds: 6,
    executionTime: 15,
    evaluationTime: 10,
    rotationTime: 5,
    stations: const [
      Station(index: 0, name: 'Stasjon A'),
      Station(index: 1, name: 'Stasjon B'),
      Station(index: 2, name: 'Stasjon C'),
    ],
    schedule: schedule,
    endTime: const SimpleTimeOfDay(hour: 12, minute: 30),
  );
}
