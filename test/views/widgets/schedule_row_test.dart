import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/views/phase_widget.dart';
import 'package:ringdrill/views/widgets/schedule_row.dart';

Exercise _makeExercise() => Exercise(
  uuid: 'test-uuid-schedule-row',
  name: 'Schedule Row Test Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  numberOfTeams: 2,
  numberOfRounds: 2,
  executionTime: 5,
  evaluationTime: 3,
  rotationTime: 2,
  stations: [],
  schedule: [
    [
      const SimpleTimeOfDay(hour: 8, minute: 0),
      const SimpleTimeOfDay(hour: 8, minute: 5),
      const SimpleTimeOfDay(hour: 8, minute: 8),
    ],
    [
      const SimpleTimeOfDay(hour: 8, minute: 10),
      const SimpleTimeOfDay(hour: 8, minute: 15),
      const SimpleTimeOfDay(hour: 8, minute: 18),
    ],
  ],
);

ExerciseEvent _makeEvent({
  required Exercise exercise,
  required ExercisePhase phase,
  int currentRound = 0,
}) => ExerciseEvent(
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

bool _hasBlueAccent(WidgetTester tester, Finder of) {
  final containers = tester.widgetList<Container>(
    find.descendant(of: of, matching: find.byType(Container)),
  );
  return containers.any(
    (c) =>
        (c.decoration as BoxDecoration?)?.color == Colors.blueAccent ||
        c.color == Colors.blueAccent,
  );
}

void main() {
  final exercise = _makeExercise();

  testWidgets('renders the label and the three phase times from schedule[0]', (
    tester,
  ) async {
    final event = _makeEvent(exercise: exercise, phase: ExercisePhase.pending);
    await tester.pumpWidget(
      _harness(
        ScheduleRow(
          label: 'Runde 1',
          event: event,
          exercise: exercise,
          roundIndex: 0,
        ),
      ),
    );

    expect(find.text('Runde 1'), findsOneWidget);
    expect(find.byType(PhasesWidget), findsNWidgets(3));
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('08:05'), findsOneWidget);
    expect(find.text('08:08'), findsOneWidget);
  });

  testWidgets(
    'the current round gets the house highlight only while running',
    (tester) async {
      final running = _makeEvent(
        exercise: exercise,
        phase: ExercisePhase.execution,
        currentRound: 0,
      );
      final rowKey = GlobalKey();
      await tester.pumpWidget(
        _harness(
          ScheduleRow(
            key: rowKey,
            label: 'Runde 1',
            event: running,
            exercise: exercise,
            roundIndex: 0,
          ),
        ),
      );
      expect(_hasBlueAccent(tester, find.byKey(rowKey)), isTrue);

      final pending = _makeEvent(
        exercise: exercise,
        phase: ExercisePhase.pending,
        currentRound: 0,
      );
      await tester.pumpWidget(
        _harness(
          ScheduleRow(
            key: rowKey,
            label: 'Runde 1',
            event: pending,
            exercise: exercise,
            roundIndex: 0,
          ),
        ),
      );
      expect(_hasBlueAccent(tester, find.byKey(rowKey)), isFalse);
    },
  );

  testWidgets(
    'a muted row is struck through and never current even when running on '
    'its round — callers omit onTap for muted rows, the row itself still '
    'wires whatever is passed',
    (tester) async {
      final running = _makeEvent(
        exercise: exercise,
        phase: ExercisePhase.execution,
        currentRound: 0,
      );
      var tapped = false;
      final rowKey = GlobalKey();
      await tester.pumpWidget(
        _harness(
          ScheduleRow(
            key: rowKey,
            label: 'Lag ×',
            event: running,
            exercise: exercise,
            roundIndex: 0,
            muted: true,
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(_hasBlueAccent(tester, find.byKey(rowKey)), isFalse);
      final text = tester.widget<Text>(find.text('Lag ×'));
      expect(text.style?.decoration, TextDecoration.lineThrough);

      await tester.tap(find.byKey(rowKey));
      expect(tapped, isTrue, reason: 'onTap is still wired even when muted');
    },
  );

  testWidgets(
    'struckThrough alone strikes the text but stays eligible for the '
    'current-round highlight',
    (tester) async {
      final running = _makeEvent(
        exercise: exercise,
        phase: ExercisePhase.execution,
        currentRound: 0,
      );
      final rowKey = GlobalKey();
      await tester.pumpWidget(
        _harness(
          ScheduleRow(
            key: rowKey,
            label: 'Post ×',
            event: running,
            exercise: exercise,
            roundIndex: 0,
            struckThrough: true,
          ),
        ),
      );

      expect(_hasBlueAccent(tester, find.byKey(rowKey)), isTrue);
      final text = tester.widget<Text>(find.text('Post ×'));
      expect(text.style?.decoration, TextDecoration.lineThrough);
    },
  );
}
