import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/plan_repository.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/coordinator_screen.dart';
import 'package:ringdrill/views/drill_player/drill_player_coordinator.dart';
import 'package:ringdrill/views/roleplay_screen.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:ringdrill/views/team_exercise_screen.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The player is one surface with four peer *modes* — exercise, station,
/// roleplay and team (ADR-0056) — not four separate players. Opening a station while
/// the player is up must switch the player's target, never stack a sheet or a
/// second player on top of it.
const _planUuid = 'prog-player-modes';
const _exerciseUuid = 'ex-player-modes';
const _roleUuid = 'role-player-modes';

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  index: 0,
  name: 'Modes Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
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
  ],
  endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
);

RolePlay _rolePlay() => const RolePlay(
  uuid: _roleUuid,
  index: 0,
  exerciseUuid: _exerciseUuid,
  stationIndex: 0,
  name: 'Savnet person',
);

Plan _shell() {
  final now = DateTime.utc(2026, 1, 1);
  return Plan(
    uuid: _planUuid,
    name: 'Test Plan',
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.1'),
    teams: const [],
    sessions: const [],
    exercises: const [],
    rolePlays: const [],
    staff: const [],
  );
}

Future<void> _seedAndInit() async {
  SharedPreferences.setMockInitialValues({});
  PlanService().reset();
  ExerciseService().stop();
  final prefs = await SharedPreferences.getInstance();
  final repo = PlanRepository(prefs);
  await repo.savePlanShell(_shell());
  await repo.setActivePlanUuid(_planUuid);
  await repo.saveExercise(_exercise());
  await repo.saveRolePlay(_rolePlay());
  await PlanService().init();
}

/// Opens the player through the real entry point, so the test exercises the
/// controller/host wiring rather than a stand-in.
Widget _harness({ContextSheetTarget? target}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () =>
              DrillPlayerCoordinator().openDrillPlayer(context, target: target),
          child: const Text('open player'),
        ),
      ),
    ),
  ),
);

void main() {
  setUp(_seedAndInit);

  testWidgets('opens in exercise mode by default', (tester) async {
    await tester.pumpWidget(
      _harness(target: const ExerciseSheetTarget(exerciseUuid: _exerciseUuid)),
    );
    await tester.tap(find.text('open player'));
    await tester.pumpAndSettle();

    expect(find.byType(CoordinatorScreen), findsOneWidget);
    expect(find.byType(StationScreen), findsNothing);
  });

  // The whole point of the consolidation: a station is a mode of the player,
  // so entering it swaps the body. Before this the station opened in a modal
  // sheet *over* the player (and blanked it on dismissal).
  testWidgets('tapping a station inside the player switches to station mode, '
      'in place', (tester) async {
    await tester.pumpWidget(
      _harness(target: const ExerciseSheetTarget(exerciseUuid: _exerciseUuid)),
    );
    await tester.tap(find.text('open player'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Post 2'));
    await tester.pumpAndSettle();

    expect(find.byType(StationScreen), findsOneWidget);
    // The station that was tapped, not merely *a* station: asserting the screen
    // alone let "every station opens the first one" through.
    expect(
      tester.widget<StationScreen>(find.byType(StationScreen)).stationIndex,
      1,
    );
    expect(
      find.byType(CoordinatorScreen),
      findsNothing,
      reason: 'the exercise body is replaced, not covered',
    );
    // One mode at a time, and still exactly one player.
    expect(find.byType(RolePlayScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens directly in station mode', (tester) async {
    await tester.pumpWidget(
      _harness(
        target: const StationSheetTarget(
          exerciseUuid: _exerciseUuid,
          stationIndex: 1,
        ),
      ),
    );
    await tester.tap(find.text('open player'));
    await tester.pumpAndSettle();

    expect(find.byType(StationScreen), findsOneWidget);
    expect(find.byType(CoordinatorScreen), findsNothing);
    expect(
      tester.widget<StationScreen>(find.byType(StationScreen)).uuid,
      _exerciseUuid,
    );
    expect(
      tester.widget<StationScreen>(find.byType(StationScreen)).stationIndex,
      1,
    );
  });

  testWidgets('opens directly in roleplay mode', (tester) async {
    await tester.pumpWidget(
      _harness(target: const RoleSheetTarget(rolePlayUuid: _roleUuid)),
    );
    await tester.tap(find.text('open player'));
    await tester.pumpAndSettle();

    expect(find.byType(RolePlayScreen), findsOneWidget);
    expect(find.byType(CoordinatorScreen), findsNothing);
    expect(find.text('Savnet person'), findsWidgets);
  });

  testWidgets('opens directly in team mode', (tester) async {
    await tester.pumpWidget(
      _harness(
        target: const TeamSheetTarget(
          exerciseUuid: _exerciseUuid,
          teamIndex: 0,
        ),
      ),
    );
    await tester.tap(find.text('open player'));
    await tester.pumpAndSettle();

    expect(find.byType(TeamExerciseScreen), findsOneWidget);
    expect(find.byType(CoordinatorScreen), findsNothing);
  });

  // The chevron always closes the player, from every mode — there is no target
  // history to unwind. A chevron-down rather than an X because it dismisses back
  // to the mini bar without stopping anything (DESIGN-001), which is what the
  // downward direction says.
  testWidgets('the close affordance dismisses the player from station mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        target: const StationSheetTarget(
          exerciseUuid: _exerciseUuid,
          stationIndex: 0,
        ),
      ),
    );
    await tester.tap(find.text('open player'));
    await tester.pumpAndSettle();
    expect(find.byType(StationScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down).first);
    await tester.pumpAndSettle();

    expect(find.byType(StationScreen), findsNothing);
    expect(find.text('open player'), findsOneWidget);
  });
}
