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
  final controller = RolePlaysController();
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        // Wire the controller's AppBar actions so tests can assert on
        // the filter icon that moved off the body FAB in Step 2.
        appBar: AppBar(
          actions: controller.buildActions(
                context,
                BoxConstraints.loose(const Size(400, 56)),
              ) ??
              [],
        ),
        // RolePlaysView now returns sliver content for embedding in a
        // CustomScrollView (see program_view.dart's per-segment scroll
        // view); the "Ny rolle" FAB is a separate overlay widget
        // (RolePlaysCreateFab) that program_view.dart renders alongside it,
        // mirrored here so the FAB-presence tests below still apply.
        body: Stack(
          children: [
            Positioned.fill(
              child: CustomScrollView(
                slivers: [RolePlaysView(controller: controller)],
              ),
            ),
            RolePlaysCreateFab(controller: controller),
          ],
        ),
      ),
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
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // The expanded cast pill reads "Enacted by {realName}".
      expect(find.text(l10n.castedByLine(_actorA.realName)), findsOneWidget);
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

    testWidgets(
      'no overflow menu remains; the cast chip opens the marker sheet, '
      'which exposes both editCast (pencil) and clearCast',
      (tester) async {
        await tester.pumpWidget(_buildView());
        await tester.pumpAndSettle();
        await _expandTileAt(tester, 0);

        // DESIGN-010 browser tile polish (Fix 4): no `⋮` context menu.
        expect(
          find.byWidgetPredicate((w) => w is PopupMenuButton),
          findsNothing,
        );

        // The collapsed tile's cast chip (Icons.face, role A is cast) is
        // the one marker-management affordance now.
        await tester.tap(find.byIcon(Icons.face).first);
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(find.text(l10n.clearCast), findsOneWidget);
        expect(find.byIcon(Icons.edit_outlined), findsWidgets);
        expect(find.byTooltip(l10n.editCast), findsWidgets);
      },
    );

    testWidgets('"Fjern markør" (in the marker sheet) clears the cast for '
        'role A', (tester) async {
      await tester.pumpWidget(_buildView());
      await tester.pumpAndSettle();
      await _expandTileAt(tester, 0);

      await tester.tap(find.byIcon(Icons.face).first);
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.clearCast));
      await tester.pumpAndSettle();

      // After clearing, the uncast "No actor" pill appears (no longer cast).
      expect(find.text(l10n.noCastLine), findsWidgets);
    });
  });

  group('Cast section — actor without phone (role B)', () {
    testWidgets('actor realName shown in expanded body', (tester) async {
      await tester.pumpWidget(_buildView());
      await tester.pumpAndSettle();
      await _expandTileAt(tester, 1);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.castedByLine(_actorB.realName)), findsOneWidget);
    });

    testWidgets('phone number not rendered when actor.phone is null',
        (tester) async {
      await tester.pumpWidget(_buildView());
      await tester.pumpAndSettle();
      await _expandTileAt(tester, 1);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // Actor name is present
      expect(find.text(l10n.castedByLine(_actorB.realName)), findsOneWidget);
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

    testWidgets('filter icon is in AppBar actions when active program exists',
        (tester) async {
      await tester.pumpWidget(_buildView());
      await tester.pumpAndSettle();

      // Filter moved from body FAB to AppBar action in Step 2.
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
    });

    testWidgets('"Nytt spill" FAB is present when active program exists',
        (tester) async {
      await tester.pumpWidget(_buildView());
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.newPlay), findsOneWidget);
    });
  });

  group('Adaptive selectors (ADR-0049)', () {
    testWidgets('the exercise filter opens the adaptive picker', (tester) async {
      await tester.pumpWidget(_buildView());
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();

      // Title + "All exercises" + the seeded exercise, via showRingdrillPicker
      // (no radios). The default 800×600 test surface is medium → a dialog.
      expect(find.text(l10n.pickerFilterByExerciseTitle), findsOneWidget);
      expect(find.text(l10n.allExercises), findsOneWidget);
      expect(find.text('Test Exercise RV'), findsWidgets);
    });

    testWidgets('"Nytt spill" opens the adaptive exercise picker',
        (tester) async {
      await tester.pumpWidget(_buildView());
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.text(l10n.newPlay));
      await tester.pumpAndSettle();

      expect(find.text(l10n.pickExerciseForRole), findsOneWidget);
      expect(find.text('Test Exercise RV'), findsWidgets);
    });
  });

  group('Collapsed tile — subtitle and title (Step 3)', () {
    testWidgets(
        'subtitle shows roleSubtitleStation when stationIndex is set',
        (tester) async {
      await tester.pumpWidget(_buildView());
      await tester.pumpAndSettle();

      // Both roles have stationIndex: 0 → the subtitle names the station,
      // now prefixed with the formatted post number (e.g. "1.1 Post Alpha").
      expect(find.textContaining(_stationName), findsWidgets);
    });

    testWidgets('collapsed title includes cast marker first name in parens '
        '(role B)', (tester) async {
      await tester.pumpWidget(_buildView());
      await tester.pumpAndSettle();

      // Role B: name 'Vitne X', no age, cast to actorB ('Ola Nordmann').
      // Collapsed, the parenthesis shows only the marker's first name (Fix 4).
      // Role B was never cleared in any prior test — safe to assert here.
      expect(find.text('Vitne X (${_actorB.firstName})'), findsOneWidget);
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
