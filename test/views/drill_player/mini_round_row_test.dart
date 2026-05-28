import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/views/drill_player/mini_round_row.dart';

Exercise _makeExercise() => Exercise(
      uuid: 'test-uuid-row',
      name: 'Row Test Exercise',
      startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
      endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
      numberOfTeams: 2,
      numberOfRounds: 4,
      executionTime: 5,
      evaluationTime: 3,
      rotationTime: 2,
      stations: [],
      schedule: [
        [
          const SimpleTimeOfDay(hour: 8, minute: 0), // execution starts 08:00
          const SimpleTimeOfDay(hour: 8, minute: 5), // evaluation starts 08:05
          const SimpleTimeOfDay(hour: 8, minute: 8), // rotation starts 08:08
        ],
        [
          const SimpleTimeOfDay(hour: 8, minute: 10),
          const SimpleTimeOfDay(hour: 8, minute: 15),
          const SimpleTimeOfDay(hour: 8, minute: 18),
        ],
        [
          const SimpleTimeOfDay(hour: 8, minute: 20),
          const SimpleTimeOfDay(hour: 8, minute: 25),
          const SimpleTimeOfDay(hour: 8, minute: 28),
        ],
        [
          const SimpleTimeOfDay(hour: 8, minute: 30),
          const SimpleTimeOfDay(hour: 8, minute: 35),
          const SimpleTimeOfDay(hour: 8, minute: 38),
        ],
      ],
    );

ExerciseEvent _makeEvent({
  required Exercise exercise,
  required ExercisePhase phase,
  int currentRound = 0,
}) =>
    ExerciseEvent(
      when: DateTime.now(),
      phase: phase,
      exercise: exercise,
      elapsedTime: 0,
      remainingTime: 5,
      currentRound: currentRound,
      phaseProgress: 0.0,
      roundProgress: 0.0,
      totalProgress: 0.0,
    );

Widget _harness(Widget widget) => MaterialApp(
      home: Scaffold(body: Center(child: widget)),
    );

void main() {
  final exercise = _makeExercise();

  testWidgets('renders R1/4 label for currentRound 0 and numberOfRounds 4',
      (tester) async {
    final event = _makeEvent(
      exercise: exercise,
      phase: ExercisePhase.execution,
      currentRound: 0,
    );
    await tester.pumpWidget(
      _harness(MiniRoundRow(exercise: exercise, event: event)),
    );
    await tester.pumpAndSettle();
    expect(find.text('R1/4'), findsOneWidget);
  });

  testWidgets(
    'renders three HH:MM cells from schedule[0] with active cell highlighted',
    (tester) async {
      final event = _makeEvent(
        exercise: exercise,
        phase: ExercisePhase.execution, // phase.index - 1 = 0 → cell 0 active
        currentRound: 0,
      );
      await tester.pumpWidget(
        _harness(MiniRoundRow(exercise: exercise, event: event)),
      );
      await tester.pumpAndSettle();

      // All three phase start times must appear
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('08:05'), findsOneWidget);
      expect(find.text('08:08'), findsOneWidget);

      // The active cell (index 0 for execution) has a blue background.
      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(MiniRoundRow),
          matching: find.byType(Container),
        ),
      );
      final hasBlue = containers.any((c) => c.color == Colors.blueAccent);
      expect(hasBlue, isTrue);
    },
  );

  testWidgets('pending state renders row without any cell highlight',
      (tester) async {
    final event = _makeEvent(
      exercise: exercise,
      phase: ExercisePhase.pending,
      currentRound: 0,
    );
    await tester.pumpWidget(
      _harness(MiniRoundRow(exercise: exercise, event: event)),
    );
    await tester.pumpAndSettle();

    // No blue active cell
    final containers = tester.widgetList<Container>(
      find.descendant(
        of: find.byType(MiniRoundRow),
        matching: find.byType(Container),
      ),
    );
    final hasBlue = containers.any((c) => c.color == Colors.blueAccent);
    expect(hasBlue, isFalse);
  });
}
