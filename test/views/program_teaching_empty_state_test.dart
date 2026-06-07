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
import 'package:ringdrill/views/widgets/teaching_empty_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _emptyProgramUuid = 'empty-program';
const _fullProgramUuid = 'full-program';
const _exerciseUuid = 'teaching-exercise';

final _exercise = Exercise(
  uuid: _exerciseUuid,
  name: 'Teaching Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [Station(index: 0, name: 'Teaching Station')],
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
  uuid: 'teaching-role',
  index: 0,
  exerciseUuid: _exerciseUuid,
  name: 'Teaching Role',
  stationIndex: 0,
);

final _team = Team(uuid: 'teaching-team', index: 0, name: 'Teaching Team');

Map<String, Object?> _programJson(String uuid) => {
  'uuid': uuid,
  'name': 'Teaching Program',
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

Map<String, Object> _prefs() {
  return {
    'app:activeProgram:v1': _emptyProgramUuid,
    'app:librarySchema:v1': '1',
    'p:$_emptyProgramUuid': jsonEncode(_programJson(_emptyProgramUuid)),
    'p:$_fullProgramUuid': jsonEncode(_programJson(_fullProgramUuid)),
    'pe:$_fullProgramUuid:$_exerciseUuid': jsonEncode(_exercise.toJson()),
    'pt:$_fullProgramUuid:${_team.uuid}': jsonEncode(_team.toJson()),
    'pr:$_fullProgramUuid:${_rolePlay.uuid}': jsonEncode(_rolePlay.toJson()),
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

void _select(_HarnessControllers controllers, ProgramSegment segment) {
  controllers.program.activeSegment.value = segment;
}

Finder _teachingIcon(IconData icon) {
  return find.descendant(
    of: find.byType(TeachingEmptyState),
    matching: find.byIcon(icon),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(_prefs());
    await ProgramService().init();
  });

  testWidgets('Exercises segment teaches when empty and keeps create FAB', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await ProgramService().setActive(_emptyProgramUuid);
    final controllers = _HarnessControllers();
    addTearDown(controllers.dispose);

    await tester.pumpWidget(_programHarness(controllers));
    await tester.pumpAndSettle();

    expect(find.text(l10n.emptyExercisesTitle), findsOneWidget);
    expect(find.text(l10n.emptyExercisesBody), findsOneWidget);
    expect(_teachingIcon(Icons.update), findsOneWidget);
    expect(find.byType(FloatingActionButton).hitTestable(), findsOneWidget);

    await ProgramService().setActive(_fullProgramUuid);
    await tester.pumpAndSettle();

    expect(find.text(l10n.emptyExercisesTitle), findsNothing);
    expect(find.text(l10n.emptyExercisesBody), findsNothing);
    expect(find.text('Teaching Exercise').hitTestable(), findsOneWidget);
  });

  testWidgets('Stations segment teaches when empty without adding a FAB', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await ProgramService().setActive(_emptyProgramUuid);
    final controllers = _HarnessControllers();
    addTearDown(controllers.dispose);
    _select(controllers, ProgramSegment.stations);

    await tester.pumpWidget(_programHarness(controllers));
    await tester.pumpAndSettle();

    expect(find.text(l10n.emptyStationsTitle), findsOneWidget);
    expect(find.text(l10n.emptyStationsBody), findsOneWidget);
    expect(_teachingIcon(Icons.place), findsOneWidget);
    expect(find.byType(FloatingActionButton).hitTestable(), findsNothing);

    await ProgramService().setActive(_fullProgramUuid);
    await tester.pumpAndSettle();

    expect(find.text(l10n.emptyStationsTitle), findsNothing);
    expect(find.text(l10n.emptyStationsBody), findsNothing);
    expect(find.text('Teaching Station').hitTestable(), findsOneWidget);
  });

  testWidgets('Script segment teaches when empty and keeps create FAB', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await ProgramService().setActive(_emptyProgramUuid);
    final controllers = _HarnessControllers();
    addTearDown(controllers.dispose);
    _select(controllers, ProgramSegment.script);

    await tester.pumpWidget(_programHarness(controllers));
    await tester.pumpAndSettle();

    expect(find.text(l10n.emptyRolesTitle), findsOneWidget);
    expect(find.text(l10n.emptyRolesBody), findsOneWidget);
    expect(_teachingIcon(Icons.theater_comedy), findsOneWidget);
    expect(find.byType(FloatingActionButton).hitTestable(), findsOneWidget);

    await ProgramService().setActive(_fullProgramUuid);
    await tester.pumpAndSettle();

    expect(find.text(l10n.emptyRolesTitle), findsNothing);
    expect(find.text(l10n.emptyRolesBody), findsNothing);
    expect(find.text('Teaching Role').hitTestable(), findsOneWidget);
  });

  testWidgets('Teams segment teaches when empty without adding a FAB', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await ProgramService().setActive(_emptyProgramUuid);
    final controllers = _HarnessControllers();
    addTearDown(controllers.dispose);
    _select(controllers, ProgramSegment.teams);

    await tester.pumpWidget(_programHarness(controllers));
    await tester.pumpAndSettle();

    expect(find.text(l10n.emptyTeamsTitle), findsOneWidget);
    expect(find.text(l10n.emptyTeamsBody), findsOneWidget);
    expect(_teachingIcon(Icons.group), findsOneWidget);
    expect(find.byType(FloatingActionButton).hitTestable(), findsNothing);

    await ProgramService().setActive(_fullProgramUuid);
    await tester.pumpAndSettle();

    expect(find.text(l10n.emptyTeamsTitle), findsNothing);
    expect(find.text(l10n.emptyTeamsBody), findsNothing);
    expect(find.text('Teaching Team').hitTestable(), findsOneWidget);
  });
}
