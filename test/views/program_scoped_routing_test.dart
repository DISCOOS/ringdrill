import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/main_screen.dart';
import 'package:ringdrill/views/widgets/cast_roster_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _programUuid = 'routing-program';
const _otherProgramUuid = 'routing-other-program';
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
    'app:activeProgram:v1': _programUuid,
    'app:librarySchema:v1': '1',
    'p:$_programUuid': jsonEncode(shell(_programUuid, 'Routing Program')),
    'p:$_otherProgramUuid': jsonEncode(
      shell(_otherProgramUuid, 'Other Routing Program'),
    ),
    'pe:$_programUuid:$_exerciseUuid': jsonEncode(_exercise.toJson()),
    'pt:$_programUuid:${_team.uuid}': jsonEncode(_team.toJson()),
    'pr:$_programUuid:$_roleUuid': jsonEncode(_role.toJson()),
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
  final router = buildRouter(false);
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
    await ProgramService().init();
  });

  setUp(() async {
    await ProgramService().setActive(_programUuid);
  });

  testWidgets('canonical program path activates its program', (tester) async {
    final router = await _pumpRouter(tester);

    await _go(tester, router, programPath(_otherProgramUuid));

    expect(ProgramService().activeProgramUuid, _otherProgramUuid);
    expect(_location(router), programPath(_otherProgramUuid));
  });

  testWidgets('unknown program uuid falls back to active program', (
    tester,
  ) async {
    final router = await _pumpRouter(tester);

    await _go(tester, router, programPath('does-not-exist'));

    expect(_location(router), programPath(_programUuid));
    expect(ProgramService().activeProgramUuid, _programUuid);
  });

  testWidgets('legacy tab roots redirect to canonical program paths', (
    tester,
  ) async {
    final router = await _pumpRouter(tester);

    for (final legacy in [
      routeProgram,
      routeStations,
      routeTeams,
      routeRolePlays,
    ]) {
      await _go(tester, router, legacy);
      expect(_location(router), programPath(_programUuid));
    }
    await _go(tester, router, routeMap);
    expect(_location(router), programMapPath(_programUuid));
  });

  test('legacy detail links redirect to canonical detail paths', () {
    final cases = {
      '$routeProgram/$_exerciseUuid': programExercisePath(
        _programUuid,
        _exerciseUuid,
      ),
      '$routeStations/$_exerciseUuid/0': programStationPath(
        _programUuid,
        _exerciseUuid,
        0,
      ),
      '$routeTeams/0': programTeamPath(_programUuid, 0),
      '$routeRolePlays/$_roleUuid': programRolePlayPath(
        _programUuid,
        _roleUuid,
      ),
      '$routeBrief/program/$_programUuid': programBriefPath(_programUuid),
      '$routeBrief/$_exerciseUuid': programExerciseBriefPath(
        _programUuid,
        _exerciseUuid,
      ),
    };

    for (final MapEntry(key: legacy, value: canonical) in cases.entries) {
      expect(legacyProgramRedirect(legacy), canonical);
    }
  });

  testWidgets('canonical detail deep links resolve', (tester) async {
    final router = await _pumpRouter(tester);
    final location = programStationPath(_programUuid, _exerciseUuid, 0);

    router.go(location);
    await tester.pump();

    expect(_location(router), location);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shell renders only Program and Map destinations', (
    tester,
  ) async {
    final router = await _pumpRouter(tester);
    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );

    expect(navigationBar.destinations, hasLength(2));
    expect(_location(router), programPath(_programUuid));
  });

  testWidgets('Markører segment still opens cast roster', (tester) async {
    await _pumpRouter(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.rolePlaysTab));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.recent_actors));
    await tester.pumpAndSettle();

    expect(find.byType(CastRosterSheet), findsOneWidget);
  });
}
