import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/coordinator_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// DESIGN-010 coordinator-play-and-status-polish follow-up, B2: the
// coordinator's compact/medium bodies keep a `Kart` segment option (the map
// is reached by picking it); the expanded body drops `Kart` from the
// segment (`Poster`/`Lag` only) because it shows the map as a permanent
// pane instead, visible without any segment interaction.
//
// None of this exercise's stations have a `position`, so the map pane
// itself renders the "no location" placeholder rather than an actual
// MapView — that's fine here, since these tests are about *whether the
// pane/segment option exists*, not about marker rendering.
// ---------------------------------------------------------------------------

const _planUuid = 'prog-coordinator-breakpoint-layout';
const _exerciseUuid = 'ex-coordinator-breakpoint-layout';

/// A fixed morning reference, safely clear of midnight for the offset used
/// below (3 minutes) and well before the fixture's own `endTime` (09:00) so
/// it never itself reads as "past end".
final _fixedNow = DateTime(2026, 1, 1, 8, 0);

/// A [SimpleTimeOfDay] [minutesAgo] before [_fixedNow] — pairs with
/// [ExerciseService.debugNowOverride] pinned to [_fixedNow] so a test is
/// not at the mercy of real wall-clock time. A bare
/// `DateTime.now().subtract(...)` loses its date once truncated to
/// [SimpleTimeOfDay] (hour/minute only): whenever the real current time was
/// less than the subtracted offset past midnight, the synthetic start time
/// landed on the previous day and the exercise looked scheduled in the
/// future (pending) instead of already running — flaky in exactly the
/// first `minutesAgo` minutes after midnight.
SimpleTimeOfDay _startTimeMinutesAgo(int minutesAgo) {
  final past = _fixedNow.subtract(Duration(minutes: minutesAgo));
  return SimpleTimeOfDay(hour: past.hour, minute: past.minute);
}

Exercise _exercise({required SimpleTimeOfDay startTime}) => Exercise(
  uuid: _exerciseUuid,
  name: 'Coordinator Breakpoint Layout Test Exercise',
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
    'app:activePlan:v1': _planUuid,
    'app:librarySchema:v1': '1',
    'p:$_planUuid': jsonEncode({
      'uuid': _planUuid,
      'name': 'Test Plan',
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
    'pe:$_planUuid:$_exerciseUuid': jsonEncode(exercise.toJson()),
  });
  await PlanService().init();
}

Widget _harness(Widget widget) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: widget,
);

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final exercise = _exercise(startTime: _startTimeMinutesAgo(3));
    await _seedAndInit(exercise);
    ExerciseService().debugNowOverride = () => _fixedNow;
    addTearDown(() => ExerciseService().debugNowOverride = DateTime.now);
    ExerciseService().start(exercise);

    await tester.pumpWidget(
      _harness(const CoordinatorScreen(uuid: _exerciseUuid)),
    );
    await tester.pump();
  }

  Future<void> stop(WidgetTester tester) async {
    ExerciseService().stop();
    await tester.pump();
  }

  testWidgets('compact includes a Kart segment option', (tester) async {
    await pumpAt(tester, const Size(360, 800));
    expect(find.text(l10n.mapTab), findsOneWidget);
    expect(find.textContaining(l10n.stationsTab), findsWidgets);
    await stop(tester);
  });

  testWidgets('medium includes a Kart segment option', (tester) async {
    await pumpAt(tester, const Size(760, 800));
    expect(find.text(l10n.mapTab), findsOneWidget);
    await stop(tester);
  });

  testWidgets(
    'expanded drops the Kart segment option and shows the map pane without '
    'any segment interaction',
    (tester) async {
      await pumpAt(tester, const Size(1180, 800));

      // No Kart segment — the map is always visible instead.
      expect(find.text(l10n.mapTab), findsNothing);

      // Still on the default "Stations" segment (never tapped Kart/Lag),
      // yet the map pane's placeholder is already showing — proof it is a
      // permanent pane, not gated behind the segment. The placeholder is the
      // teaching empty state now, so its title is what identifies it.
      expect(find.text(l10n.noPositionTitle), findsOneWidget);
      await stop(tester);
    },
  );
}
