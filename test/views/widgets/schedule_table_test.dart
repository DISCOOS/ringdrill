import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/views/widgets/schedule_row.dart';
import 'package:ringdrill/views/widgets/schedule_table.dart';

Exercise _makeExercise() => Exercise(
  uuid: 'test-uuid-schedule-table',
  name: 'Schedule Table Test Exercise',
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
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: widget)),
);

void main() {
  final exercise = _makeExercise();

  testWidgets('renders a header and one ScheduleRow per row entry', (
    tester,
  ) async {
    final event = _makeEvent(exercise: exercise, phase: ExercisePhase.pending);
    await tester.pumpWidget(
      _harness(
        ScheduleTable(
          headerLabel: 'Runde',
          event: event,
          exercise: exercise,
          rows: [
            const ScheduleTableRow(roundIndex: 0, label: 'Runde 1'),
            const ScheduleTableRow(roundIndex: 1, label: 'Runde 2'),
          ],
        ),
      ),
    );

    expect(find.text('Runde 1'), findsOneWidget);
    expect(find.text('Runde 2'), findsOneWidget);
    expect(find.byType(ScheduleRow), findsNWidgets(2));
    // Header carries the three phase-column labels.
    expect(find.text('DRILL'), findsOneWidget);
    expect(find.text('EVAL'), findsOneWidget);
    expect(find.text('ROLL'), findsOneWidget);
  });

  testWidgets('a muted+struck-through row renders with no live team, as the '
      'Post/Spill viewers use it', (tester) async {
    final event = _makeEvent(exercise: exercise, phase: ExercisePhase.pending);
    await tester.pumpWidget(
      _harness(
        ScheduleTable(
          headerLabel: 'Lag',
          event: event,
          exercise: exercise,
          bordered: true,
          rows: [
            const ScheduleTableRow(roundIndex: 0, label: 'Lag 1'),
            const ScheduleTableRow(
              roundIndex: 1,
              label: 'Lag ×',
              muted: true,
            ),
          ],
        ),
      ),
    );

    final mutedText = tester.widget<Text>(find.text('Lag ×'));
    expect(mutedText.style?.decoration, TextDecoration.lineThrough);
    final activeText = tester.widget<Text>(find.text('Lag 1'));
    expect(activeText.style?.decoration, isNot(TextDecoration.lineThrough));
  });

  testWidgets(
    'the running round shows the house highlight; no round does when '
    'pending',
    (tester) async {
      final running = _makeEvent(
        exercise: exercise,
        phase: ExercisePhase.execution,
        currentRound: 1,
      );
      await tester.pumpWidget(
        _harness(
          ScheduleTable(
            headerLabel: 'Runde',
            event: running,
            exercise: exercise,
            rows: [
              const ScheduleTableRow(roundIndex: 0, label: 'Runde 1'),
              const ScheduleTableRow(roundIndex: 1, label: 'Runde 2'),
            ],
          ),
        ),
      );

      bool blueBehind(String label) {
        final containers = tester.widgetList<Container>(
          find.descendant(
            of: find.ancestor(
              of: find.text(label),
              matching: find.byType(ScheduleRow),
            ),
            matching: find.byType(Container),
          ),
        );
        return containers.any(
          (c) =>
              (c.decoration as BoxDecoration?)?.color == Colors.blueAccent ||
              c.color == Colors.blueAccent,
        );
      }

      expect(blueBehind('Runde 1'), isFalse);
      expect(blueBehind('Runde 2'), isTrue);

      final pending = _makeEvent(
        exercise: exercise,
        phase: ExercisePhase.pending,
        currentRound: 1,
      );
      await tester.pumpWidget(
        _harness(
          ScheduleTable(
            headerLabel: 'Runde',
            event: pending,
            exercise: exercise,
            rows: [
              const ScheduleTableRow(roundIndex: 0, label: 'Runde 1'),
              const ScheduleTableRow(roundIndex: 1, label: 'Runde 2'),
            ],
          ),
        ),
      );
      expect(blueBehind('Runde 2'), isFalse);
    },
  );
}
