import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:ringdrill/views/shell/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _programUuid = 'program-collapsible-master-pane';
const _exerciseAUuid = 'exercise-collapsible-a';
const _exerciseBUuid = 'exercise-collapsible-b';

final _exerciseA = Exercise(
  uuid: _exerciseAUuid,
  name: 'Exercise A',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [Station(index: 0, name: 'Station A1')],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 0),
      SimpleTimeOfDay(hour: 8, minute: 10),
      SimpleTimeOfDay(hour: 8, minute: 15),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
);

final _exerciseB = Exercise(
  uuid: _exerciseBUuid,
  name: 'Exercise B',
  startTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [Station(index: 0, name: 'Station B1')],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 9, minute: 0),
      SimpleTimeOfDay(hour: 9, minute: 10),
      SimpleTimeOfDay(hour: 9, minute: 15),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 9, minute: 17),
);

Map<String, Object> _prefs() {
  return {
    'app:activeProgram:v1': _programUuid,
    'app:librarySchema:v1': '1',
    'p:$_programUuid': jsonEncode({
      'uuid': _programUuid,
      'name': 'Collapsible Master Pane Program',
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
    'pe:$_programUuid:$_exerciseAUuid': jsonEncode(_exerciseA.toJson()),
    'pe:$_programUuid:$_exerciseBUuid': jsonEncode(_exerciseB.toJson()),
  };
}

Future<void> _pumpWideApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await ProgramService().setActive(_programUuid);
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

Finder _railIcon(IconData icon) =>
    find.descendant(of: find.byType(NavigationRail), matching: find.byIcon(icon));

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(_prefs());
    await ProgramService().init();
  });

  testWidgets(
    'auto-selects the first exercise; an explicit pick sticks until the '
    'tab is switched away and back',
    (tester) async {
      await _pumpWideApp(tester);

      // Exercises segment auto-selects the first exercise (Exercise A) —
      // its station shows in the detail pane without tapping anything.
      expect(find.text('Station A1'), findsOneWidget);
      expect(find.text('Station B1'), findsNothing);

      // Explicitly picking Exercise B in the master list replaces it —
      // and it is not reverted back to A by any later rebuild.
      await tester.tap(find.text('Exercise B').first);
      await tester.pumpAndSettle();
      expect(find.text('Station B1'), findsOneWidget);
      expect(find.text('Station A1'), findsNothing);

      await tester.pump();
      await tester.pump();
      expect(find.text('Station B1'), findsOneWidget);

      // Switching to another tab and back re-selects the (new) tab's first
      // item — the explicit pick from before the switch does not survive.
      await tester.tap(_railIcon(Icons.map));
      await tester.pumpAndSettle();
      await tester.tap(_railIcon(Icons.update));
      await tester.pumpAndSettle();
      expect(find.text('Station A1'), findsOneWidget);
      expect(find.text('Station B1'), findsNothing);
    },
  );

  testWidgets('the Map tab has no sidebar toggle or close-X of its own', (
    tester,
  ) async {
    await _pumpWideApp(tester);

    await tester.tap(_railIcon(Icons.map));
    await tester.pumpAndSettle();

    expect(find.byIcon(CupertinoIcons.sidebar_left), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets(
    'the sidebar toggle collapses/expands the master pane and stays '
    'present in both states',
    (tester) async {
      await _pumpWideApp(tester);

      // Expanded: the master pane's segment switcher is visible alongside
      // the sidebar toggle in the detail leading.
      expect(find.byType(SegmentedButton<ProgramSegment>), findsOneWidget);
      final toggle = find.byIcon(CupertinoIcons.sidebar_left);
      expect(toggle, findsOneWidget);

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      // Collapsed: the master pane is gone, the detail pane's content
      // stays, and the toggle is still there (same control, now "show").
      expect(find.byType(SegmentedButton<ProgramSegment>), findsNothing);
      expect(find.text('Station A1'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.sidebar_left), findsOneWidget);

      await tester.tap(find.byIcon(CupertinoIcons.sidebar_left));
      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton<ProgramSegment>), findsOneWidget);
    },
  );

  testWidgets(
    'the master-pane-collapsed preference persists across an app restart',
    (tester) async {
      await _pumpWideApp(tester);

      await tester.tap(find.byIcon(CupertinoIcons.sidebar_left));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<ProgramSegment>), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppConfig.keyMasterPaneCollapsed), isTrue);

      // Simulate an app restart: a fresh router and MainScreen State reading
      // the same (persisted) SharedPreferences store from scratch.
      await _pumpWideApp(tester);
      expect(find.byType(SegmentedButton<ProgramSegment>), findsNothing);
    },
  );

  testWidgets(
    'narrow layout keeps the close-X, does not auto-select, and has no '
    'collapse concept',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await ProgramService().setActive(_programUuid);
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

      // No auto-select in narrow: nothing opens on its own.
      expect(find.text('Station A1'), findsNothing);
      expect(find.byIcon(CupertinoIcons.sidebar_left), findsNothing);

      await tester.tap(find.text('Exercise A').first);
      await tester.pumpAndSettle();

      // The opened sheet keeps the close-X, never the sidebar toggle.
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.sidebar_left), findsNothing);
    },
  );
}
