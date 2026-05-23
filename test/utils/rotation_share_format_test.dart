import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations_en.dart';
import 'package:ringdrill/l10n/app_localizations_nb.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/utils/rotation_share_format.dart';

void main() {
  group('formatRotationForShare', () {
    test('matches the manual Norwegian share format exactly', () {
      // Golden mirrors the manual template observers paste into Slack/Teams
      // today. Any divergence here is treated as a regression because
      // observers rely on the exact wording, ordering and HHMM spelling.
      final exercise = _exerciseTwo();
      final actual = formatRotationForShare(exercise, AppLocalizationsNb());

      const expected = 'Øvelse 2\n'
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
      final actual = formatRotationForShare(exercise, AppLocalizationsNb());

      expect(actual, contains('Runde 6: 1200 | 1215 | 1225 (retur)'));
      expect(actual, contains('Runde 1: 0930 | 0945 | 0955 (neste)'));
      // Only one "(retur)" anywhere in the output.
      expect('(retur)'.allMatches(actual).length, 1);
    });

    test('English locale uses translated legend and suffixes', () {
      final exercise = _exerciseTwo();
      final actual = formatRotationForShare(exercise, AppLocalizationsEn());

      expect(actual.startsWith('Øvelse 2\n'), isTrue);
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
      final actual = formatRotationForShare(exercise, AppLocalizationsNb());

      // Chat clients show a dangling empty line when the pasted text ends in
      // \n, which observers found ugly in early prototypes.
      expect(actual.endsWith('\n'), isFalse);
    });
  });
}

/// Builds the exact exercise that produced the user's manual template:
/// six rounds, 15/10/5 phase split, starting at 09:30.
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
      Station(index: 0, name: 'Post 1'),
      Station(index: 1, name: 'Post 2'),
      Station(index: 2, name: 'Post 3'),
    ],
    schedule: schedule,
    endTime: const SimpleTimeOfDay(hour: 12, minute: 30),
  );
}
