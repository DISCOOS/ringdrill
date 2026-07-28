import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/shell/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The gate is *wired*, not merely available.
///
/// `canEdit` and the wrappers were built, tested and documented while no call
/// site consulted them — so the matrix was correct and the app still let every
/// role edit everything. These tests assert through the real shell that the
/// affordances actually consult it: a `Dismissible` present for a director and
/// absent for an actor, on the same list.
///
/// Deliberately not a unit test of `canEdit` (see edit_permissions_test) — the
/// failure mode being guarded here is a call site that forgot to ask.
const _planUuid = 'plan-edit-gate';
const _exerciseUuid = 'exercise-edit-gate';

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  name: 'Gate Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [Station(index: 0, name: 'Post 1')],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 0),
      SimpleTimeOfDay(hour: 8, minute: 10),
      SimpleTimeOfDay(hour: 8, minute: 15),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
);

Map<String, Object> _prefs() => {
  'app:activePlan:v1': _planUuid,
  'app:librarySchema:v1': '1',
  'p:$_planUuid': jsonEncode({
    'uuid': _planUuid,
    'name': 'Edit Gate Plan',
    'description': '',
    'metadata': {
      'created': '2026-01-01T00:00:00.000Z',
      'updated': '2026-01-01T00:00:00.000Z',
      'version': '1.1',
    },
    'exercises': [],
    'teams': [],
    'sessions': [],
    'rolePlays': [],
    'actors': [],
  }),
  'pe:$_planUuid:$_exerciseUuid': jsonEncode(_exercise().toJson()),
};

Future<void> _pumpPlanTab(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await PlanService().setActive(_planUuid);
  final router = buildRouter(false, true);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
}

/// The swipe affordance on the exercise row.
Finder get _exerciseSwipe => find.byWidgetPredicate(
  (w) => w is Dismissible && w.key == const ValueKey(_exerciseUuid),
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(_prefs());
    await PlanService().init();
    ExerciseService().stop();
    appUserRole.value = StaffRole.director;
    addTearDown(() => appUserRole.value = StaffRole.director);
  });

  testWidgets('a director gets swipe-to-edit on an exercise', (tester) async {
    await _pumpPlanTab(tester);

    expect(_exerciseSwipe, findsOneWidget);
  });

  // The reported problem: every role could swipe any row open, including on a
  // live exercise.
  testWidgets('an actor does not — exercises are director-only', (
    tester,
  ) async {
    appUserRole.value = StaffRole.actor;
    await _pumpPlanTab(tester);

    expect(_exerciseSwipe, findsNothing);
    // And the row itself is still there: the gate removes the affordance, not
    // the content.
    expect(find.text('Gate Exercise'), findsWidgets);
  });

  testWidgets('nor an instructor', (tester) async {
    appUserRole.value = StaffRole.instructor;
    await _pumpPlanTab(tester);

    expect(_exerciseSwipe, findsNothing);
  });

  // The live lock, through the real list rather than the predicate.
  testWidgets('not even a director, while that exercise runs', (tester) async {
    await _pumpPlanTab(tester);
    expect(_exerciseSwipe, findsOneWidget);

    ExerciseService().start(_exercise());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      _exerciseSwipe,
      findsNothing,
      reason: 'a running exercise is frozen for every role',
    );

    ExerciseService().stop();
    await tester.pump();
  });

  // The listenable half: a role changed while a list is on screen has to reach
  // it. Before, the role was read once per screen and never re-read.
  testWidgets('changing role updates the affordance in place', (tester) async {
    await _pumpPlanTab(tester);
    expect(_exerciseSwipe, findsOneWidget);

    appUserRole.value = StaffRole.actor;
    await tester.pumpAndSettle();
    expect(_exerciseSwipe, findsNothing);

    appUserRole.value = StaffRole.director;
    await tester.pumpAndSettle();
    expect(_exerciseSwipe, findsOneWidget);
  });

  group('the create affordance', () {
    testWidgets('a director sees the new-exercise FAB', (tester) async {
      await _pumpPlanTab(tester);

      expect(find.byType(FloatingActionButton), findsWidgets);
    });

    testWidgets('an actor does not', (tester) async {
      appUserRole.value = StaffRole.actor;
      await _pumpPlanTab(tester);

      expect(
        find.byType(FloatingActionButton),
        findsNothing,
        reason: 'a create action this role will never have is noise',
      );
    });
  });
}
