import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/plan_repository.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/coordinator_screen.dart';
import 'package:ringdrill/views/drill_player/drill_player_coordinator.dart';
import 'package:ringdrill/views/roleplay_screen.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Swiping the player moves to the next **sibling** — the now-playing metaphor
/// DESIGN-001 is built on, applied to the target sequence (ADR-0056).
///
/// Deliberately within kind: the picker's list spans kinds, so paging it flat
/// would change the player's mode mid-gesture. And deliberately sharing its
/// ordering with the picker, so a swipe lands on the row the picker lists next.
const _planUuid = 'prog-swipe';
const _exerciseUuid = 'ex-swipe';
const _otherExerciseUuid = 'ex-swipe-2';
const _roleA = 'role-swipe-a';
const _roleB = 'role-swipe-b';

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  index: 0,
  name: 'Swipe Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 2,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
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
  ],
  endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
);

Exercise _otherExercise() => _exercise().copyWith(
  uuid: _otherExerciseUuid,
  index: 1,
  name: 'Other Exercise',
);

Plan _shell() {
  final now = DateTime.utc(2026, 1, 1);
  return Plan(
    uuid: _planUuid,
    name: 'Test Plan',
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.1'),
    teams: const [
      Team(uuid: 'team-a', index: 0, name: 'Alfa'),
      Team(uuid: 'team-b', index: 1, name: 'Bravo'),
    ],
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
      uuid: _roleA,
      index: 0,
      exerciseUuid: _exerciseUuid,
      stationIndex: 0,
      name: 'Savnet person',
    ),
  );
  await repo.saveRolePlay(
    const RolePlay(
      uuid: _roleB,
      index: 1,
      exerciseUuid: _exerciseUuid,
      stationIndex: 1,
      name: 'Pårørende',
    ),
  );
  for (final team in _shell().teams) {
    await repo.saveTeam(team);
  }
  await PlanService().init();
}

