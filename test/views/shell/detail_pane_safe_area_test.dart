import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/shell/app_router.dart';
import 'package:ringdrill/views/shell/master_detail_leading.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression guard for the iOS-landscape "empty bar between master and
/// detail": the detail pane sits to the *right* of the rail (which owns the
/// screen's left edge), so its own `SafeArea` must NOT re-apply the
/// full-window left safe-area inset — the wide shell strips it
/// (`MediaQuery.removePadding(removeLeft: true)`). Without that strip, a
/// device left inset (a landscape notch) pushed the whole detail content
/// right by the inset, showing as a dark band (web/no-notch showed none).
const _p = 'prog-detail-safearea';
const _exA = 'ex-detail-safearea';

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
    'the detail pane ignores the left safe-area inset (no phantom band '
    'between master and detail on a landscape notch device)',
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

      // Landscape phone width (>=840 → wide shell) with a fat left safe-area
      // inset standing in for a landscape notch.
      const leftInset = 44.0;
      tester.view.physicalSize = const Size(1000, 460);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(left: leftInset);
      tester.view.viewPadding = const FakeViewPadding(left: leftInset);
      addTearDown(tester.view.reset);

      final router = buildRouter(false, true);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          // iOS landscape is where the bug lived: wrapInRailPadding strips
          // the rail's safe-area inset and re-adds a flat 12 there, while
          // the detail pane must strip its own left inset. On other
          // platforms wrapInRailPadding leaves the inset in place, so the
          // scenario is iOS-specific.
          theme: ThemeData(platform: TargetPlatform.iOS),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      // The detail pane is the second Scaffold (the first is the shell's).
      final detailScaffolds = find.byType(Scaffold);
      expect(detailScaffolds.evaluate().length, greaterThanOrEqualTo(2));
      final detailPane = tester.getRect(detailScaffolds.at(1));

      // Its AppBar leading (MasterDetailLeading) sits at the detail pane's
      // top-left. With the left inset stripped it hugs the pane edge (just
      // the AppBar's own small leading gap); if the inset leaked through it
      // would be pushed ~44px further right.
      final leading = tester.getRect(find.byType(MasterDetailLeading));
      expect(
        leading.left - detailPane.left,
        lessThan(leftInset),
        reason:
            'detail content is offset by the left safe-area inset — the '
            'phantom master/detail band is back',
      );
    },
  );
}
