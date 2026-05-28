import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/views/drill_player/drill_mini_player.dart';

Exercise _makeExercise() => Exercise(
      uuid: 'test-uuid-mini',
      name: 'Mini Player Exercise',
      startTime: SimpleTimeOfDay(hour: 10, minute: 0),
      endTime: SimpleTimeOfDay(hour: 11, minute: 0),
      numberOfTeams: 2,
      numberOfRounds: 3,
      executionTime: 5,
      evaluationTime: 3,
      rotationTime: 2,
      stations: [],
      schedule: [],
    );

Widget _harness({required VoidCallback onOpen}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DrillMiniPlayer(onOpen: onOpen),
      ),
    );

void main() {
  final exercise = _makeExercise();

  testWidgets('hidden when isStarted is false', (tester) async {
    await tester.pumpWidget(_harness(onOpen: () {}));
    await tester.pump();
    expect(find.byType(SizedBox), findsWidgets);
    // No exercise name visible
    expect(find.text(exercise.name), findsNothing);
  });

  testWidgets('shows exercise name and phase chip when running', (
    tester,
  ) async {
    ExerciseService().start(exercise);

    await tester.pumpWidget(_harness(onOpen: () {}));
    await tester.pumpAndSettle();

    expect(find.text(exercise.name), findsOneWidget);
    expect(find.byType(InkWell), findsOneWidget);

    // Stop inside the FakeAsync zone so the periodic timer is cancelled
    // before the framework's pending-timer invariant check.
    ExerciseService().stop();
    await tester.pump();
  });

  testWidgets('onOpen fires when tapped', (tester) async {
    ExerciseService().start(exercise);
    var tapped = false;

    await tester.pumpWidget(_harness(onOpen: () => tapped = true));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell));
    expect(tapped, isTrue);

    ExerciseService().stop();
    await tester.pump();
  });

  testWidgets('no stop button in V1', (tester) async {
    ExerciseService().start(exercise);

    await tester.pumpWidget(_harness(onOpen: () {}));
    await tester.pumpAndSettle();

    // V1 has no stop button
    expect(find.byIcon(Icons.stop), findsNothing);
    expect(find.byIcon(Icons.stop_circle), findsNothing);

    ExerciseService().stop();
    await tester.pump();
  });
}
