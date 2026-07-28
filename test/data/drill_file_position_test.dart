import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';

/// Coverage for the data layer half of the position-picker fix
/// (station_form_screen.dart / team_form_screen.dart / roleplay_form_screen.dart):
/// once a picked LatLng reaches the model (proven separately by
/// test/views/position_form_field_test.dart, which drives the actual map
/// picker), it must survive a full DrillFile save/load round trip — the
/// question this test answers is literally "does it land in the drill
/// file", not just "does the form's in-memory state update".
void main() {
  final now = DateTime(2026);

  Plan emptyPlan() => Plan(
    uuid: 'prog-1',
    name: 'Test',
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
    teams: const [],
    sessions: const [],
    exercises: const [],
    rolePlays: const [],
    staff: const [],
  );

  final start = SimpleTimeOfDay(hour: 9, minute: 0);
  final end = SimpleTimeOfDay(hour: 10, minute: 0);

  test('station position survives a save/load roundtrip', () {
    final station = Station(
      index: 0,
      name: 'Station 0',
      position: LatLng(59.911, 10.757),
    );
    final exercise = Exercise(
      uuid: 'ex-1',
      name: 'Ex One',
      startTime: start,
      endTime: end,
      numberOfTeams: 1,
      numberOfRounds: 1,
      executionTime: 30,
      evaluationTime: 5,
      rotationTime: 5,
      stations: [station],
      schedule: const [],
    );
    final plan = emptyPlan().copyWith(exercises: [exercise]);

    final decoded = DrillFile.fromPlan(plan, 'test').plan();
    final decodedStation = decoded.exercises.single.stations.single;

    expect(decodedStation.position, LatLng(59.911, 10.757));
  });

  test('team position survives a save/load roundtrip', () {
    final team = Team(
      uuid: 'team-1',
      index: 0,
      name: 'Team 1',
      position: LatLng(58.99, 10.43),
    );
    final plan = emptyPlan().copyWith(teams: [team]);

    final decoded = DrillFile.fromPlan(plan, 'test').plan();

    expect(decoded.teams.single.position, LatLng(58.99, 10.43));
  });

  test('rolePlay position survives a save/load roundtrip', () {
    final rolePlay = RolePlay(
      uuid: 'rp-1',
      index: 0,
      exerciseUuid: 'ex-1',
      name: 'Anna',
      position: LatLng(59.0, 10.0),
    );
    final plan = emptyPlan().copyWith(rolePlays: [rolePlay]);

    final decoded = DrillFile.fromPlan(plan, 'test').plan();

    expect(decoded.rolePlays.single.position, LatLng(59.0, 10.0));
  });

  test('a null position stays null across a save/load roundtrip', () {
    final station = Station(index: 0, name: 'Station 0');
    final exercise = Exercise(
      uuid: 'ex-1',
      name: 'Ex One',
      startTime: start,
      endTime: end,
      numberOfTeams: 1,
      numberOfRounds: 1,
      executionTime: 30,
      evaluationTime: 5,
      rotationTime: 5,
      stations: [station],
      schedule: const [],
    );
    final plan = emptyPlan().copyWith(exercises: [exercise]);

    final decoded = DrillFile.fromPlan(plan, 'test').plan();

    expect(decoded.exercises.single.stations.single.position, isNull);
  });

  test('changing a station position changes the content hash', () {
    final station = Station(
      index: 0,
      name: 'Station 0',
      position: LatLng(59.911, 10.757),
    );
    final movedStation = station.copyWith(position: LatLng(59.912, 10.758));
    final exercise = Exercise(
      uuid: 'ex-1',
      name: 'Ex One',
      startTime: start,
      endTime: end,
      numberOfTeams: 1,
      numberOfRounds: 1,
      executionTime: 30,
      evaluationTime: 5,
      rotationTime: 5,
      stations: [station],
      schedule: const [],
    );
    final plan = emptyPlan().copyWith(exercises: [exercise]);
    final moved = plan.copyWith(
      exercises: [
        exercise.copyWith(stations: [movedStation]),
      ],
    );

    expect(plan.computeContentHash(), isNot(moved.computeContentHash()));
  });
}
