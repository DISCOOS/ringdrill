import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/utils/time_utils.dart';

/// A [SimpleTimeOfDay] is a clock face with no date, so a window that crosses
/// midnight is ambiguous until anchored. Anchoring on *today* produced two bugs:
///
/// - Starting a 23:00 exercise at 00:30 waited 22.5 hours rather than resuming 90
///   minutes in — the old code pushed the *end* to tomorrow and left the start on
///   today, so "now" fell before a window it was actually inside.
/// - The plan list read "20:15 - 01:15 | 19 timer", the duration computed across
///   one calendar day: 24h minus the real 5h.
Exercise _exercise({
  required SimpleTimeOfDay start,
  required SimpleTimeOfDay end,
}) => Exercise(
  uuid: 'ex-window',
  name: 'Window',
  startTime: start,
  endTime: end,
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [],
  schedule: const [],
);

void main() {
  group('a window inside one day', () {
    final exercise = _exercise(
      start: const SimpleTimeOfDay(hour: 8, minute: 0),
      end: const SimpleTimeOfDay(hour: 11, minute: 0),
    );

    test('resolves onto the reference day', () {
      final window = exercise.windowAt(DateTime(2026, 7, 29, 9));

      expect(window.start, DateTime(2026, 7, 29, 8));
      expect(window.end, DateTime(2026, 7, 29, 11));
    });

    test('before it starts, it is still today', () {
      final window = exercise.windowAt(DateTime(2026, 7, 29, 6));

      expect(window.start, DateTime(2026, 7, 29, 8));
    });

    test('duration is the plain difference', () {
      expect(exercise.scheduledDuration, const Duration(hours: 3));
    });
  });

  group('a window crossing midnight', () {
    final exercise = _exercise(
      start: const SimpleTimeOfDay(hour: 23, minute: 0),
      end: const SimpleTimeOfDay(hour: 1, minute: 0),
    );

    test('the end rolls to the next day', () {
      final window = exercise.windowAt(DateTime(2026, 7, 29, 23, 30));

      expect(window.start, DateTime(2026, 7, 29, 23));
      expect(window.end, DateTime(2026, 7, 30, 1));
    });

    // The reported bug: started after midnight, the exercise waited for that
    // evening's 23:00 instead of resuming 90 minutes in.
    test('started after midnight, it resumes rather than waiting a day', () {
      final window = exercise.windowAt(DateTime(2026, 7, 29, 0, 30));

      expect(
        window.start,
        DateTime(2026, 7, 28, 23),
        reason: 'the 23:00 it is 90 minutes into began yesterday',
      );
      expect(window.end, DateTime(2026, 7, 29, 1));
      expect(
        DateTime(2026, 7, 29, 0, 30).difference(window.start),
        const Duration(minutes: 90),
      );
    });

    // The other half: genuinely before tonight's run, it must still wait.
    test('earlier the same evening, it is still pending', () {
      final window = exercise.windowAt(DateTime(2026, 7, 29, 20));

      expect(
        window.start,
        DateTime(2026, 7, 29, 23),
        reason: 'yesterday\'s occurrence has finished; the next one is tonight',
      );
    });

    // Past the end of yesterday's run but before tonight's.
    test('after yesterday ended, the window is the upcoming one', () {
      final window = exercise.windowAt(DateTime(2026, 7, 29, 2));

      expect(window.start, DateTime(2026, 7, 29, 23));
      expect(window.end, DateTime(2026, 7, 30, 1));
    });

    test('duration counts the midnight crossing', () {
      expect(exercise.scheduledDuration, const Duration(hours: 2));
    });
  });

  test('the reported 20:15-01:15 reads as five hours, not nineteen', () {
    final exercise = _exercise(
      start: const SimpleTimeOfDay(hour: 20, minute: 15),
      end: const SimpleTimeOfDay(hour: 1, minute: 15),
    );

    expect(exercise.scheduledDuration, const Duration(hours: 5));
  });

  // The label the bug was reported through, end to end.
  group('the plan list label', () {
    test('a midnight-crossing exercise reads its real length', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final exercise = _exercise(
        start: const SimpleTimeOfDay(hour: 20, minute: 15),
        end: const SimpleTimeOfDay(hour: 1, minute: 15),
      );

      expect(exercise.scheduledDuration.formal(l10n), l10n.hour(5));
    });

    test('a same-day exercise is unchanged', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final exercise = _exercise(
        start: const SimpleTimeOfDay(hour: 8, minute: 0),
        end: const SimpleTimeOfDay(hour: 11, minute: 0),
      );

      expect(exercise.scheduledDuration.formal(l10n), l10n.hour(3));
    });
  });
}
