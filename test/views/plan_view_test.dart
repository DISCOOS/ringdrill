import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/coordinator_screen.dart';
import 'package:ringdrill/views/plan_view.dart';
import 'package:ringdrill/views/roleplay_list_view.dart';
import 'package:ringdrill/views/roleplay_screen.dart';
import 'package:ringdrill/views/shell/app_router.dart';
import 'package:ringdrill/views/station_list_view.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:ringdrill/views/team_screen.dart';
import 'package:ringdrill/views/teams_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _planUuid = 'plan-segments';
const _emptyPlanUuid = 'plan-segments-empty';
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
    'app:activePlan:v1': _planUuid,
    'app:librarySchema:v1': '1',
    'p:$_planUuid': jsonEncode({
      'uuid': _planUuid,
      'name': 'Segment Plan',
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
    'pe:$_planUuid:$_exerciseUuid': jsonEncode(_exercise.toJson()),
    'pt:$_planUuid:${_team.uuid}': jsonEncode(_team.toJson()),
    'pr:$_planUuid:${_rolePlay.uuid}': jsonEncode(_rolePlay.toJson()),
    // A second, genuinely empty plan — nothing for the wide layout to
    // auto-select, so its exercises segment keeps showing the empty
    // placeholder (with the sidebar-toggle leading).
    'p:$_emptyPlanUuid': jsonEncode({
      'uuid': _emptyPlanUuid,
      'name': 'Empty Segment Plan',
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
  };
}

class _TestPlanController extends PlanPageControllerBase {
  _TestPlanController({
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
    plan = _TestPlanController(
      stationListController: stationList,
      rolePlaysController: rolePlays,
      teamsPageController: teams,
    );
  }

  final StationListController stationList;
  final RolePlaysController rolePlays;
  final TeamsPageController teams;
  late final _TestPlanController plan;

  void dispose() {
    plan.dispose();
    stationList.dispose();
    rolePlays.dispose();
  }
}

Widget _planHarness(_HarnessControllers controllers, {bool chrome = false}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ValueListenableBuilder<PlanSegment>(
      valueListenable: controllers.plan.activeSegment,
      builder: (context, _, child) {
        return Scaffold(
          appBar: chrome
              ? AppBar(
                  actions: [
                    ...?controllers.plan.buildActions(
                      context,
                      const BoxConstraints(),
                    ),
                  ],
                )
              : null,
          body: child,
          floatingActionButton: chrome
              ? controllers.plan.buildFAB(context, const BoxConstraints())
              : null,
        );
      },
      child: PlanView(
        controller: controllers.plan,
        stationListController: controllers.stationList,
        rolePlaysController: controllers.rolePlays,
      ),
    ),
  );
}

void _select(_HarnessControllers controllers, PlanSegment segment) {
  controllers.plan.activeSegment.value = segment;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(_prefs());
    await PlanService().init();
  });

  testWidgets('renders and switches all four plan segments', (tester) async {
    final controllers = _HarnessControllers();
    addTearDown(controllers.dispose);
    await tester.pumpWidget(_planHarness(controllers));
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedButton<PlanSegment>), findsOneWidget);
    expect(find.text('Segment Exercise').hitTestable(), findsOneWidget);

    _select(controllers, PlanSegment.stations);
    await tester.pump();
    expect(find.text('Segment Station').hitTestable(), findsOneWidget);

    _select(controllers, PlanSegment.script);
    await tester.pump();
    expect(find.text('Segment Role').hitTestable(), findsOneWidget);

    _select(controllers, PlanSegment.teams);
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
    await tester.pumpWidget(_planHarness(controllers));
    await tester.pumpAndSettle();

    _select(controllers, PlanSegment.stations);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.expand_more).hitTestable());
    await tester.pumpAndSettle();
    // Expanded station tile shows the role name. Scrolled to first: an unplaced
    // station's body now carries the teaching empty state where its mini-map would
    // go, which is taller than the one-line "Ikke satt" row it replaced, so the role
    // row below it starts off-screen on this harness's height.
    await tester.scrollUntilVisible(find.text('Segment Role'), 120);
    await tester.pumpAndSettle();
    expect(find.text('Segment Role').hitTestable(), findsOneWidget);

    // Switching away and back keeps the expansion.
    _select(controllers, PlanSegment.script);
    await tester.pump();
    _select(controllers, PlanSegment.stations);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Segment Role'), 120);
    await tester.pumpAndSettle();
    expect(find.text('Segment Role').hitTestable(), findsOneWidget);
  });

  testWidgets('changes contextual FAB and AppBar actions by segment', (
    tester,
  ) async {
    final controllers = _HarnessControllers();
    addTearDown(controllers.dispose);
    await tester.pumpWidget(_planHarness(controllers, chrome: true));
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
    _select(controllers, PlanSegment.stations);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.filter_list).hitTestable(), findsOneWidget);
    expect(appBarBrief(), findsOneWidget);

    _select(controllers, PlanSegment.script);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.filter_list).hitTestable(), findsOneWidget);
    // The cast-roster shortcut (Icons.recent_actors) was retired once the
    // Roster tab became the actor registry's home; only the filter stays.
    expect(find.byIcon(Icons.recent_actors), findsNothing);
    expect(appBarBrief(), findsOneWidget);

    _select(controllers, PlanSegment.teams);
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton).hitTestable(), findsNothing);
    expect(appBarBrief(), findsOneWidget);
  });

  testWidgets('wide layout auto-selects each plan segment\'s first item '
      '(collapsible-master-pane)', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // After ADR-0032 the segment switcher pushes canonical
    // /plan/:uuid/:segment paths through `context.go(...)`. The
    // hand-rolled GoRouter we used before had no segment routes and never
    // re-rendered MainScreen with a new `location`, so taps short-circuited
    // with `No GoRouter found in context`. Pump the production router and
    // wrap it in `MaterialApp.router` so URL → state actually flows.
    await PlanService().setActive(_planUuid);
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
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Every segment in this fixture has exactly one item, so the wide
    // detail pane auto-selects it instead of showing the empty
    // placeholder (DESIGN-010 collapsible master pane).
    expect(find.text(l10n.detailEmptyExercise), findsNothing);
    expect(find.byType(CoordinatorScreen), findsOneWidget);

    await tester.tap(
      find
          .descendant(
            of: find.byType(SegmentedButton<PlanSegment>),
            matching: find.text(l10n.stationsTab),
          )
          .hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<PlanSegment>>(
            find.byType(SegmentedButton<PlanSegment>),
          )
          .selected,
      {PlanSegment.stations},
    );
    expect(find.text(l10n.detailEmptyStation), findsNothing);
    expect(find.byType(StationScreen), findsOneWidget);

    await tester.tap(
      find
          .descendant(
            of: find.byType(SegmentedButton<PlanSegment>),
            matching: find.text(l10n.scriptSegment),
          )
          .hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.detailEmptyRolePlay), findsNothing);
    expect(find.byType(RolePlayScreen), findsOneWidget);

    await tester.tap(
      find
          .descendant(
            of: find.byType(SegmentedButton<PlanSegment>),
            matching: find.text(l10n.team(2)),
          )
          .hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.detailEmptyTeam), findsNothing);
    expect(find.byType(TeamScreen), findsOneWidget);
  });

  testWidgets('an empty plan renders every segment through the router', (
    tester,
  ) async {
    // Reported from the app, and only reproducible through the *router*:
    // navigating to /plan/<uuid>/script on a plan with no exercises rendered
    // an empty master pane — no overview card, no segmented button, no empty
    // state. /exercises and /teams on the same plan were fine.
    //
    // Driving `activeSegment` directly does not reproduce it, which is why
    // this goes through buildRouter and a real URL.
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await PlanService().setActive(_emptyPlanUuid);
    addTearDown(() => PlanService().setActive(_planUuid));

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

    for (final slug in ['exercises', 'stations', 'script', 'teams']) {
      router.go('/plan/$_emptyPlanUuid/$slug');
      await tester.pumpAndSettle();
      // hitTestable: IndexedStack keeps every segment mounted, so a plain
      // finder matches the switcher inside the three that are not showing.
      expect(
        find.byType(SegmentedButton<PlanSegment>).hitTestable(),
        findsOneWidget,
        reason: 'the master pane was empty at /$slug',
      );
    }
  });

  testWidgets(
    'wide detail empty pane still shows when a segment has no items',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await PlanService().setActive(_emptyPlanUuid);
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
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Nothing to auto-select — the placeholder stays, and it carries the
      // same sidebar-toggle leading as every other detail screen.
      expect(find.text(l10n.detailEmptyExercise), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.sidebar_left), findsOneWidget);
    },
  );
}
