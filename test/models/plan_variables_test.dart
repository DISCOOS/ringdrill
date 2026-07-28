import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations_en.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';

void main() {
  final now = DateTime(2026);

  Plan base() => Plan(
    uuid: 'prog-1',
    name: 'Test',
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
    teams: const [],
    sessions: const [],
    exercises: const [],
    rolePlays: const [],
    actors: const [],
  );

  Map<String, dynamic> minimalJson() => {
    'uuid': 'prog-1',
    'name': 'Test',
    'description': '',
    'metadata': {
      'created': '2026-01-01T00:00:00.000',
      'updated': '2026-01-01T00:00:00.000',
      'version': '1.0',
    },
    'teams': [],
    'sessions': [],
    'exercises': [],
  };

  const freq = DrillVariable(
    name: 'frekvens',
    value: 'Kanal 6',
    hint: 'Sambandskanal',
  );
  const meetingPoint = DrillVariable(name: 'oppmote', value: 'Torget');

  group('backward compatibility', () {
    test('program.json without variables deserializes to empty list', () {
      final plan = Plan.fromJson(minimalJson());
      expect(plan.variables, isEmpty);
    });

    test('exercise/station json without variableOverrides deserializes to '
        'empty map', () {
      final exercise = Exercise.fromJson({
        'uuid': 'ex-1',
        'name': 'Ex',
        'startTime': {'hour': 8, 'minute': 0},
        'endTime': {'hour': 9, 'minute': 0},
        'numberOfTeams': 1,
        'numberOfRounds': 1,
        'executionTime': 10,
        'evaluationTime': 5,
        'rotationTime': 5,
        'stations': [],
        'schedule': [],
      });
      expect(exercise.variableOverrides, isEmpty);

      final station = Station.fromJson({'index': 0, 'name': 'S1'});
      expect(station.variableOverrides, isEmpty);
    });

    test('opens a synthetic pre-existing archive with no variables key', () {
      // Simulates a schema 1.2 .drill written before this change: no
      // 'variables' key in program.json, no 'variableOverrides' in the
      // exercise/station manifests.
      final plan = Plan(
        uuid: 'prog-old',
        name: 'Old',
        description: '',
        metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
        teams: const [],
        sessions: const [],
        exercises: [
          Exercise(
            uuid: 'ex-1',
            name: 'Ex',
            startTime: SimpleTimeOfDay(hour: 8, minute: 0),
            endTime: SimpleTimeOfDay(hour: 9, minute: 0),
            numberOfTeams: 1,
            numberOfRounds: 1,
            executionTime: 10,
            evaluationTime: 5,
            rotationTime: 5,
            stations: const [Station(index: 0, name: 'S1')],
            schedule: const [],
          ),
        ],
        rolePlays: const [],
        actors: const [],
      );

      final drillFile = DrillFile.fromPlan(plan, 'legacy');
      final decoded = drillFile.plan();

      expect(decoded.variables, isEmpty);
      expect(decoded.exercises.single.variableOverrides, isEmpty);
      expect(
        decoded.exercises.single.stations.single.variableOverrides,
        isEmpty,
      );
    });
  });

  group('round-trips', () {
    test('Plan registry round-trips through the real DrillFile archive', () {
      final plan = base().copyWith(variables: [freq, meetingPoint]);

      final drillFile = DrillFile.fromPlan(plan, 'test');
      final decoded = drillFile.plan();

      expect(decoded.variables, unorderedEquals([freq, meetingPoint]));
    });

    test('typed variables round-trip through the real DrillFile archive '
        '(DESIGN-008 follow-up 11)', () {
      const typed = [
        DrillVariable(name: 'tid', type: VariableType.time, value: '12:00'),
        DrillVariable(
          name: 'varighet',
          type: VariableType.duration,
          value: '90',
        ),
        DrillVariable(
          name: 'oppmote',
          type: VariableType.location,
          location: VariableLocation(
            place: 'Meiselen 14',
            position: LatLng(59.7445, 10.2045),
          ),
        ),
      ];
      final plan = base().copyWith(variables: typed);

      final decoded = DrillFile.fromPlan(plan, 'test').plan();

      expect(decoded.variables, unorderedEquals(typed));
      final location = decoded.variables
          .singleWhere((v) => v.name == 'oppmote')
          .location!;
      expect(location.place, 'Meiselen 14');
      expect(location.position!.latitude, closeTo(59.7445, 1e-9));
    });

    test('Exercise and Station variableOverrides round-trip through the '
        'archive', () {
      final station = Station(
        index: 0,
        name: 'S1',
        variableOverrides: const {'frekvens': 'Kanal 8'},
      );
      final exercise = Exercise(
        uuid: 'ex-1',
        name: 'Ex',
        startTime: SimpleTimeOfDay(hour: 8, minute: 0),
        endTime: SimpleTimeOfDay(hour: 9, minute: 0),
        numberOfTeams: 1,
        numberOfRounds: 1,
        executionTime: 10,
        evaluationTime: 5,
        rotationTime: 5,
        stations: [station],
        schedule: const [],
        variableOverrides: const {'frekvens': 'Kanal 8'},
      );
      final plan = base().copyWith(variables: [freq], exercises: [exercise]);

      final decoded = DrillFile.fromPlan(plan, 'test').plan();
      final decodedExercise = decoded.exercises.single;

      expect(decodedExercise.variableOverrides, {'frekvens': 'Kanal 8'});
      expect(decodedExercise.stations.single.variableOverrides, {
        'frekvens': 'Kanal 8',
      });
    });
  });

  group('content hash sensitivity', () {
    test('changes when a variable type changes (DESIGN-008 follow-up 11)', () {
      final prog = base().copyWith(variables: [freq]);
      final changed = prog.copyWith(
        variables: [freq.copyWith(type: VariableType.number)],
      );
      expect(prog.computeContentHash(), isNot(changed.computeContentHash()));
    });

    test('changes when a variable value changes', () {
      final prog = base().copyWith(variables: [freq]);
      final changed = prog.copyWith(
        variables: [freq.copyWith(value: 'Kanal 7')],
      );
      expect(prog.computeContentHash(), isNot(changed.computeContentHash()));
    });

    test('changes when a variable is added', () {
      final prog = base().copyWith(variables: [freq]);
      final withTwo = prog.copyWith(variables: [freq, meetingPoint]);
      expect(prog.computeContentHash(), isNot(withTwo.computeContentHash()));
    });

    test('is stable when variables differ only in list order', () {
      final a = base().copyWith(variables: [freq, meetingPoint]);
      final b = base().copyWith(variables: [meetingPoint, freq]);
      expect(a.computeContentHash(), b.computeContentHash());
    });

    test('changes when an exercise variableOverrides entry changes', () {
      Exercise exercise(String value) => Exercise(
        uuid: 'ex-1',
        name: 'Ex',
        startTime: SimpleTimeOfDay(hour: 8, minute: 0),
        endTime: SimpleTimeOfDay(hour: 9, minute: 0),
        numberOfTeams: 1,
        numberOfRounds: 1,
        executionTime: 10,
        evaluationTime: 5,
        rotationTime: 5,
        stations: const [],
        schedule: const [],
        variableOverrides: {'frekvens': value},
      );

      final prog = base().copyWith(exercises: [exercise('Kanal 6')]);
      final changed = base().copyWith(exercises: [exercise('Kanal 8')]);
      expect(prog.computeContentHash(), isNot(changed.computeContentHash()));
    });

    test('changes when a station variableOverrides entry changes', () {
      Exercise exercise(String value) => Exercise(
        uuid: 'ex-1',
        name: 'Ex',
        startTime: SimpleTimeOfDay(hour: 8, minute: 0),
        endTime: SimpleTimeOfDay(hour: 9, minute: 0),
        numberOfTeams: 1,
        numberOfRounds: 1,
        executionTime: 10,
        evaluationTime: 5,
        rotationTime: 5,
        stations: [
          Station(index: 0, name: 'S1', variableOverrides: {'frekvens': value}),
        ],
        schedule: const [],
      );

      final prog = base().copyWith(exercises: [exercise('Kanal 6')]);
      final changed = base().copyWith(exercises: [exercise('Kanal 8')]);
      expect(prog.computeContentHash(), isNot(changed.computeContentHash()));
    });
  });

  test('generateSchedule preserves an exercise\'s variableOverrides', () {
    final localizations = AppLocalizationsEn();
    final exercise = PlanService.generateSchedule(
      name: 'Ring',
      startTime: const TimeOfDay(hour: 8, minute: 0),
      numberOfTeams: 2,
      numberOfStations: 2,
      numberOfRounds: 1,
      executionTime: 10,
      evaluationTime: 5,
      rotationTime: 2,
      localizations: localizations,
      variableOverrides: const {'frekvens': 'Kanal 8'},
    );

    expect(exercise.variableOverrides, {'frekvens': 'Kanal 8'});
  });
}
