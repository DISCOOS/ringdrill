import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/team_exercise_screen.dart';
import 'package:ringdrill/views/widgets/card_section_header.dart';
import 'package:ringdrill/views/widgets/schedule_card.dart';
import 'package:ringdrill/views/widgets/schedule_table.dart';

Exercise _exercise() => Exercise(
  uuid: 'team-view-ex',
  name: 'Team View Test Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 2,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [
    Station(index: 0, name: 'Post 1'),
    Station(index: 1, name: 'Post 2'),
  ],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 0),
      SimpleTimeOfDay(hour: 8, minute: 10),
      SimpleTimeOfDay(hour: 8, minute: 15),
    ],
    [
      SimpleTimeOfDay(hour: 8, minute: 20),
      SimpleTimeOfDay(hour: 8, minute: 30),
      SimpleTimeOfDay(hour: 8, minute: 35),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
);

Widget _harness(Widget widget) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: widget,
);

void main() {
  testWidgets(
    'renders the schedule via the shared ScheduleTable, not ScheduleRow-in-Card',
    (tester) async {
      final exercise = _exercise();
      await tester.pumpWidget(
        _harness(TeamExerciseScreen(teamIndex: 0, exercise: exercise)),
      );
      await tester.pumpAndSettle();

      // Renders through the shared ScheduleCard (CardSectionHeader + bordered
      // ScheduleTable), matching the Post/Spill viewers — not the old bare
      // bordered table with no title.
      expect(find.byType(ScheduleCard), findsOneWidget);
      expect(find.byType(CardSectionHeader), findsOneWidget);
      expect(find.byType(ScheduleTable), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ScheduleTable),
          matching: find.byType(Card),
        ),
        findsNothing,
        reason: 'the old per-round Card-wrapped rows are gone',
      );

      // Both stations' rounds are listed, in order (now prefixed with the
      // formatted post number, e.g. "1.1 Post 1").
      expect(find.textContaining('Post 1'), findsOneWidget);
      expect(find.textContaining('Post 2'), findsOneWidget);

      // One shared header, not a duplicate standalone PhaseHeaders above it.
      expect(find.text('DRILL'), findsOneWidget);
      expect(find.text('EVAL'), findsOneWidget);
      expect(find.text('ROLL'), findsOneWidget);
    },
  );
}
