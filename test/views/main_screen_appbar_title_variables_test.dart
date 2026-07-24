import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/shell/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DESIGN-008 follow-up 11 — the Plan tab's AppBar title (the plan
/// name) resolves `{{var.<name>}}` under `MainScreen`'s own `PlanScope`.
/// Drives the real app through `buildRouter`/go_router rather than
/// pumping `MainScreen` directly, so the `PlanScope` under test is the
/// one `MainScreen.build()` actually provides, not a hand-wrapped stand-in.

const _planUuid = 'prog-appbar-title';

Map<String, Object> _basePrefs() => {
  'app:activePlan:v1': _planUuid,
  'app:librarySchema:v1': '1',
  'p:$_planUuid': jsonEncode({
    'uuid': _planUuid,
    'name': 'LSOR Eidene {{var.year}}',
    'description': '',
    'metadata': {
      'created': '2026-01-01T00:00:00.000Z',
      'updated': '2026-01-01T00:00:00.000Z',
      'version': '1.2',
    },
    'exercises': [],
    'teams': [],
    'sessions': [],
    'rolePlays': [],
    'actors': [],
    'variables': [const DrillVariable(name: 'year', value: '2026').toJson()],
  }),
};

Widget _app(GoRouter router) => MaterialApp.router(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  routerConfig: router,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the Plan tab AppBar title resolves the plan name variable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(_basePrefs());
    await PlanService().init();
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // isOnboardingSeen=true with an active plan already set: '/'
    // redirects straight to the plan path, landing on MainScreen
    // without going through the onboarding primer.
    final router = buildRouter(true, true);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    expect(find.text('LSOR Eidene 2026'), findsWidgets);
    expect(find.textContaining('{{var.year}}'), findsNothing);
  });

  testWidgets(
    'the wide-layout master AppBar title (SheetTitle, follow-up 09) also '
    'resolves the plan name variable',
    (tester) async {
      SharedPreferences.setMockInitialValues(_basePrefs());
      await PlanService().init();
      // Wide enough to trigger MainScreen's rail/master-detail layout.
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = buildRouter(true, true);
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      expect(find.text('LSOR Eidene 2026'), findsWidgets);
      expect(find.textContaining('{{var.year}}'), findsNothing);
    },
  );
}
