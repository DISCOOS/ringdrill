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

// 20 exercises so the list is tall enough to make the overview sliver scroll
// out of view in the scroll test.
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

Widget _harness(
  _HarnessControllers controllers, {
  bool chrome = false,
  ThemeData? theme,
}) {
  return _ProgramOverviewHarness(
    controllers: controllers,
    chrome: chrome,
    theme: theme,
  );
}

/// Stateful wrapper that owns the in-test [GoRouter] so its `dispose()` is
/// invoked when the Flutter test tears down the widget tree. The router
/// exists because [_ProgramSegmentSwitcher] in `program_view.dart` pushes
/// canonical `/program/:uuid/:segment` paths through `context.go(...)` per
/// ADR-0032 *Activation contract* — the URL is the source of truth, and the
/// controller's `activeSegment` is updated by the redirect gate, not by the
/// switcher itself. The redirect here mirrors `MainScreen._initTab` in
/// production: when the URL ends in a recognised segment slug, write that
/// slug into the controller so the segmented button reflects the tap.
class _ProgramOverviewHarness extends StatefulWidget {
  const _ProgramOverviewHarness({
    required this.controllers,
    required this.chrome,
    this.theme,
  });

  final _HarnessControllers controllers;
  final bool chrome;
  final ThemeData? theme;

  @override
  State<_ProgramOverviewHarness> createState() =>
      _ProgramOverviewHarnessState();
}

class _ProgramOverviewHarnessState extends State<_ProgramOverviewHarness> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: programSegmentPath(
        _programUuid,
        programSegmentDefaultSlug,
      ),
      redirect: (context, state) {
        final segments = state.uri.pathSegments;
        if (segments.length >= 3 && segments[0] == 'program') {
          final segment = programSegmentFromSlug(segments[2]);
          if (segment != null) {
            widget.controllers.program.activeSegment.value = segment;
          }
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/program/:uuid/:segment',
          builder: (context, _) => _buildBody(context),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  Widget _buildBody(BuildContext context) {
    return ValueListenableBuilder<ProgramSegment>(
      valueListenable: widget.controllers.program.activeSegment,
      builder: (context, _, child) {
        return Scaffold(
          appBar: widget.chrome
              ? AppBar(
                  actions: [
                    ...?widget.controllers.program.buildActions(
                      context,
                      const BoxConstraints(),
                    ),
                  ],
                )
              : null,
          body: child!,
          floatingActionButton: widget.chrome
              ? widget.controllers.program.buildFAB(
                  context,
                  const BoxConstraints(),
                )
              : null,
        );
      },
      child: ProgramView(
        controller: widget.controllers.program,
        stationListController: widget.controllers.stationList,
        rolePlaysController: widget.controllers.rolePlays,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      theme: widget.theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
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
    'scrolling the segment list scrolls the overview away while the switcher '
    'stays pinned; scrolling back to the top brings the overview back',
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

      // The overview and switcher are real slivers ahead of the active
      // segment's rows in one CustomScrollView (see program_view.dart's
      // `buildSegmentScrollView`): the switcher is a pinned
      // SliverPersistentHeader, so it stays put while the overview — an
      // ordinary sliver above it — scrolls away once the rows need the room.
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();

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

  testWidgets(
    'scrolling the segment list back to the top reveals the overview again '
    'without a segment switch',
    (tester) async {
      // The overview is an ordinary sliver ahead of the pinned switcher now,
      // so this is just confirming normal scroll behaviour: returning to the
      // top of the CustomScrollView brings it back into view on the same
      // segment, with no separate "collapsed" flag to get stuck.
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controllers = _HarnessControllers();
      addTearDown(controllers.dispose);
      await tester.pumpWidget(_harness(controllers));
      await tester.pumpAndSettle();

      expect(
        find.text('Program description text').hitTestable(),
        findsOneWidget,
      );

      // Scroll down: the overview scrolls out of view.
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(find.text('Program description text').hitTestable(), findsNothing);

      // Scroll back to the top WITHOUT switching segments.
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, 600),
      );
      await tester.pumpAndSettle();

      // Still on the exercises segment, and the overview is back.
      expect(
        tester
            .widget<SegmentedButton<ProgramSegment>>(
              find.byType(SegmentedButton<ProgramSegment>),
            )
            .selected,
        {ProgramSegment.exercises},
      );
      expect(
        find.text('Program description text').hitTestable(),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'pinned switcher keeps the segmented button at its natural height under '
    'desktop/web defaults (compact density, shrink-wrapped tap targets)',
    (tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controllers = _HarnessControllers();
      addTearDown(controllers.dispose);
      // Web in a desktop browser gets Flutter's desktop defaults: compact
      // visual density and shrink-wrapped tap targets, which make the
      // SegmentedButton naturally shorter than the pinned header's fixed
      // 56px extent. The header must give the switcher loose constraints —
      // force-stretching the button to fill the extent distorts the segment
      // outlines (the "mangled switcher" web regression).
      await tester.pumpWidget(
        _harness(
          controllers,
          theme: ThemeData(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final box = tester.renderObject<RenderBox>(
        find.byType(SegmentedButton<ProgramSegment>),
      );
      expect(
        box.size.height,
        box.getMaxIntrinsicHeight(box.size.width),
        reason:
            'The pinned header must not stretch the segmented button beyond '
            'its natural (intrinsic) height.',
      );
    },
  );
}
