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
      // Use a fixture that is reliably in the running phase regardless of
      // wall-clock time (start 5 minutes in the past).
      final now = DateTime.now();
      final pastMinutes = now.hour * 60 + now.minute - 5;
      final runningExercise = Exercise(
        uuid: 'test-uuid-running-ring',
        name: 'Running Ring Exercise',
        startTime: SimpleTimeOfDay(
          hour: ((pastMinutes % 1440 + 1440) % 1440 ~/ 60),
          minute: ((pastMinutes % 1440 + 1440) % 1440 % 60),
        ),
        endTime: SimpleTimeOfDay(
          hour: (now.hour + 1) % 24,
          minute: now.minute,
        ),
        numberOfTeams: 2,
        numberOfRounds: 2,
        executionTime: 10,
        evaluationTime: 5,
        rotationTime: 5,
        stations: [],
        schedule: [],
      );
      ExerciseService().start(runningExercise);

      await tester.pumpWidget(_harness(onOpen: () {}));
      // Use pump() not pumpAndSettle() — CircularProgressIndicator spins forever
      await tester.pump();

      expect(find.byType(ExerciseNumberBadge), findsOneWidget);
      expect(find.byType(MiniRoundRow), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      // Exercise name intentionally removed from mini-bar layout
      expect(find.text(runningExercise.name), findsNothing);
      expect(find.byType(InkWell), findsOneWidget);

      // Running state shows a spinning CircularProgressIndicator ring
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Exercise the per-second ticker; widget must not throw.
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
    // Use pump() not pumpAndSettle() — ring animation never settles
    await tester.pump();

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

  testWidgets('pending state shows "Starts in mm:ss" countdown', (tester) async {
    // Build a fixture whose startTime is 5 minutes in the future so the
    // service always emits a pending event regardless of when the test runs.
    final now = DateTime.now();
    final futureMinutes = now.hour * 60 + now.minute + 5;
    final pendingExercise = Exercise(
      uuid: 'test-uuid-pending',
      name: 'Pending Exercise',
      startTime: SimpleTimeOfDay(
        hour: (futureMinutes ~/ 60) % 24,
        minute: futureMinutes % 60,
      ),
      endTime: SimpleTimeOfDay(
        hour: ((futureMinutes ~/ 60) + 1) % 24,
        minute: futureMinutes % 60,
      ),
      numberOfTeams: 2,
      numberOfRounds: 2,
      executionTime: 5,
      evaluationTime: 3,
      rotationTime: 2,
      stations: [],
      schedule: [],
    );

    ExerciseService().start(pendingExercise);
    await tester.pumpWidget(_harness(onOpen: () {}));
    // Use pump() not pumpAndSettle() — _PulsingRing animation never settles
    await tester.pump();

    // The mini-bar must be visible (exercise is started)
    expect(find.byType(ExerciseNumberBadge), findsOneWidget);

    // Countdown must include the "Starts in" prefix followed by mm:ss.
    expect(find.textContaining('Starts in'), findsOneWidget);
    final countdownText = tester
        .widget<Text>(find.textContaining('Starts in').first)
        .data!;
    expect(countdownText, matches(RegExp(r'^Starts in \d{2}:\d{2}$')));

    // Exercise the per-second ticker — widget must not throw.
    await tester.pump(const Duration(seconds: 2));

    ExerciseService().stop();
    await tester.pump();
  });

  testWidgets('running state shows phase label before countdown', (tester) async {
    // Build a fixture whose startTime is 5 minutes in the past so the service
    // always emits a running event regardless of when the test runs.
    final now = DateTime.now();
    final pastMinutes = now.hour * 60 + now.minute - 5;
    final runningExercise = Exercise(
      uuid: 'test-uuid-running',
      name: 'Running Exercise',
      startTime: SimpleTimeOfDay(
        hour: ((pastMinutes % 1440 + 1440) % 1440 ~/ 60),
        minute: ((pastMinutes % 1440 + 1440) % 1440 % 60),
      ),
      endTime: SimpleTimeOfDay(
        hour: (now.hour + 1) % 24,
        minute: now.minute,
      ),
      numberOfTeams: 2,
      numberOfRounds: 2,
      executionTime: 10,
      evaluationTime: 5,
      rotationTime: 5,
      stations: [],
      schedule: [],
    );

    ExerciseService().start(runningExercise);
    await tester.pumpWidget(_harness(onOpen: () {}));
    // Use pump() not pumpAndSettle() — CircularProgressIndicator spins forever
    await tester.pump();

    // The phase label (DRILL/EVAL/ROLL) must appear when running.
    // Check for any of the English phase labels — the test locale is English.
    final hasLabel =
        find.text('DRILL').evaluate().isNotEmpty ||
        find.text('EVAL').evaluate().isNotEmpty ||
        find.text('ROLL').evaluate().isNotEmpty;
    expect(hasLabel, isTrue, reason: 'Running state must show a phase label');

    ExerciseService().stop();
    await tester.pump();
  });

  testWidgets('pending state hides phase label', (tester) async {
    final now = DateTime.now();
    final futureMinutes = now.hour * 60 + now.minute + 5;
    final pendingExercise = Exercise(
      uuid: 'test-uuid-pending-label',
      name: 'Pending Exercise',
      startTime: SimpleTimeOfDay(
        hour: (futureMinutes ~/ 60) % 24,
        minute: futureMinutes % 60,
      ),
      endTime: SimpleTimeOfDay(
        hour: ((futureMinutes ~/ 60) + 1) % 24,
        minute: futureMinutes % 60,
      ),
      numberOfTeams: 2,
      numberOfRounds: 2,
      executionTime: 5,
      evaluationTime: 3,
      rotationTime: 2,
      stations: [],
      schedule: [],
    );

    ExerciseService().start(pendingExercise);
    await tester.pumpWidget(_harness(onOpen: () {}));
    // Use pump() not pumpAndSettle() — _PulsingRing animation never settles
    await tester.pump();

    // No phase label in pending state — countdown starts with "Starts in"
    expect(find.text('DRILL'), findsNothing);
    expect(find.text('EVAL'), findsNothing);
    expect(find.text('ROLL'), findsNothing);

    ExerciseService().stop();
    await tester.pump();
  });

  testWidgets('pending state shows pulsing ring, not spinning indicator',
      (tester) async {
    final now = DateTime.now();
    final futureMinutes = now.hour * 60 + now.minute + 5;
    final pendingExercise = Exercise(
      uuid: 'test-uuid-pending-ring',
      name: 'Pending Ring Exercise',
      startTime: SimpleTimeOfDay(
        hour: (futureMinutes ~/ 60) % 24,
        minute: futureMinutes % 60,
      ),
      endTime: SimpleTimeOfDay(
        hour: ((futureMinutes ~/ 60) + 1) % 24,
        minute: futureMinutes % 60,
      ),
      numberOfTeams: 2,
      numberOfRounds: 2,
      executionTime: 5,
      evaluationTime: 3,
      rotationTime: 2,
      stations: [],
      schedule: [],
    );

    ExerciseService().start(pendingExercise);
    await tester.pumpWidget(_harness(onOpen: () {}));
    // Use pump() not pumpAndSettle() — _PulsingRing animation never settles
    await tester.pump();

    // No spinning indicator in pending state
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // Pulsing ring is present (keyed Container inside AnimatedBuilder)
    expect(
      find.byKey(const ValueKey('drill-mini-player-pulsing-ring')),
      findsOneWidget,
    );

    ExerciseService().stop();
    await tester.pump();
  });

  testWidgets('no stop button in V1, play square is a Container not IconButton',
      (tester) async {
    ExerciseService().start(exercise);

    await tester.pumpWidget(_harness(onOpen: () {}));
    // Use pump() not pumpAndSettle() — ring animation never settles
    await tester.pump();

    // V1 has no stop button
    expect(find.byIcon(Icons.stop), findsNothing);
    expect(find.byIcon(Icons.stop_circle), findsNothing);
    // Play square is a Container, not an interactive button
    expect(find.byType(IconButton), findsNothing);

    ExerciseService().stop();
    await tester.pump();
  });
}
