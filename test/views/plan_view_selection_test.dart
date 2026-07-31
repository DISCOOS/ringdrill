// Selection indication in the master list, on medium/expanded form factors.
//
// The bug: tapping an exercise opened it in the detail pane, but the master list
// showed no selection. `MasterDetailScope.maybeOf` reads the scope with
// `getElementForInheritedWidgetOfExactType`, which deliberately creates *no*
// dependency — so a caller that only reads `target.value` never rebuilds when the
// selection changes. `roleplay_list_view.dart` subscribes explicitly with a
// `ValueListenableBuilder`; the exercise and station lists did not, so their
// `selected` flag was computed once at first build and never again.
//
// Driven through the notifier rather than a tap: the notifier *is* the mechanism, and
// a test that taps would also be testing the shell's routing.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/plan_view.dart';
import 'package:ringdrill/views/roleplay_list_view.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/station_list_view.dart';
import 'package:ringdrill/views/teams_view.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestPlanController extends PlanPageControllerBase {
  _TestPlanController({
    required super.stationListController,
    required super.rolePlaysController,
    required super.teamsPageController,
  });
}

const _planUuid = 'sel-plan';
const _exerciseA = 'ex-a';
const _exerciseB = 'ex-b';

Exercise _exercise(
  String uuid,
  int index,
  String name, {
  required String stationName,
}) => Exercise(
  uuid: uuid,
  index: index,
  name: name,
  startTime: SimpleTimeOfDay(hour: 8, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 8, minute: 30),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 20,
  evaluationTime: 5,
  rotationTime: 5,
  schedule: const [],
  stations: [Station(index: 0, name: stationName)],
);

Plan _plan() {
  final now = DateTime.utc(2026, 1, 1);
  return Plan(
    uuid: _planUuid,
    name: 'Utvalgsplan',
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.1'),
    teams: const [],
    sessions: const [],
    rolePlays: const [],
    staff: const [],
    exercises: [
      _exercise(_exerciseA, 0, 'Øve oppstart', stationName: 'Turgåer'),
      _exercise(_exerciseB, 1, 'Førsteinnsats', stationName: 'Fisker'),
    ],
  );
}

/// `PlanView` under a `MasterDetailScope`, as the wide shell hosts it.
Widget _harness(
  ValueNotifier<ContextSheetTarget?> target, {
  PlanSegment segment = PlanSegment.exercises,
}) {
  final stationList = StationListController();
  final rolePlays = RolePlaysController();
  final controller = _TestPlanController(
    stationListController: stationList,
    rolePlaysController: rolePlays,
    teamsPageController: const TeamsPageController(),
  );
  controller.activeSegment.value = segment;
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: MasterDetailScope(
        target: target,
        emptyPaneBuilder: (_) => const SizedBox.shrink(),
        child: PlanView(
          controller: controller,
          stationListController: stationList,
          rolePlaysController: rolePlays,
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    // Exercises are seeded through their own prefs keys, the way the sibling
    // plan-view tests do: `saveExercise` reassigns indices and needs
    // localizations, neither of which this test wants.
    final plan = _plan();
    SharedPreferences.setMockInitialValues({
      'app:activePlan:v1': _planUuid,
      'app:librarySchema:v1': '1',
      'p:$_planUuid': jsonEncode(plan.toJson()),
      for (final ex in plan.exercises)
        'pe:$_planUuid:${ex.uuid}': jsonEncode(ex.toJson()),
    });
    await PlanService().init();
  });

  ExerciseCard cardFor(WidgetTester tester, String name) => tester.widget(
    find.ancestor(of: find.text(name), matching: find.byType(ExerciseCard)),
  );

  testWidgets('the master list marks the selected exercise', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final target = ValueNotifier<ContextSheetTarget?>(null);
    addTearDown(target.dispose);

    await tester.pumpWidget(_harness(target));
    await tester.pumpAndSettle();

    expect(cardFor(tester, 'Øve oppstart').selected, isFalse);

    // What tapping a row does, via the shell.
    target.value = const ExerciseSheetTarget(exerciseUuid: _exerciseA);
    await tester.pumpAndSettle();

    expect(
      cardFor(tester, 'Øve oppstart').selected,
      isTrue,
      reason: 'the row the detail pane is showing must look selected',
    );
    expect(cardFor(tester, 'Førsteinnsats').selected, isFalse);
  });

  testWidgets('selection moves with the target, and clears', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final target = ValueNotifier<ContextSheetTarget?>(
      const ExerciseSheetTarget(exerciseUuid: _exerciseA),
    );
    addTearDown(target.dispose);

    await tester.pumpWidget(_harness(target));
    await tester.pumpAndSettle();
    expect(cardFor(tester, 'Øve oppstart').selected, isTrue);

    target.value = const ExerciseSheetTarget(exerciseUuid: _exerciseB);
    await tester.pumpAndSettle();
    expect(cardFor(tester, 'Øve oppstart').selected, isFalse);
    expect(cardFor(tester, 'Førsteinnsats').selected, isTrue);

    target.value = null;
    await tester.pumpAndSettle();
    expect(cardFor(tester, 'Førsteinnsats').selected, isFalse);
  });

  testWidgets('the station list marks the selected station too', (
    tester,
  ) async {
    // Same defect, same shape: `station_list_view.dart` also read `.value` from a
    // scope that creates no dependency.
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final target = ValueNotifier<ContextSheetTarget?>(null);
    addTearDown(target.dispose);

    await tester.pumpWidget(_harness(target, segment: PlanSegment.stations));
    await tester.pumpAndSettle();

    // A station row is an ExpandableTile carrying `selected`.
    ExpandableTile tileFor(String name) => tester.widget(
      find.ancestor(of: find.text(name), matching: find.byType(ExpandableTile)),
    );

    expect(tileFor('Turgåer').selected, isFalse);

    target.value = const StationSheetTarget(
      exerciseUuid: _exerciseA,
      stationIndex: 0,
    );
    await tester.pumpAndSettle();

    expect(tileFor('Turgåer').selected, isTrue);
  });
}
