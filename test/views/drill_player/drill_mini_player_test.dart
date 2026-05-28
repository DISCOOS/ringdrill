import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/views/drill_player/drill_mini_player.dart';
import 'package:ringdrill/views/drill_player/mini_round_row.dart';
import 'package:ringdrill/views/widgets/exercise_number_badge.dart';

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
    // Exercise name and badges are not visible when stopped
    expect(find.text(exercise.name), findsNothing);
    expect(find.byType(ExerciseNumberBadge), findsNothing);
  });

  testWidgets(
    'shows ExerciseNumberBadge, MiniRoundRow, countdown and play square when running',
    (tester) async {
      ExerciseService().start(exercise);

      await tester.pumpWidget(_harness(onOpen: () {}));
      await tester.pumpAndSettle();

      expect(find.byType(ExerciseNumberBadge), findsOneWidget);
      expect(find.byType(MiniRoundRow), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      // Exercise name intentionally removed from mini-bar layout
      expect(find.text(exercise.name), findsNothing);
      expect(find.byType(InkWell), findsOneWidget);

      // Exercise the per-second ticker; widget must not throw.
      // Countdown is mm:ss when running or drillPlayerStartingIn when pending
      // — exact value depends on wall-clock position relative to fixture start.
      await tester.pump(const Duration(seconds: 2));

      // Stop inside the FakeAsync zone so the periodic timer is cancelled
      // before the framework's pending-timer invariant check.
      ExerciseService().stop();
      await tester.pump();
    },
  );

  testWidgets('onOpen fires when tapped anywhere on the strip', (tester) async {
    ExerciseService().start(exercise);
    var tapped = false;

    await tester.pumpWidget(_harness(onOpen: () => tapped = true));
    await tester.pumpAndSettle();

    // Tap the MiniRoundRow — whole strip is one tap target.
    // warnIfMissed: false because MiniRoundRow is not a hit-test target itself;
    // the enclosing InkWell handles the gesture.
    await tester.tap(find.byType(MiniRoundRow), warnIfMissed: false);
    expect(tapped, isTrue);

    // Reset and tap the play square — must also fire onOpen (not a separate button).
    // warnIfMissed: false because the Container is not a direct hit-test target;
    // the enclosing InkWell handles the gesture.
    tapped = false;
    await tester.tap(find.byIcon(Icons.play_arrow), warnIfMissed: false);
    expect(tapped, isTrue);

    ExerciseService().stop();
    await tester.pump();
  });

  testWidgets('no stop button in V1, play square is a Container not IconButton',
      (tester) async {
    ExerciseService().start(exercise);

    await tester.pumpWidget(_harness(onOpen: () {}));
    await tester.pumpAndSettle();

    // V1 has no stop button
    expect(find.byIcon(Icons.stop), findsNothing);
    expect(find.byIcon(Icons.stop_circle), findsNothing);
    // Play square is a Container, not an interactive button
    expect(find.byType(IconButton), findsNothing);

    ExerciseService().stop();
    await tester.pump();
  });
}
