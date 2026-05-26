import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/roleplays_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _programUuid = 'prog-rv';
const _exerciseUuid = 'ex-rv';

// Role A: cast to actor with phone + notes
const _roleAUuid = 'role-a';
const _actorAUuid = 'actor-a';
final _actorA = Actor(
  uuid: _actorAUuid,
  realName: 'Kari Nordmann',
  phone: '99887766',
  notes: 'Erfaren markør',
);
final _roleA = RolePlay(
  uuid: _roleAUuid,
  index: 0,
  exerciseUuid: _exerciseUuid,
  name: 'Anna Hansen',
  age: 45,
  actorUuid: _actorAUuid,
  stationIndex: 0,
);

// Role B: cast to actor without phone
const _roleBUuid = 'role-b';
const _actorBUuid = 'actor-b';
final _actorB = Actor(uuid: _actorBUuid, realName: 'Ola Nordmann');
final _roleB = RolePlay(
  uuid: _roleBUuid,
  index: 1,
  exerciseUuid: _exerciseUuid,
  name: 'Vitne X',
  actorUuid: _actorBUuid,
  stationIndex: 0,
);

const _stationName = 'Post Alpha';

Exercise _exercise() => Exercise(
      uuid: _exerciseUuid,
      name: 'Test Exercise RV',
      startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
      numberOfTeams: 1,
      numberOfRounds: 1,
      executionTime: 10,
      evaluationTime: 5,
      rotationTime: 2,
      stations: const [
        Station(index: 0, name: _stationName),
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
    'pe:$_programUuid:$_exerciseUuid': jsonEncode(ex.toJson()),
    // Two roles seeded together
    'pr:$_programUuid:$_roleAUuid': jsonEncode(_roleA.toJson()),
    'pr:$_programUuid:$_roleBUuid': jsonEncode(_roleB.toJson()),
    // Two actors: A has phone+notes, B has neither.
    // Actor.notes is excluded from JSON (ADR-0022); stored under pan: prefix.
    'pa:$_programUuid:$_actorAUuid': jsonEncode(_actorA.toJson()),
    'pan:$_programUuid:$_actorAUuid': _actorA.notes!,
    'pa:$_programUuid:$_actorBUuid': jsonEncode(_actorB.toJson()),
  };
}

Widget _buildView() {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: RolePlaysView(controller: RolePlaysController()),
    ),
  );
}

/// Expands the tile for the role at [index] (0-based in display order).
Future<void> _expandTileAt(WidgetTester tester, int index) async {
  final chevrons = find.byIcon(Icons.expand_more);
  await tester.tap(chevrons.at(index));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(_buildPrefs());
    await ProgramService().init();
  });

  group('Cast section — actor with phone and notes (role A)', () {
    testWidgets('actor realName is rendered in expanded body', (tester) async {
      await tester.pumpWidget(_buildView());
      await tester.pumpAndSettle();
      await _expandTileAt(tester, 0);
      expect(find.text(_actorA.realName), findsOneWidget);
    });

    testWidgets('phone is rendered when actor has phone', (tester) async {
      await tester.pumpWidget(_buildView());
      await tester.pumpAndSettle();
      await _expandTileAt(tester, 0);
      expect(find.text(_actorA.phone!), findsOneWidget);
    });

    testWidgets('notes are rendered when non-empty', (tester) async {
      await tester.pumpWidget(_buildView());
      await tester.pumpAndSettle();
      await _expandTileAt(tester, 0);
      expect(find.text(_actorA.notes!), findsOneWidget);
    });

    testWidgets('overflow menu exists and contains editCast and clearCast',
        (tester) async {
      await tester.pumpWidget(_buildView());
      await tester.pumpAndSettle();
      await _expandTileAt(tester, 0);

      expect(
        find.byWidgetPredicate((w) => w is PopupMenuButton),
        findsWidgets,
      );

      // Open the first popup (role A's cast section)
      await tester.tap(
        find.byWidgetPredicate((w) => w is PopupMenuButton).first,
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.editCast), findsOneWidget);
      expect(find.text(l10n.clearCast), findsOneWidget);
    });

    testWidgets('"Fjern markør" clears the cast for role A', (tester) async {
      await tester.pumpWidget(_buildView());
      await tester.pumpAndSettle();
      await _expandTileAt(tester, 0);

      await tester.tap(
        find.byWidgetPredicate((w) => w is PopupMenuButton).first,
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.clearCast));
      await tester.pumpAndSettle();

      // After clearing, add-cast button appears (role is no longer cast)
      expect(find.text(l10n.addCast), findsWidgets);
    });
  });

  group('Cast section — actor without phone (role B)', () {
    testWidgets('actor realName shown in expanded body', (tester) async {
      await tester.pumpWidget(_buildView());
      await tester.pumpAndSettle();
      await _expandTileAt(tester, 1);
      expect(find.text(_actorB.realName), findsOneWidget);
    });

    testWidgets('phone number not rendered when actor.phone is null',
        (tester) async {
      await tester.pumpWidget(_buildView());
      await tester.pumpAndSettle();
      await _expandTileAt(tester, 1);

      // Actor name is present
      expect(find.text(_actorB.realName), findsOneWidget);
      // The phone number of actor A must not appear in role B's section
      expect(find.text(_actorA.phone!), findsNothing);
    });
  });

  group('Active-program guard and AppBar action (Step 5)', () {
    testWidgets('with active program: noActiveProgramHint not shown',
        (tester) async {
      await tester.pumpWidget(_buildView());
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.noActiveProgramHint), findsNothing);
    });

    testWidgets('filter FAB is present when active program exists',
        (tester) async {
      await tester.pumpWidget(_buildView());
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  group('Collapsed tile — subtitle and title (Step 3)', () {
    testWidgets(
        'subtitle shows roleSubtitleStation when stationIndex is set',
        (tester) async {
      await tester.pumpWidget(_buildView());
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // Both roles have stationIndex: 0 → station name _stationName
      expect(
        find.text(l10n.roleSubtitleStation(_stationName)),
        findsWidgets,
      );
    });

    testWidgets('title includes cast actor realName in parens (role B)',
        (tester) async {
      await tester.pumpWidget(_buildView());
      await tester.pumpAndSettle();

      // Role B: name 'Vitne X', no age, cast to actorB ('Ola Nordmann').
      // Role B was never cleared in any prior test — safe to assert here.
      expect(find.text('Vitne X (${_actorB.realName})'), findsOneWidget);
    });

    testWidgets('title includes age suffix when age is set (role A)',
        (tester) async {
      // Role A may or may not have actor after the clearCast test, but its
      // name 'Anna Hansen' and age 45 are always present in the title.
      await tester.pumpWidget(_buildView());
      await tester.pumpAndSettle();

      // Find a text widget whose content starts with 'Anna Hansen, 45'
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data?.startsWith('Anna Hansen, 45') ?? false),
        ),
        findsOneWidget,
      );
    });
  });
}
