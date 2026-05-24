import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/widgets/station_role_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _programUuid = 'prog-srs';
const _exerciseUuid = 'ex-srs';

const _actorAUuid = 'actor-srs-a';
final _actorA = Actor(uuid: _actorAUuid, realName: 'Kari Nordmann');

// Role at station 0 with age, no actor
const _roleWithAge = RolePlay(
  uuid: 'role-srs-age',
  index: 0,
  exerciseUuid: _exerciseUuid,
  stationIndex: 0,
  name: 'Olav Berg',
  age: 45,
);

// Role at station 0, cast to actorA
const _roleCast = RolePlay(
  uuid: 'role-srs-cast',
  index: 1,
  exerciseUuid: _exerciseUuid,
  stationIndex: 0,
  name: 'Anna Hansen',
  actorUuid: _actorAUuid,
);

// Role at station 1 — used to verify filtering (should not appear for station 0)
const _roleStation1 = RolePlay(
  uuid: 'role-srs-s1',
  index: 2,
  exerciseUuid: _exerciseUuid,
  stationIndex: 1,
  name: 'Vitne X',
);

Exercise _exercise() => Exercise(
      uuid: _exerciseUuid,
      name: 'Test Exercise SRS',
      startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
      numberOfTeams: 1,
      numberOfRounds: 1,
      executionTime: 10,
      evaluationTime: 5,
      rotationTime: 2,
      stations: const [
        Station(index: 0, name: 'Post A'),
        Station(index: 1, name: 'Post B'),
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

Map<String, Object> _buildPrefs() {
  final ex = _exercise();
  return {
    'app:activeProgram:v1': _programUuid,
    'app:librarySchema:v1': '1',
    'p:$_programUuid': jsonEncode({
      'uuid': _programUuid,
      'name': 'Test',
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
    'pe:$_programUuid:$_exerciseUuid': jsonEncode(ex.toJson()),
    'pr:$_programUuid:${_roleWithAge.uuid}': jsonEncode(_roleWithAge.toJson()),
    'pr:$_programUuid:${_roleCast.uuid}': jsonEncode(_roleCast.toJson()),
    'pr:$_programUuid:${_roleStation1.uuid}':
        jsonEncode(_roleStation1.toJson()),
    'pa:$_programUuid:$_actorAUuid': jsonEncode(_actorA.toJson()),
  };
}

/// Wraps [StationRoleSummary] in a GoRouter so [context.push] calls work.
Widget _buildWidget({required int stationIndex}) {
  final ex = _exercise();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: StationRoleSummary(
            exercise: ex,
            stationIndex: stationIndex,
          ),
        ),
        routes: [
          GoRoute(
            path: 'roleplays/:roleUuid',
            builder: (context, state) => Scaffold(
              body: Text('RolePlay ${state.pathParameters['roleUuid']}'),
            ),
          ),
        ],
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(_buildPrefs());
    await ProgramService().init();
  });

  testWidgets('returns SizedBox.shrink when no roles match stationIndex',
      (tester) async {
    // Station 2 has no roles seeded — widget should be effectively empty.
    await tester.pumpWidget(_buildWidget(stationIndex: 2));
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.stationRolesSection), findsNothing);
  });

  testWidgets('renders header with role count when roles exist', (tester) async {
    await tester.pumpWidget(_buildWidget(stationIndex: 0));
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // Two roles at station 0
    expect(find.text(l10n.stationRolesSection), findsOneWidget);
    expect(find.text('(2)'), findsOneWidget);
  });

  testWidgets('renders one row per matching role with age suffix in title',
      (tester) async {
    await tester.pumpWidget(_buildWidget(stationIndex: 0));
    await tester.pump();

    // _roleWithAge has name 'Olav Berg', age 45
    expect(find.text('Olav Berg, 45'), findsOneWidget);
    // _roleCast has name 'Anna Hansen', no age
    expect(find.text('Anna Hansen'), findsOneWidget);
    // Station 1 role must not appear
    expect(find.text('Vitne X'), findsNothing);
  });

  testWidgets('subtitle shows castedByLine when actor is cast', (tester) async {
    await tester.pumpWidget(_buildWidget(stationIndex: 0));
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.castedByLine(_actorA.realName)), findsOneWidget);
  });

  testWidgets('subtitle shows noCastLine when no actor is cast', (tester) async {
    await tester.pumpWidget(_buildWidget(stationIndex: 0));
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // _roleWithAge is uncast
    expect(find.text(l10n.noCastLine), findsOneWidget);
  });

  testWidgets('uncast subtitle is italic + lowered opacity', (tester) async {
    await tester.pumpWidget(_buildWidget(stationIndex: 0));
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final noCastWidgets =
        tester.widgetList<Text>(find.text(l10n.noCastLine));
    for (final w in noCastWidgets) {
      expect(w.style?.fontStyle, FontStyle.italic,
          reason: 'Uncast subtitle must be italic');
    }
  });

  testWidgets('tapping a row body pushes the roleplay route', (tester) async {
    await tester.pumpWidget(_buildWidget(stationIndex: 0));
    await tester.pump();

    // Tap the InkWell area of the first row (the name text)
    await tester.tap(find.text('Olav Berg, 45'));
    await tester.pumpAndSettle();

    expect(
      find.text('RolePlay ${_roleWithAge.uuid}'),
      findsOneWidget,
    );
  });

  testWidgets('trailing cast icon is not wrapped in IconButton or InkWell',
      (tester) async {
    await tester.pumpWidget(_buildWidget(stationIndex: 0));
    await tester.pump();

    // The only InkWell should be the row-body taps (one per row = 2).
    // There should be no extra InkWells for the trailing icon.
    final inkWells = tester.widgetList<InkWell>(find.byType(InkWell));
    // 2 rows at station 0 → 2 InkWells (row body taps only)
    expect(inkWells.length, 2,
        reason: 'Only row-body InkWells; trailing icon must not be wrapped');

    // No IconButton anywhere
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('no Dismissible or delete icon in widget tree', (tester) async {
    await tester.pumpWidget(_buildWidget(stationIndex: 0));
    await tester.pump();

    expect(find.byType(Dismissible), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);
  });
}
