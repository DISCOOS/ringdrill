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
import 'package:ringdrill/views/drill_player/drill_player_scope.dart';
import 'package:ringdrill/views/roleplay_screen.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Entry policy (ADR-0056): while an exercise is live, opening one of *its*
/// stations or roleplays from a planning list enters the fullscreen player at
/// that item. Everything else keeps opening the ordinary context sheet.
///
/// The two surfaces are told apart by the drag handle: the viewer sheet has
/// one, the fullscreen player deliberately does not (it is non-dismissible).
const _planUuid = 'prog-entry-policy';
const _exerciseUuid = 'ex-entry-policy';
const _otherExerciseUuid = 'ex-entry-policy-2';
const _roleUuid = 'role-entry-policy';

final _dragHandle = find.byKey(const Key('ringdrill-sheet-drag-handle'));

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  index: 0,
  name: 'Live Exercise',
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

Exercise _otherExercise() => _exercise().copyWith(
  uuid: _otherExerciseUuid,
  index: 1,
  name: 'Bystander Exercise',
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
    actors: const [],
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
  await repo.saveExercise(_otherExercise());
  await repo.saveRolePlay(
    const RolePlay(
      uuid: _roleUuid,
      index: 0,
      exerciseUuid: _exerciseUuid,
      stationIndex: 0,
      name: 'Savnet person',
    ),
  );
  await PlanService().init();
}

/// Stands in for a planning list: a row whose tap goes through
/// [openContextTarget], under the same scope + sheet the shell mounts.
Widget _harness(ContextSheetTarget target, {bool withScope = true}) {
  final controller = ContextSheetController();
  Widget child = ContextSheet(
    controller: controller,
    child: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => openContextTarget(context, target),
            child: const Text('open row'),
          ),
        ),
      ),
    ),
  );
  if (withScope) {
    child = DrillPlayerScope(
      coordinator: DrillPlayerCoordinator(),
      child: child,
    );
  }
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

