import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/roster_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Fixture identifiers — must not collide with roster_view_test.dart (separate
// isolate, but keeps the intent clear).
const _programUuid = 'roster-pull-refresh';
const _actorUuid = 'actor-pull-refresh';

/// A program installed from the catalog (`source.runtimeType == 'catalog'`),
/// the precondition `active_actions.isCatalogProgram` checks before
/// roster_view.dart wraps its list in a `RefreshIndicator`.
Map<String, Object> _catalogProgramPrefs() {
  return {
    'app:activeProgram:v1': _programUuid,
    'app:librarySchema:v1': '1',
    'p:$_programUuid': jsonEncode({
      'uuid': _programUuid,
      'name': 'Catalog Program',
      'description': '',
      'metadata': {
        'created': '2026-01-01T00:00:00.000Z',
        'updated': '2026-01-01T00:00:00.000Z',
        'version': '1.1',
      },
      'source': {
        'runtimeType': 'catalog',
        'slug': 'roster-pull-refresh-plan',
        'latestEtag': 'etag-1',
        'installedAt': '2026-01-01T00:00:00.000Z',
      },
      'exercises': [],
      'teams': [],
      'sessions': [],
      'rolePlays': [],
      'actors': [],
    }),
    'pa:$_programUuid:$_actorUuid': jsonEncode({
      'uuid': _actorUuid,
      'realName': 'Per Hansen',
    }),
  };
}

Widget _harness() {
  final controller = RosterController();
  addTearDown(controller.dispose);
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: RosterView(controller: controller)),
  );
}

void main() {
  testWidgets(
    'dragging down on a catalog-sourced plan triggers RefreshIndicator',
    (tester) async {
      SharedPreferences.setMockInitialValues(_catalogProgramPrefs());
      await ProgramService().init();

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
        find.byType(ListView).first,
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
