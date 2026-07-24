import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/plan_repository.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('migrates legacy exercise and team keys once', () async {
    final exercise = Exercise(
      uuid: 'exercise-1',
      name: 'Exercise 1',
      startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
      numberOfTeams: 1,
      numberOfRounds: 1,
      executionTime: 10,
      evaluationTime: 5,
      rotationTime: 2,
      stations: const [Station(index: 0, name: 'Station 1')],
      schedule: const [
        [
          SimpleTimeOfDay(hour: 8, minute: 0),
          SimpleTimeOfDay(hour: 8, minute: 10),
          SimpleTimeOfDay(hour: 8, minute: 15),
        ],
      ],
      endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
    );
    const team = Team(uuid: 'team-1', index: 0, name: 'Team 1');

    SharedPreferences.setMockInitialValues({
      'e:${exercise.uuid}': jsonEncode(exercise.toJson()),
      't:${team.uuid}': jsonEncode(team.toJson()),
    });

    final prefs = await SharedPreferences.getInstance();
    final repo = PlanRepository(prefs);

    await repo.init();

    final plans = repo.listPlans();
    expect(plans, hasLength(1));
    final planUuid = plans.single.uuid;
    expect(repo.activePlanUuid, planUuid);
    expect(repo.loadExercises(planUuid), [exercise]);
    expect(repo.loadTeams(planUuid), [team]);
    expect(prefs.containsKey('e:${exercise.uuid}'), isFalse);
    expect(prefs.containsKey('t:${team.uuid}'), isFalse);
    expect(prefs.getString(AppConfig.keyLibrarySchema), '1');

    final keysAfterFirstInit = prefs.getKeys().toSet();
    await repo.init();
    expect(prefs.getKeys(), keysAfterFirstInit);
    expect(repo.listPlans(), hasLength(1));
  });
}
