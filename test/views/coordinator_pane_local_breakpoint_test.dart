import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/coordinator_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// DESIGN-010 coordinator-play-and-status-polish follow-up: coordinator-pane-
// local-breakpoint. The coordinator must pick compact/medium/expanded from
// its own available width (e.g. the detail pane inside the wide
// master/detail shell), not `MediaQuery`'s whole-window width — otherwise it
// tries to render the expanded two-pane (map-right) body inside a pane far
// narrower than the window, overflowing on the right.
//
// Both cases here pump `CoordinatorScreen` as `home:` inside an `Align` +
// `SizedBox` of the target pane width while the test binding reports a wide
// (1200px) window — `SizedBox` narrows the local layout constraints without
// touching `MediaQuery.sizeOf`, reproducing "wide window, narrow pane".
// ---------------------------------------------------------------------------

const _programUuid = 'prog-coordinator-pane-local-breakpoint';
const _exerciseUuid = 'ex-coordinator-pane-local-breakpoint';

Exercise _exercise({required SimpleTimeOfDay startTime}) => Exercise(
  uuid: _exerciseUuid,
  name: 'Coordinator Pane Local Breakpoint Test Exercise',
  startTime: startTime,
  numberOfTeams: 2,
  numberOfRounds: 2,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 5,
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
    [
      SimpleTimeOfDay(hour: 8, minute: 20),
      SimpleTimeOfDay(hour: 8, minute: 30),
      SimpleTimeOfDay(hour: 8, minute: 35),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
);

Future<void> _seedAndInit(Exercise exercise) async {
  SharedPreferences.setMockInitialValues({
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
    'pe:$_programUuid:$_exerciseUuid': jsonEncode(exercise.toJson()),
  });
  await ProgramService().init();
}

/// Pumps `CoordinatorScreen` with the test binding reporting a wide
/// (1200x800) window, but the widget itself constrained to [paneWidth] via
/// an ancestor `SizedBox` — MediaQuery keeps reporting the full window size
/// regardless, so this reproduces "wide window, narrow pane" without
/// touching `MediaQuery`.
Future<void> _pumpAtPaneWidth(WidgetTester tester, double paneWidth) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final past = DateTime.now().subtract(const Duration(minutes: 3));
  final exercise = _exercise(
    startTime: SimpleTimeOfDay(hour: past.hour, minute: past.minute),
  );
  await _seedAndInit(exercise);
  ExerciseService().start(exercise);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: paneWidth,
          height: 800,
          child: const CoordinatorScreen(uuid: _exerciseUuid),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _stop(WidgetTester tester) async {
  ExerciseService().stop();
  await tester.pump();
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets(
    'a ~430px pane inside a 1200px window renders compact/medium — no '
    'overflow, Kart segment present, no expanded map pane',
    (tester) async {
      await _pumpAtPaneWidth(tester, 430);

      // The bug: reading MediaQuery's 1200px window instead of the pane's
      // own 430px would pick `expanded` and overflow the two-pane body.
      expect(tester.takeException(), isNull);

      expect(find.text(l10n.mapTab), findsOneWidget);
      // Still on the default "Stations" segment — the expanded body's
      // permanent map pane would show this placeholder without any
      // interaction; its absence confirms the expanded body was not used.
      expect(find.text(l10n.noLocation), findsNothing);

      await _stop(tester);
    },
  );

  testWidgets(
    'a >= 840px pane inside a 1200px window still renders expanded — map '
    'pane shown, no Kart segment',
    (tester) async {
      await _pumpAtPaneWidth(tester, 900);

      expect(tester.takeException(), isNull);

      expect(find.text(l10n.mapTab), findsNothing);
      expect(find.text(l10n.noLocation), findsOneWidget);

      await _stop(tester);
    },
  );
}
