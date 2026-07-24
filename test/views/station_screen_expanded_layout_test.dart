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
    'a medium (700px) pane uses the Info/Script/Map selector, not '
    'WideDetailMapSplit; Info shows description + schedule, Script shows '
    'persons + locations',
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

      // Default Info segment: description + schedule; persons (Script) not
      // yet visible.
      expect(
        find.text(l10n.postDescriptionCardTitle.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(l10n.stationTimingCardTitle.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text(l10n.personsSectionTitle.toUpperCase()), findsNothing);

      // Script segment: persons + locations.
      await tester.tap(find.byIcon(Icons.theater_comedy));
      await tester.pumpAndSettle();
      expect(find.text(l10n.personsSectionTitle.toUpperCase()), findsOneWidget);
      expect(
        find.text(l10n.locationsSectionTitle.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(l10n.postDescriptionCardTitle.toUpperCase()),
        findsNothing,
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
    'the medium (700px) layout shows the Info/Map selector; the Map segment '
    'fills the floored viewport-derived height (no WideDetailMapSplit)',
    (tester) async {
      await _seedAndInit();
      // 700px width is medium (600-839), not compact — the segmented
      // Info/Map body, not WideDetailMapSplit.
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

      // The panel lives behind the Map segment; select it, then assert the
      // map fills the floored (viewportHeight - 220).clamp(240, inf) height.
      // The panel is the map card (mapHeight) plus its coordinate bar and
      // legend chrome, so assert approximately, not an exact raw difference.
      await tester.tap(find.byIcon(Icons.map));
      await tester.pumpAndSettle();

      final panelRect = tester.getRect(find.byType(StationPositionPanel));
      expect(panelRect.height, greaterThan(240));
      expect(panelRect.height, lessThan(800));
    },
  );

  testWidgets(
    'a short medium viewport (800x375, landscape phone) floors the Map '
    "segment's height and scrolls — no overflow",
    (tester) async {
      await _seedAndInit();
      tester.view.physicalSize = const Size(800, 375);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _harness(
          const StationExerciseScreen(stationIndex: 0, uuid: _exerciseUuid),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.map));
      await tester.pumpAndSettle();

      // (375 - 220) < 240, so the map clamps *up* to the 240 floor and the
      // SingleChildScrollView scrolls — never overflows.
      expect(tester.takeException(), isNull);
      final panelRect = tester.getRect(find.byType(StationPositionPanel));
      expect(panelRect.height, greaterThan(240));
    },
  );

  testWidgets(
    'the expanded map pane is directly interactive with its own FAB '
    'commands, even at a pane width just past the 840px split threshold',
    (tester) async {
      await _seedAndInit();
      // Deliberately close to (not far past) the 840px expanded threshold:
      // WideDetailMapSplit's own fixed-width left column (440px) plus its
      // 16px gutter leaves the map pane itself only ~410px wide here — a
      // real regression left the map static in exactly this range, because
      // an earlier version of the mini-maps' interactive gate re-checked
      // WindowSizeClass off that narrower *local* map-pane width instead
      // of trusting fillHeight (already only ever true once the screen
      // itself committed to its expanded layout) plus a height check.
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
      expect(find.byIcon(Icons.center_focus_strong_rounded), findsOneWidget);
      expect(find.byIcon(Icons.open_in_full), findsOneWidget);
      expect(find.byIcon(Icons.layers), findsOneWidget);
    },
  );

  testWidgets(
    'medium body defaults to the Info segment (no map yet); selecting Map '
    'reveals a directly interactive map with its own FAB commands',
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

      // Two segments (info_outline + map icons), defaulting to Info: no map
      // is rendered yet.
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.byIcon(Icons.map), findsOneWidget);
      expect(find.byType(StationPositionPanel), findsNothing);
      expect(find.byIcon(Icons.center_focus_strong_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.map));
      await tester.pumpAndSettle();

      // Now the interactive map with its own FAB stack (no tap-to-expand).
      expect(find.byType(StationPositionPanel), findsOneWidget);
      expect(find.byIcon(Icons.center_focus_strong_rounded), findsOneWidget);
      expect(find.byIcon(Icons.open_in_full), findsOneWidget);
    },
  );
}
