import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:ringdrill/views/roleplays_view.dart';
import 'package:ringdrill/views/station_list_view.dart';
import 'package:ringdrill/views/teams_view.dart';
import 'package:ringdrill/views/widgets/start_here_pill.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _emptyProgramUuid = 'start-here-empty';
const _fullProgramUuid = 'start-here-full';
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

Map<String, Object> _programJson(String uuid) => {
  'uuid': uuid,
  'name': 'Start Here Program',
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

// Both programs seeded once so ProgramRepository's prefs ref stays valid.
Map<String, Object> _basePrefs() => {
  'app:activeProgram:v1': _emptyProgramUuid,
  'app:librarySchema:v1': '1',
  'p:$_emptyProgramUuid': jsonEncode(_programJson(_emptyProgramUuid)),
  'p:$_fullProgramUuid': jsonEncode(_programJson(_fullProgramUuid)),
  'pe:$_fullProgramUuid:$_exerciseUuid': jsonEncode(_exercise.toJson()),
};

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

Widget _programHarness(_HarnessControllers controllers) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ValueListenableBuilder<ProgramSegment>(
      valueListenable: controllers.program.activeSegment,
      builder: (context, _, child) {
        return Scaffold(
          body: child,
          floatingActionButton: controllers.program.buildFAB(
            context,
            const BoxConstraints(),
          ),
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
    await ProgramService().init();
  });

  setUp(() async {
    // Reset flag and active program before each test so they are independent.
    await _clearStartHereFlag();
    await ProgramService().setActive(_emptyProgramUuid);
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

    await tester.pumpWidget(_programHarness(controllers));
    await tester.pumpAndSettle();

    expect(find.text(l10n.startHereCue), findsOneWidget);
  });

  testWidgets('pill hidden when keyStartHereSeen is set', (tester) async {
    await _setStartHereFlag();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final controllers = _HarnessControllers();
    addTearDown(controllers.dispose);

    await tester.pumpWidget(_programHarness(controllers));
    await tester.pumpAndSettle();

    expect(find.text(l10n.startHereCue), findsNothing);
  });

  testWidgets('pill hidden when Øvelser has exercises', (tester) async {
    await ProgramService().setActive(_fullProgramUuid);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final controllers = _HarnessControllers();
    addTearDown(controllers.dispose);

    await tester.pumpWidget(_programHarness(controllers));
    await tester.pumpAndSettle();

    expect(find.text(l10n.startHereCue), findsNothing);
  });

  testWidgets('pill absent on non-Øvelser segment (Script)', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final controllers = _HarnessControllers();
    addTearDown(controllers.dispose);
    controllers.program.activeSegment.value = ProgramSegment.script;

    await tester.pumpWidget(_programHarness(controllers));
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

  testWidgets('first exercise created via ProgramService dismisses pill', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.pumpWidget(_pillHarness());
    await tester.pump();

    expect(find.text(l10n.startHereCue), findsOneWidget);

    await ProgramService().saveExercise(
      await AppLocalizations.delegate.load(const Locale('en')),
      _exercise,
    );
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppConfig.keyStartHereSeen), isTrue);
    expect(find.text(l10n.startHereCue), findsNothing);
  });
}
