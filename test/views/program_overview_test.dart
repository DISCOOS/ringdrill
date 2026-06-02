import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:ringdrill/views/roleplays_view.dart';
import 'package:ringdrill/views/station_list_view.dart';
import 'package:ringdrill/views/teams_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Fixture identifiers — must not collide with program_view_test.dart (separate
// isolate, but keeps the intent clear).
const _programUuid = 'program-overview';
const _exerciseUuid0 = 'ex-overview-0';

Exercise _makeExercise(int i) => Exercise(
  uuid: 'ex-overview-$i',
  name: 'Overview Exercise $i',
  startTime: SimpleTimeOfDay(hour: 8, minute: i % 60),
  numberOfTeams: 2,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: [Station(index: 0, name: 'Overview Station $i')],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 0),
      SimpleTimeOfDay(hour: 8, minute: 10),
      SimpleTimeOfDay(hour: 8, minute: 15),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
);

// 20 exercises so the list is tall enough to drive the NestedScrollView header
// collapse in the scroll test.
final _exercises = List.generate(20, _makeExercise);
final _team0 = Team(uuid: 'team-ov-0', index: 0, name: 'Overview Team A');
final _team1 = Team(uuid: 'team-ov-1', index: 1, name: 'Overview Team B');
final _rolePlay = RolePlay(
  uuid: 'role-overview',
  index: 0,
  exerciseUuid: _exerciseUuid0,
  name: 'Overview Role',
  stationIndex: 0,
);

Map<String, Object> _prefs() {
  return {
    'app:activeProgram:v1': _programUuid,
    'app:librarySchema:v1': '1',
    'p:$_programUuid': jsonEncode({
      'uuid': _programUuid,
      'name': 'Overview Program',
      'description': 'Program description text',
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
    for (final ex in _exercises)
      'pe:$_programUuid:${ex.uuid}': jsonEncode(ex.toJson()),
    'pt:$_programUuid:${_team0.uuid}': jsonEncode(_team0.toJson()),
    'pt:$_programUuid:${_team1.uuid}': jsonEncode(_team1.toJson()),
    'pr:$_programUuid:${_rolePlay.uuid}': jsonEncode(_rolePlay.toJson()),
  };
}

class _TestProgramController extends ProgramPageControllerBase {
  _TestProgramController({
    required super.stationListController,
    required super.rolePlaysController,
    required super.teamsPageController,
  });
}

class _HarnessControllers {
  _HarnessControllers()
    : stationList = StationListController(),
      rolePlays = RolePlaysController(),
      teams = const TeamsPageController() {
    program = _TestProgramController(
      stationListController: stationList,
      rolePlaysController: rolePlays,
      teamsPageController: teams,
    );
  }

  final StationListController stationList;
  final RolePlaysController rolePlays;
  final TeamsPageController teams;
  late final _TestProgramController program;

  void dispose() {
    program.dispose();
    stationList.dispose();
    rolePlays.dispose();
  }
}

Widget _harness(_HarnessControllers controllers, {bool chrome = false}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ValueListenableBuilder<ProgramSegment>(
      valueListenable: controllers.program.activeSegment,
      builder: (context, _, child) {
        return Scaffold(
          appBar: chrome
              ? AppBar(
                  actions: [
                    ...?controllers.program.buildActions(
                      context,
                      const BoxConstraints(),
                    ),
                  ],
                )
              : null,
          body: child,
          floatingActionButton: chrome
              ? controllers.program.buildFAB(context, const BoxConstraints())
              : null,
        );
      },
      child: ProgramView(
        controller: controllers.program,
        stationListController: controllers.stationList,
        rolePlaysController: controllers.rolePlays,
      ),
    ),
  );
}


void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(_prefs());
    await ProgramService().init();
  });

  testWidgets('overview renders summary line with team and exercise counts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controllers = _HarnessControllers();
    addTearDown(controllers.dispose);
    await tester.pumpWidget(_harness(controllers));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // Default segment is exercises: "Lag · Exercises" in Norwegian, "Teams · Exercises" in English.
    expect(find.textContaining(l10n.team(2)), findsWidgets);
    expect(find.textContaining(l10n.exercise(_exercises.length)), findsWidgets);
  });


  testWidgets('overview renders description when present', (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controllers = _HarnessControllers();
    addTearDown(controllers.dispose);
    await tester.pumpWidget(_harness(controllers));
    await tester.pumpAndSettle();

    expect(find.text('Program description text'), findsOneWidget);
  });


  testWidgets(
    'scrolling the segment list collapses the overview; switcher stays pinned',
    (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controllers = _HarnessControllers();
      addTearDown(controllers.dispose);
      await tester.pumpWidget(_harness(controllers));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // Overview description and switcher are both visible initially.
      expect(find.text('Program description text').hitTestable(), findsOneWidget);
      expect(
        find.byType(SegmentedButton<ProgramSegment>).hitTestable(),
        findsOneWidget,
      );

      // Drag the active segment ListView upward. The NotificationListener
      // catches the positive scroll delta and collapses the overview via
      // AnimatedSize (manual collapse, not a NestedScrollView sliver).
      await tester.drag(
        find.byType(ListView).first,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      // Overview scrolled off — description no longer hit-testable.
      expect(find.text('Program description text').hitTestable(), findsNothing);
      // Pinned switcher remains visible and usable.
      expect(
        find.byType(SegmentedButton<ProgramSegment>).hitTestable(),
        findsOneWidget,
      );
      // Can still switch segments via the pinned bar.
      await tester.tap(
        find
            .descendant(
              of: find.byType(SegmentedButton<ProgramSegment>),
              matching: find.text(l10n.stationsTab),
            )
            .hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SegmentedButton<ProgramSegment>>(
              find.byType(SegmentedButton<ProgramSegment>),
            )
            .selected,
        {ProgramSegment.stations},
      );
    },
  );

}
