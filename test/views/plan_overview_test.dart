import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/plan_view.dart';
import 'package:ringdrill/views/roleplay_list_view.dart';
import 'package:ringdrill/views/station_list_view.dart';
import 'package:ringdrill/views/teams_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Fixture identifiers — must not collide with plan_view_test.dart (separate
// isolate, but keeps the intent clear).
const _planUuid = 'plan-overview';
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
    'app:activePlan:v1': _planUuid,
    'app:librarySchema:v1': '1',
    'p:$_planUuid': jsonEncode({
      'uuid': _planUuid,
      'name': 'Overview Plan',
      'description': 'Plan description text',
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
      'pe:$_planUuid:${ex.uuid}': jsonEncode(ex.toJson()),
    'pt:$_planUuid:${_team0.uuid}': jsonEncode(_team0.toJson()),
    'pt:$_planUuid:${_team1.uuid}': jsonEncode(_team1.toJson()),
    'pr:$_planUuid:${_rolePlay.uuid}': jsonEncode(_rolePlay.toJson()),
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

Widget _harness(
  _HarnessControllers controllers, {
  bool chrome = false,
  ThemeData? theme,
}) {
  return _PlanOverviewHarness(
    controllers: controllers,
    chrome: chrome,
    theme: theme,
  );
}

/// Stateful wrapper that owns the in-test [GoRouter] so its `dispose()` is
/// invoked when the Flutter test tears down the widget tree. The router
/// exists because [_PlanSegmentSwitcher] in `plan_view.dart` pushes
/// canonical `/plan/:uuid/:segment` paths through `context.go(...)` per
/// ADR-0032 *Activation contract* — the URL is the source of truth, and the
/// controller's `activeSegment` is updated by the redirect gate, not by the
/// switcher itself. The redirect here mirrors `MainScreen._initTab` in
/// production: when the URL ends in a recognised segment slug, write that
/// slug into the controller so the segmented button reflects the tap.
class _PlanOverviewHarness extends StatefulWidget {
  const _PlanOverviewHarness({
    required this.controllers,
    required this.chrome,
    this.theme,
  });

  final _HarnessControllers controllers;
  final bool chrome;
  final ThemeData? theme;

  @override
  State<_PlanOverviewHarness> createState() => _PlanOverviewHarnessState();
}

class _PlanOverviewHarnessState extends State<_PlanOverviewHarness> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: planSegmentPath(_planUuid, planSegmentDefaultSlug),
      redirect: (context, state) {
        final segments = state.uri.pathSegments;
        if (segments.length >= 3 && segments[0] == 'plan') {
          final segment = planSegmentFromSlug(segments[2]);
          if (segment != null) {
            widget.controllers.plan.activeSegment.value = segment;
          }
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/plan/:uuid/:segment',
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
    return ValueListenableBuilder<PlanSegment>(
      valueListenable: widget.controllers.plan.activeSegment,
      builder: (context, _, child) {
        return Scaffold(
          appBar: widget.chrome
              ? AppBar(
                  actions: [
                    ...?widget.controllers.plan.buildActions(
                      context,
                      const BoxConstraints(),
                    ),
                  ],
                )
              : null,
          body: child!,
          floatingActionButton: widget.chrome
              ? widget.controllers.plan.buildFAB(
                  context,
                  const BoxConstraints(),
                )
              : null,
        );
      },
      child: PlanView(
        controller: widget.controllers.plan,
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

/// Sets [description]/[commsMd] on the active plan for one test, and restores the
/// shared fixture afterwards.
///
/// Through `replacePlan`, not a prefs re-seed: the markdown fields are
/// `includeFromJson: false` because they live in `.md` companion files in the
/// archive (ADR-0022), so writing them into the plan JSON does nothing at all. The
/// restore keeps these tests from depending on the order they run in.
Future<void> _withPlanContent({
  required String description,
  String? commsMd,
}) async {
  final base = PlanService().activePlan!;
  addTearDown(() => PlanService().replacePlan(base));
  await PlanService().replacePlan(
    base.copyWith(description: description, commsMd: commsMd),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(_prefs());
    await PlanService().init();
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

    expect(find.text('Plan description text'), findsOneWidget);
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
      expect(find.text('Plan description text').hitTestable(), findsOneWidget);
      expect(
        find.byType(SegmentedButton<PlanSegment>).hitTestable(),
        findsOneWidget,
      );

      // The overview and switcher are real slivers ahead of the active
      // segment's rows in one CustomScrollView (see plan_view.dart's
      // `buildSegmentScrollView`): the switcher is a pinned
      // SliverPersistentHeader, so it stays put while the overview — an
      // ordinary sliver above it — scrolls away once the rows need the room.
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();

      expect(find.text('Plan description text').hitTestable(), findsNothing);
      // Pinned switcher remains visible and usable.
      expect(
        find.byType(SegmentedButton<PlanSegment>).hitTestable(),
        findsOneWidget,
      );
      // Can still switch segments via the pinned bar.
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

      expect(find.text('Plan description text').hitTestable(), findsOneWidget);

      // Scroll down: the overview scrolls out of view.
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(find.text('Plan description text').hitTestable(), findsNothing);

      // Scroll back to the top WITHOUT switching segments.
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, 600),
      );
      await tester.pumpAndSettle();

      // Still on the exercises segment, and the overview is back.
      expect(
        tester
            .widget<SegmentedButton<PlanSegment>>(
              find.byType(SegmentedButton<PlanSegment>),
            )
            .selected,
        {PlanSegment.exercises},
      );
      expect(find.text('Plan description text').hitTestable(), findsOneWidget);
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
        find.byType(SegmentedButton<PlanSegment>),
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

  group('markdown in the overview card', () {
    const table =
        '| Rolle | Talegruppe |\n'
        '|---|---|\n'
        '| LSOR Deltakere | RK-VFOLD-ØV4 |\n'
        '| LSOR Stab | RK-VFOLD-ØV5 |\n';

    testWidgets('a table in commsMd renders as a table once expanded', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _withPlanContent(
        description: 'Plan description text',
        commsMd: '$table\nTelefon til KO: 93258930.',
      );

      final controllers = _HarnessControllers();
      addTearDown(controllers.dispose);
      await tester.pumpWidget(_harness(controllers));
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Collapsed: no pipe soup. This is the bug — the table used to arrive
      // flattened onto one line. Matched on the table's own markup rather than a
      // bare "|", because an exercise row legitimately reads "08:00 - 08:17 | 17
      // min | 1 round".
      expect(find.textContaining('| Rolle |'), findsNothing);
      expect(find.textContaining('---|'), findsNothing);
      expect(find.byType(Table), findsNothing);

      await tester.tap(find.text(l10n.showMore));
      await tester.pumpAndSettle();

      expect(find.byType(Table), findsOneWidget);
      expect(find.text('Rolle', findRichText: true), findsOneWidget);
      expect(find.text('RK-VFOLD-ØV4', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a table-only commsMd still renders the card and a toggle', (
      tester,
    ) async {
      // The `hasContent` trap: a table-only field teases to null, and deriving
      // emptiness from the teaser would replace the whole card with the
      // empty-state edit row — hiding the very table it should show.
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _withPlanContent(description: '', commsMd: table);

      final controllers = _HarnessControllers();
      addTearDown(controllers.dispose);
      await tester.pumpWidget(_harness(controllers));
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // The card, not the empty-state row: the section label is shown.
      expect(find.text(l10n.briefSectionPlanComms), findsOneWidget);
      expect(find.text(l10n.showMore), findsOneWidget);
      expect(find.textContaining('| Rolle |'), findsNothing);
      expect(find.textContaining('---|'), findsNothing);

      await tester.tap(find.text(l10n.showMore));
      await tester.pumpAndSettle();

      expect(find.byType(Table), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
