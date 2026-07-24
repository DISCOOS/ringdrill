import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/shell/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _planUuid = 'routing-plan';
const _otherPlanUuid = 'routing-other-plan';
const _exerciseUuid = 'routing-exercise';
const _roleUuid = 'routing-role';

final _exercise = Exercise(
  uuid: _exerciseUuid,
  name: 'Routing Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [Station(index: 0, name: 'Routing Station')],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 0),
      SimpleTimeOfDay(hour: 8, minute: 10),
      SimpleTimeOfDay(hour: 8, minute: 15),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
);

final _role = RolePlay(
  uuid: _roleUuid,
  index: 0,
  exerciseUuid: _exerciseUuid,
  name: 'Routing Role',
  stationIndex: 0,
);

final _team = Team(uuid: 'routing-team', index: 0, name: 'Routing Team');

Map<String, Object> _prefs() {
  Map<String, Object?> shell(String uuid, String name) => {
    'uuid': uuid,
    'name': name,
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
  };

  return {
    'app:activePlan:v1': _planUuid,
    'app:librarySchema:v1': '1',
    'p:$_planUuid': jsonEncode(shell(_planUuid, 'Routing Plan')),
    'p:$_otherPlanUuid': jsonEncode(
      shell(_otherPlanUuid, 'Other Routing Plan'),
    ),
    'pe:$_planUuid:$_exerciseUuid': jsonEncode(_exercise.toJson()),
    'pt:$_planUuid:${_team.uuid}': jsonEncode(_team.toJson()),
    'pr:$_planUuid:$_roleUuid': jsonEncode(_role.toJson()),
  };
}

Widget _app(GoRouter router) {
  return MaterialApp.router(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}

String _location(GoRouter router) =>
    router.routeInformationProvider.value.uri.path;

Future<GoRouter> _pumpRouter(WidgetTester tester) async {
  tester.view.physicalSize = const Size(700, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = buildRouter(false, true);
  addTearDown(router.dispose);
  await tester.pumpWidget(_app(router));
  await tester.pumpAndSettle();
  return router;
}

Future<void> _go(WidgetTester tester, GoRouter router, String location) async {
  router.go(location);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(_prefs());
    await PlanService().init();
  });

  setUp(() async {
    await PlanService().setActive(_planUuid);
  });

  testWidgets('canonical plan path activates its plan', (tester) async {
    final router = await _pumpRouter(tester);

    await _go(tester, router, planPath(_otherPlanUuid));

    expect(PlanService().activePlanUuid, _otherPlanUuid);
    // Bare `/plan/:uuid` redirects to the default segment per ADR-0032
    // *Canonical scheme*. Every Plan-tab view has a stable URL.
    expect(
      _location(router),
      planSegmentPath(_otherPlanUuid, planSegmentDefaultSlug),
    );
  });

  testWidgets('unknown plan uuid falls back to active plan', (
    tester,
  ) async {
    final router = await _pumpRouter(tester);

    await _go(tester, router, planPath('does-not-exist'));

    expect(
      _location(router),
      planSegmentPath(_planUuid, planSegmentDefaultSlug),
    );
    expect(PlanService().activePlanUuid, _planUuid);
  });

  testWidgets('legacy tab roots redirect to canonical plan paths', (
    tester,
  ) async {
    final router = await _pumpRouter(tester);

    for (final legacy in [
      routePlan,
      routeStations,
      routeTeams,
      routeRolePlays,
    ]) {
      await _go(tester, router, legacy);
      expect(
        _location(router),
        planSegmentPath(_planUuid, planSegmentDefaultSlug),
      );
    }
    await _go(tester, router, routeMap);
    expect(_location(router), planMapPath(_planUuid));
  });

  test('legacy detail links redirect to canonical detail paths', () {
    final cases = {
      '$routePlan/$_exerciseUuid': planExercisePath(
        _planUuid,
        _exerciseUuid,
      ),
      '$routeStations/$_exerciseUuid/0': planStationPath(
        _planUuid,
        _exerciseUuid,
        0,
      ),
      '$routeTeams/0': planTeamPath(_planUuid, 0),
      '$routeRolePlays/$_roleUuid': planRolePlayPath(
        _planUuid,
        _roleUuid,
      ),
      '$routeBrief/plan/$_planUuid': planBriefPath(_planUuid),
      '$routeBrief/$_exerciseUuid': planExerciseBriefPath(
        _planUuid,
        _exerciseUuid,
      ),
    };

    for (final MapEntry(key: legacy, value: canonical) in cases.entries) {
      expect(legacyPlanRedirect(legacy), canonical);
    }
  });

  testWidgets('canonical detail deep links resolve', (tester) async {
    final router = await _pumpRouter(tester);
    final location = planStationPath(_planUuid, _exerciseUuid, 0);

    router.go(location);
    await tester.pump();

    expect(_location(router), location);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shell renders Plan, Map and Roster destinations', (
    tester,
  ) async {
    final router = await _pumpRouter(tester);
    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );

    expect(navigationBar.destinations, hasLength(3));
    expect(
      _location(router),
      planSegmentPath(_planUuid, planSegmentDefaultSlug),
    );
  });

  testWidgets(
    'Script (Spill) segment no longer carries the cast-roster action',
    (tester) async {
      await _pumpRouter(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.text(l10n.scriptSegment));
      await tester.pumpAndSettle();

      // The cast-roster shortcut (Icons.recent_actors) was retired once the
      // Roster tab became the actor registry's home. Only the exercise
      // filter remains as a Spill-segment AppBar action.
      expect(find.byIcon(Icons.recent_actors), findsNothing);
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
    },
  );

  testWidgets('segment paths resolve as their own canonical URLs', (
    tester,
  ) async {
    final router = await _pumpRouter(tester);

    for (final slug in planSegmentSlugs) {
      await _go(tester, router, planSegmentPath(_planUuid, slug));
      expect(_location(router), planSegmentPath(_planUuid, slug));
    }
  });

  testWidgets('tapping a segment updates the URL', (tester) async {
    final router = await _pumpRouter(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.scriptSegment));
    await tester.pumpAndSettle();

    expect(
      _location(router),
      planSegmentPath(_planUuid, planSegmentScriptSlug),
    );
  });
}
