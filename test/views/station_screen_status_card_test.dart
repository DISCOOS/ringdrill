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

/// A fixed morning reference, safely clear of midnight for every offset
/// used below (up to 43 minutes) and well before the fixture's own
/// `endTime` (noon) so it never itself reads as "past end".
final _fixedNow = DateTime(2026, 1, 1, 9, 0);

/// A [SimpleTimeOfDay] [minutesAgo] before [_fixedNow] — pairs with
/// [ExerciseService.debugNowOverride] pinned to [_fixedNow] so a test is
/// not at the mercy of real wall-clock time. A bare
/// `DateTime.now().subtract(...)` loses its date once truncated to
/// [SimpleTimeOfDay] (hour/minute only): whenever the real current time was
/// less than the subtracted offset past midnight, the synthetic start time
/// landed on the previous day and the exercise looked scheduled in the
/// future (pending) instead of already running — flaky in exactly the
/// first `minutesAgo` minutes after midnight.
SimpleTimeOfDay _startTimeMinutesAgo(int minutesAgo) {
  final past = _fixedNow.subtract(Duration(minutes: minutesAgo));
  return SimpleTimeOfDay(hour: past.hour, minute: past.minute);
}

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
      final exercise = _exercise(startTime: _startTimeMinutesAgo(3));
      await _seedAndInit(exercise);
      ExerciseService().debugNowOverride = () => _fixedNow;
      addTearDown(() => ExerciseService().debugNowOverride = DateTime.now);
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
    'running: station 1 on the last round falls back to the exercise '
    'finish time instead of an empty next-cell',
    (tester) async {
      // 3 minutes into round 2's (the last round's) execution phase: 2 full
      // rounds (20 min each: executionTime 10 + evaluationTime 5 +
      // rotationTime 5) plus 3 minutes.
      final exercise = _exercise(startTime: _startTimeMinutesAgo(43));
      await _seedAndInit(exercise);
      ExerciseService().debugNowOverride = () => _fixedNow;
      addTearDown(() => ExerciseService().debugNowOverride = DateTime.now);
      ExerciseService().start(exercise);

      // Station 0 (0-based): round2 -> team1 ("Team 2"), so the "now" cell
      // is active — only the "next" cell is exhausted (no round after the
      // last one).
      await tester.pumpWidget(_buildScreen(stationIndex: 0));
      await tester.pump();

      final cardFinder = find.byType(PlayerStatusCard);
      expect(cardFinder, findsOneWidget);

      expect(
        find.descendant(
          of: cardFinder,
          matching: find.text(
            '${l10n.nextLabel} · ${exercise.endTime}',
          ),
        ),
        findsOneWidget,
        reason: 'the next-cell label still reads "Next", with the '
            "exercise's finish time appended inline",
      );
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.text(l10n.statusFinishValue),
        ),
        findsOneWidget,
        reason: 'the next-cell value reads "Finish" instead of being empty',
      );

      ExerciseService().stop();
      await tester.pump();
    },
  );

  testWidgets(
    'running: station 2 has no team round0 — shows "Not active now"',
    (tester) async {
      final exercise = _exercise(startTime: _startTimeMinutesAgo(3));
      await _seedAndInit(exercise);
      ExerciseService().debugNowOverride = () => _fixedNow;
      addTearDown(() => ExerciseService().debugNowOverride = DateTime.now);
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
