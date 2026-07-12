import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/coordinator_screen.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:ringdrill/views/widgets/player_status_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// DESIGN-010 coordinator-play-and-status-polish follow-up, Fix 1: the status
// card must sit at the same left-edge inset on every surface. Locks the
// "coordinator status card nearly edge-to-edge, tighter than Post/Lag/Spill"
// regression by comparing its rendered left edge to a player's (Post) at the
// same viewport width.
// ---------------------------------------------------------------------------

const _programUuid = 'prog-status-card-padding-parity';
const _exerciseUuid = 'ex-status-card-padding-parity';

Exercise _exercise({required SimpleTimeOfDay startTime}) => Exercise(
  uuid: _exerciseUuid,
  name: 'Padding Parity Test Exercise',
  startTime: startTime,
  numberOfTeams: 1,
  numberOfRounds: 2,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 5,
  stations: const [Station(index: 0, name: 'Post 1')],
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

// `ProgramService` is a lazily-initialized singleton that only reads
// SharedPreferences once (`_isReady` guards `init()`), so — unlike the
// other status-card fixtures, which each run in their own test file — this
// test renders both surfaces from the *same* seeded exercise/program
// instead of re-seeding between them.
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
    'pe:$_programUuid:${exercise.uuid}': jsonEncode(exercise.toJson()),
  });
  await ProgramService().init();
}

Widget _coordinatorHarness(String uuid) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: CoordinatorScreen(uuid: uuid),
);

Widget _stationHarness(String uuid) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            StationExerciseScreen(stationIndex: 0, uuid: uuid),
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
  testWidgets(
    'the status card sits at the same left-edge inset on the coordinator '
    'as on a player (Post)',
    (tester) async {
      // A compact width so the coordinator renders its single-column
      // stacked body regardless of the ambient test viewport default.
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final past = DateTime.now().subtract(const Duration(minutes: 3));
      final exercise = _exercise(
        startTime: SimpleTimeOfDay(hour: past.hour, minute: past.minute),
      );
      await _seedAndInit(exercise);
      ExerciseService().start(exercise);

      // Coordinator.
      await tester.pumpWidget(_coordinatorHarness(_exerciseUuid));
      await tester.pump();
      expect(find.byType(PlayerStatusCard), findsOneWidget);
      final coordinatorLeft = tester
          .getTopLeft(find.byType(PlayerStatusCard))
          .dx;

      // Post (station) — same exercise, same start/stop lifecycle.
      await tester.pumpWidget(_stationHarness(_exerciseUuid));
      await tester.pump();
      expect(find.byType(PlayerStatusCard), findsOneWidget);
      final stationLeft = tester.getTopLeft(find.byType(PlayerStatusCard)).dx;

      ExerciseService().stop();
      await tester.pump();

      expect(
        stationLeft,
        coordinatorLeft,
        reason:
            'the coordinator and Post status cards must share the same '
            'left-edge inset (kPlayerSurfaceHorizontalPadding)',
      );
    },
  );
}
