import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:ringdrill/views/roleplays_view.dart';
import 'package:ringdrill/views/station_list_view.dart';
import 'package:ringdrill/views/teams_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _programUuid = 'program-order-test';

final _station = Station(index: 0, name: 'Post 1');

Exercise _ex(String uuid, String name, int index, {int startHour = 9}) =>
    Exercise(
      uuid: uuid,
      index: index,
      name: name,
      startTime: SimpleTimeOfDay(hour: startHour, minute: 0),
      numberOfTeams: 1,
      numberOfRounds: 1,
      executionTime: 15,
      evaluationTime: 5,
      rotationTime: 2,
      stations: [_station],
      schedule: [
        [
          SimpleTimeOfDay(hour: startHour, minute: 0),
          SimpleTimeOfDay(hour: startHour, minute: 15),
          SimpleTimeOfDay(hour: startHour, minute: 20),
        ],
      ],
      endTime: SimpleTimeOfDay(hour: startHour, minute: 22),
    );

// Three exercises: "Gamma" first (index 0), "Alpha" second (index 1),
// "Beta" third (index 2). Start times are Alpha=08h < Beta=09h < Gamma=10h
// so sort-by-time produces a DIFFERENT order than the initial index order.
final _exGamma = _ex('ex-gamma', 'Gamma', 0, startHour: 10);
final _exAlpha = _ex('ex-alpha', 'Alpha', 1, startHour: 8);
final _exBeta = _ex('ex-beta', 'Beta', 2, startHour: 9);

// The canonical uuid order for the initial arrangement (Gamma, Alpha, Beta).
const _canonicalOrder = ['ex-gamma', 'ex-alpha', 'ex-beta'];

Map<String, Object> _prefs() => {
  'app:activeProgram:v1': _programUuid,
  'app:librarySchema:v1': '1',
  'p:$_programUuid': jsonEncode({
    'uuid': _programUuid,
    'name': 'Order Test Plan',
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
  'pe:$_programUuid:ex-gamma': jsonEncode(_exGamma.toJson()),
  'pe:$_programUuid:ex-alpha': jsonEncode(_exAlpha.toJson()),
  'pe:$_programUuid:ex-beta': jsonEncode(_exBeta.toJson()),
};

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

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

Widget _harness(_HarnessControllers controllers) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ValueListenableBuilder<ProgramSegment>(
      valueListenable: controllers.program.activeSegment,
      builder: (context, _, child) => Scaffold(
        appBar: AppBar(
          actions: [
            ...?controllers.program.buildActions(
              context,
              const BoxConstraints(),
            ),
          ],
        ),
        body: child,
      ),
      child: ProgramView(
        controller: controllers.program,
        stationListController: controllers.stationList,
        rolePlaysController: controllers.rolePlays,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // setUpAll: load mock SharedPreferences with the 3-exercise plan ONCE and
  // initialise ProgramService. Each mutating test restores canonical order
  // in its own setUp to avoid state leaking between tests.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(_prefs());
    await ProgramService().init();
  });

  /// Restore the initial exercise order (Gamma, Alpha, Beta) before each
  /// test that mutates state, so tests do not depend on each other's results.
  setUp(() async {
    await ProgramService().reorderExercises(_canonicalOrder);
  });

  /// Helper: collect exercise-name Text widgets in render order.
  List<String> renderedOrder(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .where(
        (t) =>
            t.data != null &&
            ['Gamma', 'Alpha', 'Beta'].contains(t.data) &&
            t.style?.fontWeight == FontWeight.bold,
      )
      .map((t) => t.data!)
      .toList();

  testWidgets(
    'exercises load in index order: Gamma(0), Alpha(1), Beta(2)',
    (tester) async {
      final controllers = _HarnessControllers();
      addTearDown(controllers.dispose);
      await tester.pumpWidget(_harness(controllers));
      await tester.pumpAndSettle();

      expect(renderedOrder(tester), ['Gamma', 'Alpha', 'Beta']);
    },
  );

  testWidgets(
    'move-down action on first row persists new order and renumbers badges',
    (tester) async {
      final controllers = _HarnessControllers();
      addTearDown(controllers.dispose);
      await tester.pumpWidget(_harness(controllers));
      await tester.pumpAndSettle();

      // Initial order: Gamma, Alpha, Beta.
      expect(renderedOrder(tester), ['Gamma', 'Alpha', 'Beta']);

      // Tap the overflow menu on the first row (Gamma = index 0 in the list).
      // PopupMenuButton is generic so find.byType(PopupMenuButton) uses exact
      // runtimeType matching and misses PopupMenuButton<_ExerciseAction>.
      // Find the more_vert icon instead — the first one is the per-row overflow
      // on Gamma's card (AppBar sort menu is last).
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.exerciseMoveDown));
      await tester.pumpAndSettle();

      // After move-down: Alpha should be first, then Gamma, then Beta.
      expect(renderedOrder(tester), ['Alpha', 'Gamma', 'Beta']);

      // Persisted indices reflect new order.
      final exercises = ProgramService().loadExercises();
      final byName = {for (final e in exercises) e.name: e.index};
      expect(byName['Alpha'], 0);
      expect(byName['Gamma'], 1);
      expect(byName['Beta'], 2);
    },
  );

  testWidgets(
    'sort by start time reorders chronologically and renumbers',
    (tester) async {
      final controllers = _HarnessControllers();
      addTearDown(controllers.dispose);
      await tester.pumpWidget(_harness(controllers));
      await tester.pumpAndSettle();

      // Initial order is Gamma(10h), Alpha(8h), Beta(9h).
      expect(renderedOrder(tester), ['Gamma', 'Alpha', 'Beta']);

      // The AppBar sort button shows Icons.more_vert; the last icon in the tree
      // is the AppBar's (after the 3 per-row overflows).
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.exerciseSortByStartTime));
      await tester.pumpAndSettle();

      // Start times: Alpha 08h < Beta 09h < Gamma 10h.
      expect(renderedOrder(tester), ['Alpha', 'Beta', 'Gamma']);

      final exercises = ProgramService().loadExercises();
      final byName = {for (final e in exercises) e.name: e.index};
      expect(byName['Alpha'], 0);
      expect(byName['Beta'], 1);
      expect(byName['Gamma'], 2);
    },
  );

  testWidgets(
    'onReorderItem callback maps from/to index pair to the correct persisted order',
    (tester) async {
      final controllers = _HarnessControllers();
      addTearDown(controllers.dispose);
      await tester.pumpWidget(_harness(controllers));
      await tester.pumpAndSettle();

      // Initial order: Gamma(0), Alpha(1), Beta(2).
      expect(renderedOrder(tester), ['Gamma', 'Alpha', 'Beta']);

      // Locate the ReorderableListView (exercises segment body).
      final listView = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView).first,
      );

      // Simulate dragging item at index 0 (Gamma) to position 2 (after Beta).
      // onReorderItem already delivers the adjusted destination index.
      listView.onReorderItem!(0, 2);
      await tester.pumpAndSettle();

      // Expected order: Alpha(0), Beta(1), Gamma(2).
      expect(renderedOrder(tester), ['Alpha', 'Beta', 'Gamma']);

      final exercises = ProgramService().loadExercises();
      final byName = {for (final e in exercises) e.name: e.index};
      expect(byName['Alpha'], 0);
      expect(byName['Beta'], 1);
      expect(byName['Gamma'], 2);
    },
  );
}
