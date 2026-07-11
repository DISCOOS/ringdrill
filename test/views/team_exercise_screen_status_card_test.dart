import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/views/team_exercise_screen.dart';
import 'package:ringdrill/views/widgets/player_status_card.dart';

// ---------------------------------------------------------------------------
// DESIGN-010 follow-up: player-status-card — the Lag player's now/next is
// the post the team is at now/next, badged with the shared station-number
// badge, from Exercise.stationIndex.
// ---------------------------------------------------------------------------

Exercise _exercise({required SimpleTimeOfDay startTime}) => Exercise(
  uuid: 'team-status-card-ex',
  name: 'Team Status Card Test Exercise',
  startTime: startTime,
  numberOfTeams: 2,
  numberOfRounds: 3,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 5,
  stations: const [
    Station(index: 0, name: 'Post 1'),
    Station(index: 1, name: 'Post 2'),
    Station(index: 2, name: 'Post 3'),
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
    [
      SimpleTimeOfDay(hour: 8, minute: 40),
      SimpleTimeOfDay(hour: 8, minute: 50),
      SimpleTimeOfDay(hour: 8, minute: 55),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 12, minute: 0),
);

Widget _harness(Widget widget) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: widget,
);

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets(
    'running: team 0 shows the badged post it is at now/next',
    (tester) async {
      final past = DateTime.now().subtract(const Duration(minutes: 3));
      final exercise = _exercise(
        startTime: SimpleTimeOfDay(hour: past.hour, minute: past.minute),
      );
      // Team 0: stationIndex(0, round) = round % 3 -> round0: station0
      // ("Post 1"), round1: station1 ("Post 2").
      ExerciseService().start(exercise);

      await tester.pumpWidget(
        _harness(TeamExerciseScreen(teamIndex: 0, exercise: exercise)),
      );
      await tester.pump();

      final cardFinder = find.byType(PlayerStatusCard);
      expect(cardFinder, findsOneWidget);

      expect(
        find.descendant(
          of: cardFinder,
          matching: find.textContaining(l10n.statusNow),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.textContaining(l10n.nextLabel),
        ),
        findsOneWidget,
      );
      // Both post names appear, each with its own number badge — not a
      // bare label baked into the surface title.
      expect(
        find.descendant(of: cardFinder, matching: find.text('Post 1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cardFinder, matching: find.text('Post 2')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cardFinder, matching: find.text('1.1')),
        findsOneWidget,
        reason: 'the "Nå" post is badged with the dotted station number',
      );
      expect(
        find.descendant(of: cardFinder, matching: find.text('1.2')),
        findsOneWidget,
        reason: 'the "Neste" post is badged with the dotted station number',
      );

      ExerciseService().stop();
      await tester.pump();
    },
  );
}
