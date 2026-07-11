import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:ringdrill/views/widgets/player_status_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// DESIGN-010 follow-up: player-status-card — the Post player's now/next is
// the team at this station now/next, from Exercise.teamIndex.
//
// 3 stations, 2 teams, 3 rounds — Exercise.teamIndex(stationIndex, round):
//   round0: s0->team0 s1->team1 s2->none   (station 2 tested for "Not active now")
//   round1: s0->none  s1->team0 s2->team1
//   round2: s0->team1 s1->none  s2->team0
// ---------------------------------------------------------------------------

const _programUuid = 'prog-station-status-card';
const _exerciseUuid = 'ex-station-status-card';

Exercise _exercise({required SimpleTimeOfDay startTime}) => Exercise(
  uuid: _exerciseUuid,
  name: 'Station Status Card Test Exercise',
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

Future<void> _seedAndInit(Exercise exercise) async {
  SharedPreferences.setMockInitialValues({
    'app:activeProgram:v1': _programUuid,
    'app:librarySchema:v1': '1',
    'p:$_programUuid': jsonEncode({
      'uuid': _programUuid,
      'name': 'Test Program',
      'description': '',
      'metadata': {
        'created': '2024-01-01T00:00:00.000Z',
        'updated': '2024-01-01T00:00:00.000Z',
        'version': '1.1',
      },
      'exercises': [],
      'teams': [],
      'sessions': [],
      'rolePlays': [],
      'actors': [],
    }),
    'pe:$_programUuid:$_exerciseUuid': jsonEncode(exercise.toJson()),
  });
  await ProgramService().init();
}

Widget _buildScreen({required int stationIndex}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => StationExerciseScreen(
          stationIndex: stationIndex,
          uuid: _exerciseUuid,
        ),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets(
    'running: station 1 shows the team at this post now/next',
    (tester) async {
      final past = DateTime.now().subtract(const Duration(minutes: 3));
      final exercise = _exercise(
        startTime: SimpleTimeOfDay(hour: past.hour, minute: past.minute),
      );
      await _seedAndInit(exercise);
      ExerciseService().start(exercise);

      // Station 1 (0-based): round0 -> team1 ("Team 2"), round1 -> team0
      // ("Team 1").
      await tester.pumpWidget(_buildScreen(stationIndex: 1));
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
          matching: find.text('${l10n.team(1)} 2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.text('${l10n.team(1)} 1'),
        ),
        findsOneWidget,
      );

      ExerciseService().stop();
      await tester.pump();
    },
  );

  testWidgets(
    'running: station 2 has no team round0 — shows "Not active now"',
    (tester) async {
      final past = DateTime.now().subtract(const Duration(minutes: 3));
      final exercise = _exercise(
        startTime: SimpleTimeOfDay(hour: past.hour, minute: past.minute),
      );
      await _seedAndInit(exercise);
      ExerciseService().start(exercise);

      await tester.pumpWidget(_buildScreen(stationIndex: 2));
      await tester.pump();

      final cardFinder = find.byType(PlayerStatusCard);
      expect(cardFinder, findsOneWidget);
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.text(l10n.statusNotActiveNow),
        ),
        findsOneWidget,
      );

      ExerciseService().stop();
      await tester.pump();
    },
  );
}