/// [settle] false uses bounded pumps instead of `pumpAndSettle`: a running
/// exercise animates the mini player's ring indefinitely, so settling never
/// returns once a session is live.
Future<void> _openPlayer(
  WidgetTester tester,
  ContextSheetTarget target, {
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => DrillPlayerCoordinator().openDrillPlayer(
                context,
                target: target,
              ),
              child: const Text('open player'),
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  await tester.tap(find.text('open player'));
  if (settle) {
    await tester.pumpAndSettle();
    return;
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// A fling on the player body. Negative dx pages forward (content moves left),
/// mirroring how a `PageView` reads a drag.
///
/// Flings high in the body rather than at its centre, deliberately: a body can
/// hold its own horizontally scrollable content — the coordinator's round table
/// sits dead centre — and a nested scrollable rightly wins the gesture arena
/// over the pager. See the `on inner horizontal content` test, which pins that
/// as intended rather than letting it look like a flaky swipe.
Future<void> _swipe(WidgetTester tester, {required bool forward}) async {
  final rect = tester.getRect(find.byType(PageView));
  await tester.flingFrom(
    Offset(rect.center.dx, rect.top + rect.height * 0.2),
    Offset(forward ? -400 : 400, 0),
    1200,
  );
  await tester.pumpAndSettle();
}

int _stationIndex(WidgetTester tester) =>
    tester.widget<StationScreen>(find.byType(StationScreen)).stationIndex;

void main() {
  setUp(_seedAndInit);

  group('station mode', () {
    testWidgets('swiping forward and back walks the station sequence', (
      tester,
    ) async {
      await _openPlayer(
        tester,
        const StationSheetTarget(exerciseUuid: _exerciseUuid, stationIndex: 0),
      );
      expect(_stationIndex(tester), 0);

      await _swipe(tester, forward: true);
      expect(_stationIndex(tester), 1);

      await _swipe(tester, forward: true);
      expect(_stationIndex(tester), 2);

      await _swipe(tester, forward: false);
      expect(_stationIndex(tester), 1);
    });

    // Within kind, always: the mode may not change under the user's thumb. Past
    // the last station comes the first — never the next kind.
    testWidgets('wraps from the last station to the first', (tester) async {
      await _openPlayer(
        tester,
        const StationSheetTarget(exerciseUuid: _exerciseUuid, stationIndex: 2),
      );

      await _swipe(tester, forward: true);

      expect(_stationIndex(tester), 0);
      expect(find.byType(StationScreen), findsOneWidget);
      expect(find.byType(RolePlayScreen), findsNothing);
      expect(find.byType(CoordinatorScreen), findsNothing);
    });

    testWidgets('wraps back from the first station to the last', (
      tester,
    ) async {
      await _openPlayer(
        tester,
        const StationSheetTarget(exerciseUuid: _exerciseUuid, stationIndex: 0),
      );

      await _swipe(tester, forward: false);

      expect(_stationIndex(tester), 2);
    });

    // Wrapping is unbounded in both directions, not a single loop: the page
    // range is deep enough that a user paging one way never runs out.
    testWidgets('wraps repeatedly in one direction', (tester) async {
      await _openPlayer(
        tester,
        const StationSheetTarget(exerciseUuid: _exerciseUuid, stationIndex: 0),
      );

      for (var i = 0; i < 7; i++) {
        await _swipe(tester, forward: true);
      }

      // 7 forward from 0 over 3 stations lands on 1.
      expect(_stationIndex(tester), 1);
    });

    testWidgets('the controller follows the swipe', (tester) async {
      await _openPlayer(
        tester,
        const StationSheetTarget(exerciseUuid: _exerciseUuid, stationIndex: 0),
      );
      await _swipe(tester, forward: true);

      // Not just the visible page: the host's target is what every other
      // surface reads, so it has to move too.
      final target = ContextSheet.of(
        tester.element(find.byType(StationScreen)),
      ).target.value;
      expect(target, isA<StationSheetTarget>());
      expect((target! as StationSheetTarget).stationIndex, 1);
    });
  });

  group('roleplay mode', () {
    testWidgets('swiping walks the markør sequence, and wraps', (tester) async {
      await _openPlayer(tester, const RoleSheetTarget(rolePlayUuid: _roleA));
      expect(find.text('Savnet person'), findsWidgets);

      await _swipe(tester, forward: true);
      expect(find.byType(RolePlayScreen), findsOneWidget);
      expect(find.text('Pårørende'), findsWidgets);

      // Two markører, so one more forward comes back around.
      await _swipe(tester, forward: true);
      expect(find.text('Savnet person'), findsWidgets);
    });
  });

  group('exercise mode', () {
    testWidgets('swiping walks the plan\'s exercises when idle', (
      tester,
    ) async {
      await _openPlayer(
        tester,
        const ExerciseSheetTarget(exerciseUuid: _exerciseUuid),
      );

      await _swipe(tester, forward: true);

      expect(
        tester.widget<CoordinatorScreen>(find.byType(CoordinatorScreen)).uuid,
        _otherExerciseUuid,
      );
    });

    // The rule that must not be routed around: a live exercise has no siblings,
    // so there is nothing to swipe to. The last time this rule lived in one
    // surface, widening another silently bypassed it.
    testWidgets('a running exercise cannot be swiped away from', (
      tester,
    ) async {
      ExerciseService().start(_exercise());
      await _openPlayer(
        tester,
        const ExerciseSheetTarget(exerciseUuid: _exerciseUuid),
        settle: false,
      );

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1200);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        tester.widget<CoordinatorScreen>(find.byType(CoordinatorScreen)).uuid,
        _exerciseUuid,
      );

      ExerciseService().stop();
      await tester.pump();
    });
  });

  // A body's own horizontal content keeps its gestures: the pager is an ancestor,
  // and the inner scrollable wins the arena. Recorded because it is a real
  // property of this interaction — the swipe is an accelerator, not the only way
  // to move (the picker is), so losing it over the round table is an acceptable
  // trade rather than a bug to chase.
  testWidgets('on inner horizontal content, the content scrolls instead', (
    tester,
  ) async {
    await _openPlayer(
      tester,
      const ExerciseSheetTarget(exerciseUuid: _exerciseUuid),
    );

    // The coordinator's round table occupies the body's centre.
    await tester.flingFrom(
      tester.getCenter(find.byType(PageView)),
      const Offset(-400, 0),
      1200,
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<CoordinatorScreen>(find.byType(CoordinatorScreen)).uuid,
      _exerciseUuid,
      reason: 'the table scrolled; the player stayed put',
    );
  });

  // The other direction of travel: an external replace has to move the page,
  // without its own onPageChanged echoing back and fighting it.
  testWidgets('an external target change moves the page', (tester) async {
    await _openPlayer(
      tester,
      const StationSheetTarget(exerciseUuid: _exerciseUuid, stationIndex: 0),
    );
    final controller = ContextSheet.of(
      tester.element(find.byType(StationScreen)),
    );

    controller.replace(
      const StationSheetTarget(exerciseUuid: _exerciseUuid, stationIndex: 2),
    );
    await tester.pumpAndSettle();

    expect(_stationIndex(tester), 2);

    // And the page still swipes afterwards — the echo guard must not have left
    // the pager and the controller disagreeing about where they are.
    await _swipe(tester, forward: false);
    expect(_stationIndex(tester), 1);
  });

  // Regression: handing a Scrollable a *new* ScrollController does not restart
  // it — ScrollPosition.absorb carries the old pixel offset across, so
  // initialPage is ignored. After a length change that offset resolves to a
  // different sibling (page 1500 modulo a new length of 2 is index 0), so the
  // player showed the wrong target while claiming to show the picked one.
  testWidgets('a kind change lands on the picked target, not a stale page', (
    tester,
  ) async {
    await _openPlayer(
      tester,
      const StationSheetTarget(exerciseUuid: _exerciseUuid, stationIndex: 0),
    );
    ContextSheet.of(
      tester.element(find.byType(StationScreen)),
    ).replace(const RoleSheetTarget(rolePlayUuid: _roleB));
    await tester.pumpAndSettle();

    expect(
      tester.widget<RolePlayScreen>(find.byType(RolePlayScreen)).uuid,
      _roleB,
      reason: 'the second markør was picked, so it is what must be showing',
    );
  });

  // Changing kind changes the page count, which a PageController cannot be told
  // about — the host replaces it instead.
  testWidgets('changing kind rebuilds the sequence', (tester) async {
    await _openPlayer(
      tester,
      const StationSheetTarget(exerciseUuid: _exerciseUuid, stationIndex: 0),
    );
    final controller = ContextSheet.of(
      tester.element(find.byType(StationScreen)),
    );

    controller.replace(const RoleSheetTarget(rolePlayUuid: _roleB));
    await tester.pumpAndSettle();

    expect(find.byType(RolePlayScreen), findsOneWidget);
    expect(find.byType(StationScreen), findsNothing);

    // Now paging the roleplay sequence, not the station one.
    await _swipe(tester, forward: false);
    expect(find.text('Savnet person'), findsWidgets);
  });
}
