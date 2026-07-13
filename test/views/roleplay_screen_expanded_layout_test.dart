import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/data/program_repository.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/roleplay_screen.dart';
import 'package:ringdrill/views/shell/wide_detail_map_split.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// DESIGN-010 post-spill-expanded-map-split: at a pane width >= 840 the Spill
// viewer mirrors the Post viewer's follow-up — the role position panel
// moves to a fixed full-height right pane beside a capped, independently-
// scrolling left column (status/context/identity/Markørordre/Når aktiv), via
// the shared `WideDetailMapSplit`. Compact and medium keep today's single
// scrolling column. The roleplay carries a real position and a source
// location here so the panel's two-line coordinate bar (label + source)
// actually renders and the expanded map pane's height math is exercised
// against real content, not an empty placeholder.
// ---------------------------------------------------------------------------

const _programUuid = 'prog-role-expanded-layout';
const _exerciseUuid = 'ex-role-expanded-layout';
const _roleUuid = 'role-expanded-layout';

const _homeLocation = Location(
  slug: 'home',
  label: 'Bosted',
  kind: LocationKind.home,
  position: LatLng(59.92, 10.76),
);

const _hilde = Person(
  slug: 'hilde',
  name: 'Hilde',
  age: 34,
  gender: 'woman',
  locSlug: 'home',
);

Program _shell() {
  final now = DateTime.utc(2026, 1, 1);
  return Program(
    uuid: _programUuid,
    name: 'Test Program',
    description: '',
    metadata: ProgramMetadata(created: now, updated: now, version: '1.0'),
    teams: const [],
    sessions: const [],
    exercises: const [],
  );
}

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  index: 0,
  name: 'Test Exercise',
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
      persons: [_hilde],
      locations: [_homeLocation],
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

RolePlay _rolePlay() => const RolePlay(
  uuid: _roleUuid,
  index: 0,
  exerciseUuid: _exerciseUuid,
  stationIndex: 0,
  name: 'Hilde',
  personRef: 'hilde',
  position: LatLng(59.92, 10.76),
  behavior: 'Rolig.',
  background: 'Sett ved posten.',
  propsMd: 'Fiskestang.',
);

Future<void> _seedAndInit() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = ProgramRepository(prefs);
  await repo.saveProgramShell(_shell());
  await repo.setActiveProgramUuid(_programUuid);
  await repo.saveExercise(_exercise());
  await repo.saveRolePlay(_rolePlay());
  await ProgramService().init();
}

Widget _harness(Widget widget) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: widget,
);

/// Pumps [RolePlayScreen] with the test binding reporting a wide (1200x800)
/// window, but the widget itself constrained to [paneWidth] via an ancestor
/// `SizedBox` — reproducing "wide window, narrow pane" the way the
/// coordinator's own pane-local-breakpoint test does, so this proves the
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
          child: const RolePlayScreen(rolePlayUuid: _roleUuid),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a narrow (700px) pane stacks — no WideDetailMapSplit, no overflow',
    (tester) async {
      await _seedAndInit();
      tester.view.physicalSize = const Size(700, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_harness(const RolePlayScreen(rolePlayUuid: _roleUuid)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(WideDetailMapSplit), findsNothing);
      expect(find.text('Bosted'), findsOneWidget);
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

      await tester.pumpWidget(_harness(const RolePlayScreen(rolePlayUuid: _roleUuid)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(WideDetailMapSplit), findsOneWidget);
      expect(find.text('Bosted'), findsOneWidget);
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
}
