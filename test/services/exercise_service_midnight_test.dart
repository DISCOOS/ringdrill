import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';

/// Starting an exercise that began before midnight must resume it, not wait for
/// the next evening.
///
/// Reported from production: "if an exercise starts 2300 and I start it after
/// midnight, it will wait until 2300 that day, not 1 hour into it". The service
/// rolled the *end* of a midnight-crossing window forward a day and left the start
/// on today, so at 00:30 the start sat 22.5 hours in the future and the drill
/// reported itself pending.
Exercise _nightExercise() => const Exercise(
  uuid: 'ex-night',
  name: 'Night Exercise',
  // 23:00 to 01:00, four half-hour rounds.
  startTime: SimpleTimeOfDay(hour: 23, minute: 0),
  endTime: SimpleTimeOfDay(hour: 1, minute: 0),
  numberOfTeams: 2,
  numberOfRounds: 4,
  executionTime: 20,
  evaluationTime: 5,
  rotationTime: 5,
  stations: [],
  schedule: [],
);

void main() {
  final service = ExerciseService();

  tearDown(() {
    service.stop();
    service.debugNowOverride = DateTime.now;
  });

  test('started after midnight, it is running and 90 minutes in', () {
    service.debugNowOverride = () => DateTime(2026, 7, 29, 0, 30);

    service.start(_nightExercise());
    service.debugForceTick();

    final event = service.last!;
    expect(
      event.isPending,
      isFalse,
      reason: 'the exercise began at 23:00 yesterday; it is running now',
    );
    expect(event.elapsedTime, 90);
  });

  test('started before it begins, it is still pending', () {
    service.debugNowOverride = () => DateTime(2026, 7, 29, 20, 0);

    service.start(_nightExercise());
    service.debugForceTick();

    final event = service.last!;
    expect(
      event.isPending,
      isTrue,
      reason: 'yesterday\'s run has finished; tonight\'s has not begun',
    );
    // Three hours until 23:00.
    expect(event.remainingTime, 180);
  });

  test('a same-day exercise is unaffected', () {
    service.debugNowOverride = () => DateTime(2026, 7, 29, 9, 0);

    service.start(
      _nightExercise().copyWith(
        startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
        endTime: const SimpleTimeOfDay(hour: 11, minute: 0),
      ),
    );
    service.debugForceTick();

    final event = service.last!;
    expect(event.isPending, isFalse);
    expect(event.elapsedTime, 60);
  });
}
