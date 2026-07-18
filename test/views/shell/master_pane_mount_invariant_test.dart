/// Verifies that the master pane's element tree (and therefore every segment
/// page inside `tabs`) is NOT disposed or re-initialised when the user
/// toggles the collapse button.
///
/// The observable proxy for "no rebuild": if a segment page ran `initState`
/// again it would trigger auto-select-first, overwriting any explicit pick.
/// So a selection made before collapsing that is still present after
/// re-expanding proves the segment page was never recreated.
///
/// Also checks that collapsed vs expanded correctly distributes width
/// between the master and detail panes.
library;

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/shell/app_router.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _programUuid = 'program-mount-invariant';
const _exerciseAUuid = 'exercise-mount-a';
const _exerciseBUuid = 'exercise-mount-b';

final _exerciseA = Exercise(
  uuid: _exerciseAUuid,
  name: 'Mount Exercise A',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [Station(index: 0, name: 'Mount Station A1')],
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
  name: 'Mount Exercise B',
  startTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [Station(index: 0, name: 'Mount Station B1')],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 9, minute: 0),
      SimpleTimeOfDay(hour: 9, minute: 10),
      SimpleTimeOfDay(hour: 9, minute: 15),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 9, minute: 17),
);

Map<String, Object> _prefs() => {
  'app:activeProgram:v1': _programUuid,
  'app:librarySchema:v1': '1',
  'p:$_programUuid': jsonEncode({
    'uuid': _programUuid,
    'name': 'Mount Invariant Program',
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> _pumpWide(WidgetTester tester) async {
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

double _detailWidth(WidgetTester tester) {
  // The detail pane is the Expanded child of the master/detail Row — find
  // MasterDetailPane and measure its rendered width.
  final el = tester.element(find.byType(MasterDetailPane).first);
  final rb = el.renderObject as RenderBox;
  return rb.size.width;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(_prefs());
    await ProgramService().init();
  });

  testWidgets(
    'segment-page state (selection) survives a collapse → re-expand toggle',
    (tester) async {
      await _pumpWide(tester);

      // Auto-selected: Mount Exercise A.
      expect(find.text('Mount Station A1'), findsOneWidget);

      // Explicitly pick Mount Exercise B.
      await tester.tap(find.text('Mount Exercise B').first);
      await tester.pumpAndSettle();
      expect(find.text('Mount Station B1'), findsOneWidget);

      // Collapse the master pane.
      final toggle = find.byIcon(CupertinoIcons.sidebar_left);
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      // Detail is still showing Mount Station B1 — the context sheet target
      // is preserved even though the master pane is now hidden.
      expect(find.text('Mount Station B1'), findsOneWidget);

      // Re-expand.
      await tester.tap(find.byIcon(CupertinoIcons.sidebar_left));
      await tester.pumpAndSettle();

      // INVARIANT: if the exercises segment page had run initState again it
      // would have auto-selected the first exercise (A), replacing B. The
      // fact that B's station is still showing proves the segment page was
      // never disposed or re-initialised.
      expect(find.text('Mount Station B1'), findsOneWidget);
      expect(find.text('Mount Station A1'), findsNothing);
    },
  );

  testWidgets(
    'collapsed detail fills the full shell width; expanded restores masterWidth',
    (tester) async {
      await _pumpWide(tester);

      final expandedDetailWidth = _detailWidth(tester);

      // Collapse: the master pane clips to 0 visible width, so the detail
      // pane should be wider (gains at least the master content width).
      final toggle = find.byIcon(CupertinoIcons.sidebar_left);
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      final collapsedDetailWidth = _detailWidth(tester);

      // Collapsed detail must be wider than expanded detail.
      expect(
        collapsedDetailWidth,
        greaterThan(expandedDetailWidth),
        reason:
            'collapsed detail ($collapsedDetailWidth) should fill the space '
            'freed by the hidden master pane (was $expandedDetailWidth)',
      );

      // Re-expand: detail returns to the original narrower width.
      await tester.tap(find.byIcon(CupertinoIcons.sidebar_left));
      await tester.pumpAndSettle();

      expect(
        _detailWidth(tester),
        moreOrLessEquals(expandedDetailWidth, epsilon: 1),
        reason: 're-expanding must restore the original detail width',
      );
    },
  );

  testWidgets(
    'Map tab is unaffected: no sidebar toggle, no master/detail split',
    (tester) async {
      await _pumpWide(tester);

      // Navigate to the Map tab.
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.byIcon(Icons.map),
        ),
      );
      await tester.pumpAndSettle();

      // Map tab has no sidebar toggle and no MasterDetailPane.
      expect(find.byIcon(CupertinoIcons.sidebar_left), findsNothing);
      expect(find.byType(MasterDetailPane), findsNothing);
    },
  );

  testWidgets(
    'narrow layout is unaffected: no sidebar toggle, no master/detail split',
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

      // Narrow layout: no NavigationRail, no sidebar toggle, no MasterDetailPane.
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byIcon(CupertinoIcons.sidebar_left), findsNothing);
      expect(find.byType(MasterDetailPane), findsNothing);
    },
  );
}
