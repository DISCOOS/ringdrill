import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _programUuid = 'prog-x';
const _exerciseUuid = 'ex-x';

// Only station 0 has a role; station 1 has none — used for empty-state test.
const _roleAtStation0 = RolePlay(
  uuid: 'role-s0',
  index: 0,
  exerciseUuid: _exerciseUuid,
  stationIndex: 0,
  name: 'Pasient A',
);

Exercise _exercise() => Exercise(
      uuid: _exerciseUuid,
      name: 'Test Exercise',
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

Map<String, Object> _basePrefs() {
  final ex = _exercise();
  return {
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
    // Exercises are stored with 'pe:' prefix keys, not inline in program JSON
    'pe:$_programUuid:$_exerciseUuid': jsonEncode(ex.toJson()),
    // Only station 0 gets a role; station 1 stays empty for empty-state test
    'pr:$_programUuid:${_roleAtStation0.uuid}':
        jsonEncode(_roleAtStation0.toJson()),
  };
}

Future<void> _seedAndInit() async {
  SharedPreferences.setMockInitialValues(_basePrefs());
  await ProgramService().init();
}

/// Wraps [StationExerciseScreen] in a GoRouter so [context.push] works
/// while still allowing the ProgramService to be ready before rendering.
Widget _buildScreen({int stationIndex = 0}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => StationExerciseScreen(
          stationIndex: stationIndex,
          uuid: _exerciseUuid,
        ),
        routes: [
          GoRoute(
            path: 'roleplays/:uuid',
            builder: (context, state) => Scaffold(
              body: Text('RolePlay ${state.pathParameters['uuid']}'),
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
  setUp(() async {
    await _seedAndInit();
  });

  testWidgets('section renders only roles matching (exerciseUuid, stationIndex)',
      (tester) async {
    await tester.pumpWidget(_buildScreen(stationIndex: 0));
    await tester.pumpAndSettle();

    // Role for station 0 is visible
    expect(find.text('Pasient A'), findsOneWidget);
    // Station 1 has no roles, so empty hint is not shown here
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.noRolesAtThisStation), findsNothing);
  });

  testWidgets('empty-state hint appears when no roles match station',
      (tester) async {
    // Station 1 has no roles in the base seed — empty state shows.
    await tester.pumpWidget(_buildScreen(stationIndex: 1));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.noRolesAtThisStation), findsOneWidget);
  });

  testWidgets('tapping add button pushes RolePlayFormScreen with correct draft',
      (tester) async {
    await tester.pumpWidget(_buildScreen(stationIndex: 0));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.addRolePlay));
    await tester.pumpAndSettle();

    // RolePlayFormScreen pushed; AppBar title = newRolePlayTitle (draft name empty)
    expect(find.text(l10n.newRolePlayTitle), findsOneWidget);
    expect(find.byType(RolePlayFormScreen), findsOneWidget);
  });

  testWidgets('tapping row body navigates to role detail', (tester) async {
    await tester.pumpWidget(_buildScreen(stationIndex: 0));
    await tester.pumpAndSettle();

    // The InkWell wrapping row content (title text is tappable)
    await tester.tap(find.text('Pasient A'));
    await tester.pumpAndSettle();

    // Stub route renders the UUID
    expect(find.text('RolePlay ${_roleAtStation0.uuid}'), findsOneWidget);
  });

  testWidgets('swipe opens edit form; row does not dismiss', (tester) async {
    await tester.pumpWidget(_buildScreen(stationIndex: 0));
    await tester.pumpAndSettle();

    // Fling right (startToEnd) past the dismiss threshold
    await tester.fling(find.text('Pasient A'), const Offset(500, 0), 800);
    await tester.pumpAndSettle();

    expect(find.byType(RolePlayFormScreen), findsOneWidget);

    // Pop without saving
    final NavigatorState navigator = tester.state(find.byType(Navigator).last);
    navigator.pop();
    await tester.pumpAndSettle();

    // Row is still present (not dismissed)
    expect(find.text('Pasient A'), findsOneWidget);
  });

  testWidgets('no Icons.delete and no DismissDirection.endToStart on role row',
      (tester) async {
    await tester.pumpWidget(_buildScreen(stationIndex: 0));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete), findsNothing);

    final dismissibles =
        tester.widgetList<Dismissible>(find.byType(Dismissible));
    for (final d in dismissibles) {
      expect(
        d.direction,
        isNot(DismissDirection.endToStart),
        reason: 'Role row must not have an endToStart (delete) swipe',
      );
    }
  });
}
