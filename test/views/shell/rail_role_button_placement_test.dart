import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/shell/app_router.dart';
import 'package:ringdrill/views/widgets/app_user_role_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The rail's role selector (ADR-0057 — what this device may *edit*) is not a
/// navigation destination, and used to read as one: `NavigationRail` places its
/// `trailing` slot directly under the last destination unless
/// `trailingAtBottom` is set, so the role icon sat in the tab stack at the same
/// rhythm as the tabs and looked like a fourth tab.
///
/// It is now pinned to the bottom of the rail with a divider above it. The
/// divider is deliberately a divider and not a border around the icon: the rail
/// marks the selected destination with a filled pill, so a persistent outline
/// would read as "selected".
const _p = 'prog-rail-role';
const _exA = 'ex-rail-role';

final _a = Exercise(
  uuid: _exA,
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

Future<void> _pumpWideShell(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({
    'app:activePlan:v1': _p,
    'app:librarySchema:v1': '1',
    'p:$_p': jsonEncode({
      'uuid': _p,
      'name': 'P',
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
    'pe:$_p:$_exA': jsonEncode(_a.toJson()),
  });
  await PlanService().init();
  await PlanService().setActive(_p);

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

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

void main() {
  testWidgets('the role selector sits at the bottom of the rail, not in the '
      'tab stack', (tester) async {
    // Tall enough that "after the last tab" and "at the bottom" are far apart —
    // on a short viewport the two coincide and the test would pass either way.
    await _pumpWideShell(tester, const Size(900, 900));

    final rail = tester.getRect(find.byType(NavigationRail));
    final role = tester.getRect(find.byType(AppUserRoleButton));
    final lastTab = tester.getRect(find.byIcon(Icons.badge));

    // Pinned to the bottom: below every destination, and near the rail's own
    // bottom edge rather than trailing the last one.
    expect(role.top, greaterThan(lastTab.bottom));
    expect(rail.bottom - role.bottom, lessThan(24));
    expect(role.top - lastTab.bottom, greaterThan(100));
  });

  testWidgets('a divider separates it from the destinations', (tester) async {
    await _pumpWideShell(tester, const Size(900, 900));

    final divider = find.descendant(
      of: find.byType(NavigationRail),
      matching: find.byType(Divider),
    );
    expect(divider, findsOneWidget);

    // Above the role icon, and actually painted: a Divider handed loose
    // constraints collapses to zero width and shows nothing at all, which is
    // exactly what happened before the width was made explicit.
    final dividerRect = tester.getRect(divider);
    expect(
      dividerRect.bottom,
      lessThan(tester.getRect(find.byType(AppUserRoleButton)).top),
    );
    expect(dividerRect.width, greaterThan(0));
  });
}
