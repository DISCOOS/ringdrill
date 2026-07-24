import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/shell/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression guard for the short-viewport rail overflow: `NavigationRail`
/// lays its leading + destinations + trailing out in a non-scrolling,
/// min-sized Column, so on a short viewport (a landscape phone still wide
/// enough to read as the medium/expanded master-detail shell) the items were
/// taller than the available height and the rail overflowed by ~14px. The
/// wide shell now wraps the rail in a scroll view so it scrolls instead.
const _p = 'prog-rail-short';
const _exA = 'ex-rail-short';

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

void main() {
  testWidgets(
    'the navigation rail scrolls instead of overflowing on a short '
    'medium-width viewport (a landscape phone)',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'app:activeProgram:v1': _p,
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
      await ProgramService().init();
      await ProgramService().setActive(_p);

      // Wide enough for the master-detail rail shell — the wide layout needs
      // `maxWidth - railWidth(72) - masterWidth(320) >= 360`, so ~752px up,
      // still medium (<840) — but short enough that the rail's items exceed
      // the available height.
      tester.view.physicalSize = const Size(800, 260);
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

      expect(find.byType(NavigationRail), findsOneWidget);
      // No RenderFlex overflow was thrown while laying the rail out.
      expect(tester.takeException(), isNull);
    },
  );
}
