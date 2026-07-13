import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/position_widget.dart';
import 'package:ringdrill/views/shell/wide_detail_map_split.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:ringdrill/views/widgets/station_position_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// DESIGN-010 post-spill-expanded-map-split: at a pane width >= 840 the Post
// viewer now mirrors the coordinator's expanded body — the map panel (with
// its legend and coordinate row) moves to a fixed full-height right pane
// beside a capped, independently-scrolling left column
// (Postbeskrivelse/Personer/Lokasjoner/Tidsplan), via the shared
// `WideDetailMapSplit`. Compact and medium keep today's single scrolling
// column. The station carries a position and several locations here (unlike
// most other Post viewer tests) so the legend actually renders and the
// expanded map pane's height math is exercised against real content, not
// just an empty placeholder.
// ---------------------------------------------------------------------------

const _programUuid = 'prog-station-expanded-layout';
const _exerciseUuid = 'ex-station-expanded-layout';

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  name: 'Station Expanded Layout Test Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [
    Station(
      index: 0,
      name: 'Post 1',
      description: 'Beskrivelse av post 1.',
      persons: [Person(slug: 'hilde', name: 'Hilde', age: 34)],
      locations: [Location(slug: 'lkp', label: 'LKP', kind: LocationKind.lkp)],
      position: LatLng(59.9, 10.7),
    ),
  ],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 0),
      SimpleTimeOfDay(hour: 8, minute: 10),
      SimpleTimeOfDay(hour: 8, minute: 15),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
);

Future<void> _seedAndInit() async {
  final ex = _exercise();
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
    'pe:$_programUuid:$_exerciseUuid': jsonEncode(ex.toJson()),
  });
  await ProgramService().init();
}

Widget _harness(Widget widget) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: widget,
);

/// Pumps [StationExerciseScreen] with the test binding reporting a wide
/// (1200x800) window, but the widget itself constrained to [paneWidth] via
/// an ancestor `SizedBox` — reproducing "wide window, narrow pane" the way
/// the coordinator's own pane-local-breakpoint test does, so this proves the
/// split is driven by the pane's own width, not `MediaQuery`'s window width.
Future<void> _pumpAtPaneWidth(WidgetTester tester, double paneWidth) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await _seedAndInit();

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: paneWidth,
          height: 800,
          child: const StationExerciseScreen(
            stationIndex: 0,
            uuid: _exerciseUuid,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets(
    'a narrow (700px) pane stacks — no WideDetailMapSplit, no overflow',
    (tester) async {
      await _seedAndInit();
      tester.view.physicalSize = const Size(700, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _harness(
          const StationExerciseScreen(stationIndex: 0, uuid: _exerciseUuid),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(WideDetailMapSplit), findsNothing);
      // The stacked body still renders every section, in one column.
      expect(
        find.text(l10n.postDescriptionCardTitle.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text(l10n.personsSectionTitle.toUpperCase()), findsOneWidget);
      expect(
        find.text(l10n.stationTimingCardTitle.toUpperCase()),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'an expanded (900px) pane splits — map pane beside a capped left '
    'column, no overflow',
    (tester) async {
      await _seedAndInit();
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _harness(
          const StationExerciseScreen(stationIndex: 0, uuid: _exerciseUuid),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(WideDetailMapSplit), findsOneWidget);
      // Every section is still present, now split across the two panes.
      expect(
        find.text(l10n.postDescriptionCardTitle.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text(l10n.personsSectionTitle.toUpperCase()), findsOneWidget);
      expect(
        find.text(l10n.stationTimingCardTitle.toUpperCase()),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a ~430px pane inside a 1200px window stacks — pane width drives the '
    'split, not the window',
    (tester) async {
      await _pumpAtPaneWidth(tester, 430);

      expect(tester.takeException(), isNull);
      expect(find.byType(WideDetailMapSplit), findsNothing);
    },
  );

  testWidgets(
    'a >= 840px pane inside a 1200px window still splits — the pane, not '
    'the window, is what drives it',
    (tester) async {
      await _pumpAtPaneWidth(tester, 900);

      expect(tester.takeException(), isNull);
      expect(find.byType(WideDetailMapSplit), findsOneWidget);
    },
  );

  testWidgets(
    'the expanded map panel fills the pane height, with the coordinate bar '
    'pinned at the bottom — no fixed-height gap',
    (tester) async {
      await _seedAndInit();
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _harness(
          const StationExerciseScreen(stationIndex: 0, uuid: _exerciseUuid),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final splitHeight = tester.getSize(find.byType(WideDetailMapSplit)).height;
      final panelRect = tester.getRect(find.byType(StationPositionPanel));

      // The panel used to sit at a small fixed height (~200) regardless of
      // how tall the pane was, leaving an empty gap below it — now it
      // fills the pane's full height instead.
      expect(panelRect.height, closeTo(splitHeight, 1));
      expect(panelRect.height, greaterThan(400));

      // The coordinate bar (holding the UTM position) sits at the very
      // bottom of the filled panel, not floating with a gap beneath it.
      final barBottom = tester.getRect(find.byType(PositionWidget)).bottom;
      expect(barBottom, closeTo(panelRect.bottom, 20));
    },
  );

  testWidgets(
    'a short expanded pane still fills the map with no overflow',
    (tester) async {
      await _seedAndInit();
      tester.view.physicalSize = const Size(900, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _harness(
          const StationExerciseScreen(stationIndex: 0, uuid: _exerciseUuid),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final splitHeight = tester.getSize(find.byType(WideDetailMapSplit)).height;
      final panelRect = tester.getRect(find.byType(StationPositionPanel));
      expect(panelRect.height, closeTo(splitHeight, 1));
    },
  );

  testWidgets(
    'the stacked (compact) layout keeps the panel at its fixed inline '
    'height, unaffected by the expanded fill mode',
    (tester) async {
      await _seedAndInit();
      tester.view.physicalSize = const Size(700, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _harness(
          const StationExerciseScreen(stationIndex: 0, uuid: _exerciseUuid),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final panelRect = tester.getRect(find.byType(StationPositionPanel));
      // Well short of the ~800px window height — the fixed thumbnail
      // height plus legend/bar chrome, not a filled pane.
      expect(panelRect.height, lessThan(350));
    },
  );
}
