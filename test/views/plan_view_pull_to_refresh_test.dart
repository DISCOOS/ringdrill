import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/plan_view.dart';
import 'package:ringdrill/views/roleplay_list_view.dart';
import 'package:ringdrill/views/station_list_view.dart';
import 'package:ringdrill/views/teams_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Fixture identifiers — must not collide with other plan_view_*_test.dart
// files (separate isolate, but keeps the intent clear).
const _planUuid = 'plan-pull-refresh';
const _exerciseUuid = 'ex-pull-refresh-0';

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  name: 'Pull Refresh Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 0),
      SimpleTimeOfDay(hour: 8, minute: 10),
      SimpleTimeOfDay(hour: 8, minute: 15),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
);

/// A plan installed from the catalog (`source.runtimeType == 'catalog'`),
/// the precondition `active_actions.isCatalogPlan` checks before
/// plan_view.dart wraps the segment scroll view in a `RefreshIndicator`.
Map<String, Object> _catalogPlanPrefs() {
  return {
    'app:activePlan:v1': _planUuid,
    'app:librarySchema:v1': '1',
    'p:$_planUuid': jsonEncode({
      'uuid': _planUuid,
      'name': 'Catalog Plan',
      'description': '',
      'metadata': {
        'created': '2026-01-01T00:00:00.000Z',
        'updated': '2026-01-01T00:00:00.000Z',
        'version': '1.1',
      },
      'source': {
        'runtimeType': 'catalog',
        'slug': 'pull-refresh-plan',
        'latestEtag': 'etag-1',
        'installedAt': '2026-01-01T00:00:00.000Z',
      },
      'exercises': [],
      'teams': [],
      'sessions': [],
      'rolePlays': [],
      'actors': [],
    }),
    'pe:$_planUuid:$_exerciseUuid': jsonEncode(_exercise().toJson()),
  };
}

class _TestPlanController extends PlanPageControllerBase {
  _TestPlanController({
    required super.stationListController,
    required super.rolePlaysController,
    required super.teamsPageController,
  });
}

Widget _harness() {
  final controller = _TestPlanController(
    stationListController: StationListController(),
    rolePlaysController: RolePlaysController(),
    teamsPageController: const TeamsPageController(),
  );
  addTearDown(controller.dispose);
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    // No GoRouter: this test only drags the scroll view, it never taps the
    // segmented switcher (whose `onSelectionChanged` calls `context.go`).
    home: Scaffold(
      body: PlanView(
        controller: controller,
        stationListController: controller.stationListController,
        rolePlaysController: controller.rolePlaysController,
      ),
    ),
  );
}

void main() {
  testWidgets(
    'dragging down on a catalog-sourced plan triggers RefreshIndicator',
    (tester) async {
      SharedPreferences.setMockInitialValues(_catalogPlanPrefs());
      await PlanService().init();

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      // A local plan would get no RefreshIndicator at all (drag-to-update
      // only applies to catalog-sourced plans) — confirm the wrapper is
      // actually present before testing the gesture, so a false negative
      // below can't be mistaken for "the gesture doesn't work".
      expect(find.byType(RefreshIndicator), findsOneWidget);

      // fling (not drag): RefreshIndicator's activation is driven by
      // overscroll notifications carrying real drag velocity, which a
      // multi-step fling produces reliably — a single `tester.drag` call
      // can leave the ballistic/refresh activity ambiguous.
      await tester.fling(
        find.byType(CustomScrollView).first,
        const Offset(0, 300),
        1000,
      );
      // One frame: the indicator should already be armed and spinning,
      // before the (network-backed, and here-unreachable) onRefresh future
      // resolves.
      await tester.pump();
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);

      // Let the network attempt fail (HttpClient calls return 400 under
      // flutter test) and the indicator retract so the test ends clean.
      await tester.pumpAndSettle();
      // The failure snackbar (_RefreshSnackBar in active_plan_actions.dart)
      // schedules its own 4s auto-dismiss timer, which pumpAndSettle doesn't
      // wait out on its own (it stops once no more frames are scheduled, not
      // once every Timer has fired) — advance past it explicitly so the test
      // doesn't end with a timer still pending.
      await tester.pump(const Duration(seconds: 5));
    },
  );
}