/// Starts the exercise, taps the row, and settles with bounded pumps — a live
/// exercise animates the mini player's ring forever, so pumpAndSettle never
/// returns once the player is up.
Future<void> _tapRowWhileLive(WidgetTester tester) async {
  await _startLive(tester);
  await tester.tap(find.text('open row'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _startLive(WidgetTester tester) async {
  ExerciseService().start(_exercise());
  await tester.pump();
}

/// Stopping before the test body ends is not cosmetic: the service holds a
/// periodic timer, and a timer still pending at teardown fails the test — a
/// tearDown callback runs too late, after the tree is disposed.
Future<void> _stopLive(WidgetTester tester) async {
  ExerciseService().stop();
  await tester.pump();
}

void main() {
  setUp(_seedAndInit);

  group('while its exercise is live', () {
    testWidgets('a station enters the player, not a sheet', (tester) async {
      await tester.pumpWidget(
        _harness(
          const StationSheetTarget(
            exerciseUuid: _exerciseUuid,
            stationIndex: 1,
          ),
        ),
      );
      await _tapRowWhileLive(tester);

      expect(find.byType(StationScreen), findsOneWidget);
      expect(
        _dragHandle,
        findsNothing,
        reason: 'the fullscreen player has no drag handle; a viewer sheet does',
      );

      await _stopLive(tester);
    });

    testWidgets('a roleplay enters the player', (tester) async {
      await tester.pumpWidget(
        _harness(const RoleSheetTarget(rolePlayUuid: _roleUuid)),
      );
      await _tapRowWhileLive(tester);

      expect(find.byType(RolePlayScreen), findsOneWidget);
      expect(_dragHandle, findsNothing);

      await _stopLive(tester);
    });

    testWidgets('the exercise itself enters the player', (tester) async {
      await tester.pumpWidget(
        _harness(const ExerciseSheetTarget(exerciseUuid: _exerciseUuid)),
      );
      await _tapRowWhileLive(tester);

      expect(find.byType(CoordinatorScreen), findsOneWidget);
      expect(_dragHandle, findsNothing);

      await _stopLive(tester);
    });

    // The player is for what the operator is actually running. A bystander
    // exercise's post must not hijack it.
    testWidgets('a station of a DIFFERENT exercise opens the ordinary sheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const StationSheetTarget(
            exerciseUuid: _otherExerciseUuid,
            stationIndex: 0,
          ),
        ),
      );
      await _tapRowWhileLive(tester);

      expect(find.byType(StationScreen), findsOneWidget);
      expect(_dragHandle, findsOneWidget);

      await _stopLive(tester);
    });

    // A team is not one of the player's three modes, so team taps behave
    // exactly as they did before the consolidation.
    testWidgets('a team keeps opening the ordinary sheet', (tester) async {
      await tester.pumpWidget(
        _harness(
          const TeamSheetTarget(exerciseUuid: _exerciseUuid, teamIndex: 0),
        ),
      );
      await _tapRowWhileLive(tester);

      expect(_dragHandle, findsOneWidget);

      await _stopLive(tester);
    });

    // A brief is a modal surface by definition.
    testWidgets('a brief keeps opening its own modal', (tester) async {
      await tester.pumpWidget(
        _harness(const BriefSheetTarget(exerciseUuid: _exerciseUuid)),
      );
      await _tapRowWhileLive(tester);

      expect(find.byType(StationScreen), findsNothing);
      expect(find.byType(CoordinatorScreen), findsNothing);

      await _stopLive(tester);
    });
  });

  testWidgets('with nothing running, a station opens the ordinary sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        const StationSheetTarget(exerciseUuid: _exerciseUuid, stationIndex: 0),
      ),
    );
    await tester.tap(find.text('open row'));
    await tester.pumpAndSettle();

    expect(find.byType(StationScreen), findsOneWidget);
    expect(_dragHandle, findsOneWidget);
  });

  // A cold deep link has no DrillPlayerScope above it. It must degrade to the
  // ordinary flow rather than crash looking for one.
  testWidgets('without a DrillPlayerScope it falls back to the sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        const StationSheetTarget(exerciseUuid: _exerciseUuid, stationIndex: 0),
        withScope: false,
      ),
    );
    await _tapRowWhileLive(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(StationScreen), findsOneWidget);
    expect(_dragHandle, findsOneWidget);

    await _stopLive(tester);
  });

  group('shouldHostInPlayer', () {
    late BuildContext ctx;

    Future<void> pumpContext(WidgetTester tester, {bool inline = false}) async {
      final controller = ContextSheetController();
      addTearDown(controller.dispose);
      if (inline) {
        controller.adoptInlineTarget(
          const ExerciseSheetTarget(exerciseUuid: _exerciseUuid),
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          home: ContextSheet(
            controller: controller,
            child: Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
    }

    testWidgets('false when nothing is running', (tester) async {
      await pumpContext(tester);

      expect(
        shouldHostInPlayer(
          ctx,
          const StationSheetTarget(
            exerciseUuid: _exerciseUuid,
            stationIndex: 0,
          ),
        ),
        isFalse,
      );
    });

    testWidgets('false for a target whose exercise is gone from the plan', (
      tester,
    ) async {
      await pumpContext(tester);
      await _startLive(tester);
      // Uuid equality alone would say yes here; the entity has to still exist.
      await PlanService().deleteExercise(_exerciseUuid);

      expect(
        shouldHostInPlayer(
          ctx,
          const StationSheetTarget(
            exerciseUuid: _exerciseUuid,
            stationIndex: 0,
          ),
        ),
        isFalse,
      );

      await _stopLive(tester);
    });

    // Inside the player the controller is already inline, so show/showOrReplace
    // swaps the body in place — opening a second player would be wrong.
    testWidgets('false when already inside the player', (tester) async {
      await pumpContext(tester, inline: true);
      await _startLive(tester);

      expect(
        shouldHostInPlayer(
          ctx,
          const StationSheetTarget(
            exerciseUuid: _exerciseUuid,
            stationIndex: 1,
          ),
        ),
        isFalse,
      );

      await _stopLive(tester);
    });

    testWidgets('true for a live exercise\'s own station', (tester) async {
      await pumpContext(tester);
      await _startLive(tester);

      expect(
        shouldHostInPlayer(
          ctx,
          const StationSheetTarget(
            exerciseUuid: _exerciseUuid,
            stationIndex: 1,
          ),
        ),
        isTrue,
      );

      await _stopLive(tester);
    });
  });
}
