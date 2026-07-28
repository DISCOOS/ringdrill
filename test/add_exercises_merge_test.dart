import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/views/add_exercises_dialog.dart';

void main() {
  test('projects add-exercises merge and applies overwrites by uuid', () {
    final active = _plan(
      uuid: 'active',
      exercises: [
        _exercise('exercise-1', 'Warmup'),
        _exercise('exercise-2', 'Ladder'),
      ],
      teams: const [
        Team(uuid: 'team-1', index: 0, name: 'Red'),
        Team(uuid: 'team-2', index: 1, name: 'Blue'),
      ],
    );
    final incoming = _plan(
      uuid: 'incoming',
      exercises: [
        _exercise('exercise-2', 'Ladder changed'),
        _exercise('exercise-3', 'Sprint'),
        _exercise('exercise-4', 'Recovery'),
      ],
      teams: const [
        Team(uuid: 'team-2', index: 1, name: 'Blue changed'),
        Team(uuid: 'team-3', index: 2, name: 'Green'),
      ],
    );
    final selected = incoming.exercises
        .map((exercise) => exercise.uuid)
        .toList();

    final projected = projectMergedPlan(active, incoming, selected);
    final diff = diffPlans(active, projected);

    expect(diff.modifiedExercises.map((i) => i.name), ['Ladder changed']);
    expect(diff.addedExercises, ['Recovery', 'Sprint']);
    expect(diff.modifiedTeams.map((i) => i.name), ['Blue changed']);
    expect(diff.addedTeams, ['Green']);

    final applied = applyProjectedMerge(active, incoming, selected);
    expect(applied.exercises, hasLength(4));
    expect(applied.teams, hasLength(3));
    expect(
      applied.exercises
          .singleWhere((exercise) => exercise.uuid == 'exercise-2')
          .name,
      'Ladder changed',
    );
    expect(
      applied.teams.singleWhere((team) => team.uuid == 'team-2').name,
      'Blue changed',
    );
  });
}

Plan _plan({
  required String uuid,
  required List<Exercise> exercises,
  required List<Team> teams,
}) {
  final now = DateTime(2026);
  return Plan(
    uuid: uuid,
    name: uuid,
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
    teams: teams,
    sessions: const [],
    exercises: exercises,
    rolePlays: const [],
    staff: const [],
  );
}

Exercise _exercise(String uuid, String name) {
  return Exercise(
    uuid: uuid,
    name: name,
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
}
