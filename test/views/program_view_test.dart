import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/main_screen.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:ringdrill/views/roleplays_view.dart';
import 'package:ringdrill/views/station_list_view.dart';
import 'package:ringdrill/views/teams_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _programUuid = 'program-segments';
const _exerciseUuid = 'exercise-segments';

final _exercise = Exercise(
  uuid: _exerciseUuid,
  name: 'Segment Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [Station(index: 0, name: 'Segment Station')],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 0),
      SimpleTimeOfDay(hour: 8, minute: 10),
      SimpleTimeOfDay(hour: 8, minute: 15),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
);

final _rolePlay = RolePlay(
  uuid: 'role-segments',
  index: 0,
  exerciseUuid: _exerciseUuid,
  name: 'Segment Role',
  stationIndex: 0,
);

final _team = Team(uuid: 'team-segments', index: 0, name: 'Segment Team');

Map<String, Object> _prefs() {
  return {
    'app:activeProgram:v1': _programUuid,
    'app:librarySchema:v1': '1',
    'p:$_programUuid': jsonEncode({
      'uuid': _programUuid,
      'name': 'Segment Program',
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
    'pe:$_programUuid:$_exerciseUuid': jsonEncode(_exercise.toJson()),
    'pt:$_programUuid:${_team.uuid}': jsonEncode(_team.toJson()),
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

Widget _programHarness(_HarnessControllers controllers, {bool chrome = false}) {
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

void _select(_HarnessControllers controllers, ProgramSegment segment) {
  controllers.program.activeSegment.value = segment;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(_prefs());
    await ProgramService().init();
  });

  testWidgets('renders and switches all four program segments', (tester) async {
    final controllers = _HarnessControllers();
    addTearDown(controllers.dispose);
    await tester.pumpWidget(_programHarness(controllers));
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedButton<ProgramSegment>), findsOneWidget);
    expect(find.text('Segment Exercise').hitTestable(), findsOneWidget);

    _select(controllers, ProgramSegment.stations);
    await tester.pump();
    expect(find.text('Segment Station').hitTestable(), findsOneWidget);

    _select(controllers, ProgramSegment.script);
    await tester.pump();
    expect(find.text('Segment Role').hitTestable(), findsOneWidget);

    _select(controllers, ProgramSegment.teams);
    await tester.pump();
    expect(find.text('Segment Team').hitTestable(), findsOneWidget);
  });

  // The IndexedStack body (manual-collapse rework, replacing the
  // NestedScrollView + active-only fallback) keeps every segment mounted, so a
  // segment's State — e.g. an expanded station tile — is retained across
  // switches.
  testWidgets('segment body expansion is retained when switching away', (
    tester,
  ) async {
    final controllers = _HarnessControllers();
    addTearDown(controllers.dispose);
    await tester.pumpWidget(_programHarness(controllers));
    await tester.pumpAndSettle();

    _select(controllers, ProgramSegment.stations);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.expand_more).hitTestable());
    await tester.pumpAndSettle();
    // Expanded station tile shows the role name.
    expect(find.text('Segment Role').hitTestable(), findsOneWidget);

    // Switching away and back keeps the expansion.
    _select(controllers, ProgramSegment.script);
    await tester.pump();
    _select(controllers, ProgramSegment.stations);
    await tester.pumpAndSettle();
    expect(find.text('Segment Role').hitTestable(), findsOneWidget);
  });

  testWidgets('changes contextual FAB and AppBar actions by segment', (
    tester,
  ) async {
    final controllers = _HarnessControllers();
    addTearDown(controllers.dispose);
    await tester.pumpWidget(_programHarness(controllers, chrome: true));
    await tester.pumpAndSettle();

    // Brief is an AppBar action on every lens (it renders the whole plan).
    Finder appBarBrief() => find
        .descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.menu_book),
        )
        .hitTestable();

    expect(appBarBrief(), findsOneWidget);
    expect(find.byType(FloatingActionButton).hitTestable(), findsOneWidget);

    // Poster filters via an AppBar action (Icons.filter_list), like Markører,
    // not a body FAB. Brief stays present.
    _select(controllers, ProgramSegment.stations);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.filter_list).hitTestable(), findsOneWidget);
    expect(appBarBrief(), findsOneWidget);

    _select(controllers, ProgramSegment.script);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.filter_list).hitTestable(), findsOneWidget);
    expect(find.byIcon(Icons.recent_actors).hitTestable(), findsOneWidget);
    expect(appBarBrief(), findsOneWidget);

    _select(controllers, ProgramSegment.teams);
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton).hitTestable(), findsNothing);
    expect(find.byIcon(Icons.recent_actors).hitTestable(), findsNothing);
    expect(appBarBrief(), findsOneWidget);
  });

  testWidgets('wide detail empty pane follows the active program segment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: [
        for (final route in [routeProgram, routeMap])
          GoRoute(path: route, builder: (_, _) => const SizedBox.shrink()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MainScreen(
          router: router,
          routes: const [routeProgram, routeMap],
          location: routeProgram,
          navigatorKey: GlobalKey<NavigatorState>(),
          isFirstLaunch: false,
          shellChild: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.detailEmptyExercise), findsOneWidget);
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
    expect(find.text(l10n.detailEmptyStation), findsOneWidget);

    await tester.tap(
      find
          .descendant(
            of: find.byType(SegmentedButton<ProgramSegment>),
            matching: find.text(l10n.rolePlaysTab),
          )
          .hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.detailEmptyRolePlay), findsOneWidget);

    await tester.tap(
      find
          .descendant(
            of: find.byType(SegmentedButton<ProgramSegment>),
            matching: find.text(l10n.team(2)),
          )
          .hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.detailEmptyTeam), findsOneWidget);
  });
}
