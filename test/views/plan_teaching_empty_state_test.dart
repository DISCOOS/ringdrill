import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/plan_view.dart';
import 'package:ringdrill/views/roleplay_list_view.dart';
import 'package:ringdrill/views/station_list_view.dart';
import 'package:ringdrill/views/teams_view.dart';
import 'package:ringdrill/views/widgets/teaching_empty_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _emptyPlanUuid = 'empty-plan';
const _fullPlanUuid = 'full-plan';
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

Map<String, Object?> _planJson(String uuid) => {
  'uuid': uuid,
  'name': 'Teaching Plan',
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
    'app:activePlan:v1': _emptyPlanUuid,
    'app:librarySchema:v1': '1',
    'p:$_emptyPlanUuid': jsonEncode(_planJson(_emptyPlanUuid)),
    'p:$_fullPlanUuid': jsonEncode(_planJson(_fullPlanUuid)),
    'pe:$_fullPlanUuid:$_exerciseUuid': jsonEncode(_exercise.toJson()),
    'pt:$_fullPlanUuid:${_team.uuid}': jsonEncode(_team.toJson()),
    'pr:$_fullPlanUuid:${_rolePlay.uuid}': jsonEncode(_rolePlay.toJson()),
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

void _select(_HarnessControllers controllers, PlanSegment segment) {
  controllers.plan.activeSegment.value = segment;
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
    await PlanService().init();
  });

  testWidgets('Exercises segment teaches when empty and keeps create FAB', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await PlanService().setActive(_emptyPlanUuid);
    final controllers = _HarnessControllers();
    addTearDown(controllers.dispose);

    await tester.pumpWidget(_planHarness(controllers));
    await tester.pumpAndSettle();

    expect(find.text(l10n.emptyExercisesTitle), findsOneWidget);
    expect(find.text(l10n.emptyExercisesBody), findsOneWidget);
    expect(_teachingIcon(Icons.update), findsOneWidget);
    expect(find.byType(FloatingActionButton).hitTestable(), findsOneWidget);

    await PlanService().setActive(_fullPlanUuid);
    await tester.pumpAndSettle();

    expect(find.text(l10n.emptyExercisesTitle), findsNothing);
    expect(find.text(l10n.emptyExercisesBody), findsNothing);
    expect(find.text('Teaching Exercise').hitTestable(), findsOneWidget);
  });

  testWidgets('Stations segment teaches when empty without adding a FAB', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await PlanService().setActive(_emptyPlanUuid);
    final controllers = _HarnessControllers();
    addTearDown(controllers.dispose);
    _select(controllers, PlanSegment.stations);

    await tester.pumpWidget(_planHarness(controllers));
    await tester.pumpAndSettle();

    expect(find.text(l10n.emptyStationsTitle), findsOneWidget);
    expect(find.text(l10n.emptyStationsBody), findsOneWidget);
    expect(_teachingIcon(Icons.place), findsOneWidget);
    expect(find.byType(FloatingActionButton).hitTestable(), findsNothing);

    await PlanService().setActive(_fullPlanUuid);
    await tester.pumpAndSettle();

    expect(find.text(l10n.emptyStationsTitle), findsNothing);
    expect(find.text(l10n.emptyStationsBody), findsNothing);
    expect(find.text('Teaching Station').hitTestable(), findsOneWidget);
  });

  testWidgets('Script segment teaches when empty and hides create FAB', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await PlanService().setActive(_emptyPlanUuid);
    final controllers = _HarnessControllers();
    addTearDown(controllers.dispose);
    _select(controllers, PlanSegment.script);

    await tester.pumpWidget(_planHarness(controllers));
    await tester.pumpAndSettle();

    expect(find.text(l10n.emptyRolesTitle), findsOneWidget);
    expect(find.text(l10n.emptyRolesBody), findsOneWidget);
    expect(_teachingIcon(Icons.theater_comedy), findsOneWidget);
    expect(find.byType(FloatingActionButton).hitTestable(), findsNothing);

    await PlanService().setActive(_fullPlanUuid);
    await tester.pumpAndSettle();

    expect(find.text(l10n.emptyRolesTitle), findsNothing);
    expect(find.text(l10n.emptyRolesBody), findsNothing);
    expect(find.text('Teaching Role').hitTestable(), findsOneWidget);
    expect(find.byType(FloatingActionButton).hitTestable(), findsOneWidget);
  });

  testWidgets('Teams segment teaches when empty without adding a FAB', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await PlanService().setActive(_emptyPlanUuid);
    final controllers = _HarnessControllers();
    addTearDown(controllers.dispose);
    _select(controllers, PlanSegment.teams);

    await tester.pumpWidget(_planHarness(controllers));
    await tester.pumpAndSettle();

    expect(find.text(l10n.emptyTeamsTitle), findsOneWidget);
    expect(find.text(l10n.emptyTeamsBody), findsOneWidget);
    expect(_teachingIcon(Icons.group), findsOneWidget);
    expect(find.byType(FloatingActionButton).hitTestable(), findsNothing);

    await PlanService().setActive(_fullPlanUuid);
    await tester.pumpAndSettle();

    expect(find.text(l10n.emptyTeamsTitle), findsNothing);
    expect(find.text(l10n.emptyTeamsBody), findsNothing);
    expect(find.text('Teaching Team').hitTestable(), findsOneWidget);
  });
}
