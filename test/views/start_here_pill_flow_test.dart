import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/prefs.dart';
import 'package:ringdrill/views/plan_view.dart';
import 'package:ringdrill/views/roleplay_list_view.dart';
import 'package:ringdrill/views/station_list_view.dart';
import 'package:ringdrill/views/teams_view.dart';
import 'package:ringdrill/views/widgets/start_here_pill.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _emptyPlanUuid = 'start-here-empty';
const _fullPlanUuid = 'start-here-full';
const _exerciseUuid = 'start-here-ex';

final _exercise = Exercise(
  uuid: _exerciseUuid,
  name: 'Start Here Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [Station(index: 0, name: 'Start Here Station')],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 0),
      SimpleTimeOfDay(hour: 8, minute: 10),
      SimpleTimeOfDay(hour: 8, minute: 15),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
);

Map<String, Object> _planJson(String uuid) => {
  'uuid': uuid,
  'name': 'Start Here Plan',
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
};

// Both plans seeded once so PlanRepository's prefs ref stays valid.
Map<String, Object> _basePrefs() => {
  'app:activePlan:v1': _emptyPlanUuid,
  'app:librarySchema:v1': '1',
  'p:$_emptyPlanUuid': jsonEncode(_planJson(_emptyPlanUuid)),
  'p:$_fullPlanUuid': jsonEncode(_planJson(_fullPlanUuid)),
  'pe:$_fullPlanUuid:$_exerciseUuid': jsonEncode(_exercise.toJson()),
};

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

Widget _planHarness(_HarnessControllers controllers) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ValueListenableBuilder<PlanSegment>(
      valueListenable: controllers.plan.activeSegment,
      builder: (context, _, child) {
        return Scaffold(
          body: child,
          floatingActionButton: controllers.plan.buildFAB(
            context,
            const BoxConstraints(),
          ),
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

Widget _pillHarness({VoidCallback? onActivate}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: StartHerePill(onActivate: onActivate ?? () {})),
);

Future<void> _clearStartHereFlag() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(AppConfig.keyStartHereSeen);
}

Future<void> _setStartHereFlag() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(AppConfig.keyStartHereSeen, true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(_basePrefs());
    await PlanService().init();
  });

  // Prefs reads are synchronous now, so a test that seeds a real value has to
  // bind the instance — an unbound read means "nothing stored", which would show
  // the pill and pass for the wrong reason.
  setUp(() async {
    Prefs.reset();
    Prefs.bind(await SharedPreferences.getInstance());
    addTearDown(Prefs.reset);
  });

  setUp(() async {
    // Reset flag and active plan before each test so they are independent.
    await _clearStartHereFlag();
    await PlanService().setActive(_emptyPlanUuid);
  });

  // ---------------------------------------------------------------------------
  // Show / hide in the FAB harness
  // ---------------------------------------------------------------------------

  testWidgets('pill shows on Øvelser FAB when flag unset and exercises empty', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final controllers = _HarnessControllers();
    addTearDown(controllers.dispose);

    await tester.pumpWidget(_planHarness(controllers));
    await tester.pumpAndSettle();

    expect(find.text(l10n.startHereCue), findsOneWidget);
  });

  testWidgets('pill hidden when keyStartHereSeen is set', (tester) async {
    await _setStartHereFlag();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final controllers = _HarnessControllers();
    addTearDown(controllers.dispose);

    await tester.pumpWidget(_planHarness(controllers));
    await tester.pumpAndSettle();

    expect(find.text(l10n.startHereCue), findsNothing);
  });

  testWidgets('pill hidden when Øvelser has exercises', (tester) async {
    await PlanService().setActive(_fullPlanUuid);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final controllers = _HarnessControllers();
    addTearDown(controllers.dispose);

    await tester.pumpWidget(_planHarness(controllers));
    await tester.pumpAndSettle();

    expect(find.text(l10n.startHereCue), findsNothing);
  });

  testWidgets('pill absent on non-Øvelser segment (Script)', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final controllers = _HarnessControllers();
    addTearDown(controllers.dispose);
    controllers.plan.activeSegment.value = PlanSegment.script;

    await tester.pumpWidget(_planHarness(controllers));
    await tester.pumpAndSettle();

    expect(find.text(l10n.startHereCue), findsNothing);
  });

  // ---------------------------------------------------------------------------
  // Tap dismissal (StartHerePill directly with no-op onActivate)
  // ---------------------------------------------------------------------------

  testWidgets('tapping pill writes flag and removes pill', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.pumpWidget(_pillHarness());
    await tester.pump(); // let _loadFlag async settle

    expect(find.text(l10n.startHereCue), findsOneWidget);

    await tester.tap(find.text(l10n.startHereCue));
    await tester.pump();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppConfig.keyStartHereSeen), isTrue);
    expect(find.text(l10n.startHereCue), findsNothing);
  });

  // ---------------------------------------------------------------------------
  // First exercise created dismisses the pill via the event stream
  // ---------------------------------------------------------------------------

  testWidgets('first exercise created via PlanService dismisses pill', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.pumpWidget(_pillHarness());
    await tester.pump();

    expect(find.text(l10n.startHereCue), findsOneWidget);

    await PlanService().saveExercise(
      await AppLocalizations.delegate.load(const Locale('en')),
      _exercise,
    );
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppConfig.keyStartHereSeen), isTrue);
    expect(find.text(l10n.startHereCue), findsNothing);
  });
}
