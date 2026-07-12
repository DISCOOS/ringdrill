import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/exercise_service.dart';

/// An exercise that spans midnight: starts 23:50, ends 00:10 the next day.
/// A single round whose drill/eval/roll phases fit inside those 20 minutes.
final _overnightExercise = Exercise(
  uuid: 'overnight',
  name: 'Overnight',
  startTime: const SimpleTimeOfDay(hour: 23, minute: 50),
  endTime: const SimpleTimeOfDay(hour: 0, minute: 10),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 5,
  evaluationTime: 3,
  rotationTime: 2,
  stations: const [Station(index: 0, name: 'Station')],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 23, minute: 50),
      SimpleTimeOfDay(hour: 23, minute: 55),
      SimpleTimeOfDay(hour: 23, minute: 58),
    ],
  ],
);

void main() {
  final service = ExerciseService();

  tearDown(() {
    service.stop();
    service.debugNowOverride = DateTime.now;
  });

  test(
    'an overnight exercise keeps a valid currentRound once real time '
    'crosses midnight past its own end, and auto-stops',
    () {
      var now = DateTime(2026, 1, 1, 23, 50);
      service.debugNowOverride = () => now;
      service.start(_overnightExercise);
      expect(service.last!.currentRound, 0);
      expect(service.last!.isRunning, isTrue);

      // Cross midnight, one minute past the exercise's own end (00:10) —
      // the exact moment that used to corrupt `_roundIndex`: re-deriving
      // the exercise's start/end from a moving `DateTime.now()` on every
      // tick flipped the day-rollover decision once "now" moved onto the
      // end's calendar day, pushing `startTime` a further day into the
      // future and making `_elapsedMinutes` (and so `_roundIndex`) a large
      // negative number instead of triggering the end-time auto-stop.
      now = DateTime(2026, 1, 2, 0, 11);
      service.debugForceTick();

      expect(service.last!.currentRound, greaterThanOrEqualTo(0));
      expect(service.last!.currentRound, lessThan(1));
      expect(service.last!.isDone, isTrue);
      expect(service.last!.autoStopped, isTrue);
    },
  );

  test(
    'currentRound never goes out of range for exercise.schedule across a '
    'run, including the tick right before auto-stop',
    () {
      var now = DateTime(2026, 1, 1, 23, 50);
      service.debugNowOverride = () => now;
      service.start(_overnightExercise);

      for (final minutes in [1, 5, 8, 9]) {
        now = DateTime(2026, 1, 1, 23, 50).add(Duration(minutes: minutes));
        service.debugForceTick();
        final round = service.last!.currentRound;
        expect(round, inInclusiveRange(0, _overnightExercise.schedule.length - 1));
      }

      now = DateTime(2026, 1, 2, 0, 15);
      service.debugForceTick();
      expect(service.last!.isDone, isTrue);
    },
  );
}
