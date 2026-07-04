import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/utils/plan_variable_refs.dart';

final _start = SimpleTimeOfDay(hour: 8, minute: 0);
final _end = SimpleTimeOfDay(hour: 9, minute: 0);

Program _emptyProgram() {
  final now = DateTime(2026);
  return Program(
    uuid: 'prog-1',
    name: 'Program',
    description: '',
    metadata: ProgramMetadata(created: now, updated: now, version: '1.2'),
    teams: const [],
    sessions: const [],
    exercises: const [],
    rolePlays: const [],
    actors: const [],
  );
}

Exercise _exercise({
  String uuid = 'ex-1',
  List<Station> stations = const [],
  String? methodMd,
  String? learningGoalsMd,
  String? trainingFocusMd,
  String? orderFormatMd,
  String? executionTipsMd,
  String? commsMd,
  Map<String, String> variableOverrides = const {},
}) {
  return Exercise(
    uuid: uuid,
    name: 'Exercise',
    startTime: _start,
    endTime: _end,
    numberOfTeams: 1,
    numberOfRounds: 1,
    executionTime: 10,
    evaluationTime: 5,
    rotationTime: 5,
    stations: stations,
    schedule: const [],
    methodMd: methodMd,
    learningGoalsMd: learningGoalsMd,
    trainingFocusMd: trainingFocusMd,
    orderFormatMd: orderFormatMd,
    executionTipsMd: executionTipsMd,
    commsMd: commsMd,
    variableOverrides: variableOverrides,
  );
}

void main() {
  group('variableReferenceCount', () {
    test('zero when the variable is not referenced anywhere', () {
      final program = _emptyProgram().copyWith(
        variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
        exercises: [
          _exercise(
            stations: const [Station(index: 0, name: 'Post')],
            methodMd: 'Ingen variabler her.',
          ),
        ],
      );

      expect(variableReferenceCount(program, 'frekvens'), 0);
    });

    test('counts across program, exercise, station, roleplay and override maps', () {
      final rolePlay = RolePlay(
        uuid: 'rp-1',
        index: 0,
        exerciseUuid: 'ex-1',
        name: 'Rolle',
        stationIndex: 0,
        behavior: 'Sier {{var.frekvens}}',
      );
      final station = Station(
        index: 0,
        name: 'Post',
        situationMd: 'Kanal {{var.frekvens}}',
        variableOverrides: const {'frekvens': 'Kanal 9'},
      );
      final exercise = _exercise(
        stations: [station],
        methodMd: 'Kanal {{var.frekvens}} og {{var.frekvens}} igjen',
        variableOverrides: const {'frekvens': 'Kanal 8'},
      );
      final program = _emptyProgram().copyWith(
        variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
        exercises: [exercise],
        rolePlays: [rolePlay],
        briefIntroMd: 'Kanal {{var.frekvens}}',
      );

      // program.briefIntroMd: 1, exercise.methodMd: 2, exercise override
      // key: 1, station.situationMd: 1, station override key: 1,
      // roleplay.behavior: 1 = 7.
      expect(variableReferenceCount(program, 'frekvens'), 7);
    });

    test('does not confuse a variable name that is a prefix of another', () {
      final program = _emptyProgram().copyWith(
        variables: const [
          DrillVariable(name: 'kanal', value: 'A'),
          DrillVariable(name: 'kanal2', value: 'B'),
        ],
        briefIntroMd: '{{var.kanal2}}',
      );

      expect(variableReferenceCount(program, 'kanal'), 0);
      expect(variableReferenceCount(program, 'kanal2'), 1);
    });
  });

  group('variableReferences', () {
    test('one entry per location, not per occurrence', () {
      final program = _emptyProgram().copyWith(
        exercises: [
          _exercise(methodMd: 'Kanal {{var.frekvens}} og {{var.frekvens}}'),
        ],
      );

      final refs = variableReferences(program, 'frekvens');
      expect(refs, hasLength(1));
      expect(refs.single.field, PlanVariableField.exerciseMethod);
      expect(refs.single.exerciseNumber, 1);
    });

    test('locations carry the right exercise number, station code and roleplay name', () {
      final rolePlay = RolePlay(
        uuid: 'rp-1',
        index: 0,
        exerciseUuid: 'ex-2',
        name: 'Turgåer',
        stationIndex: 0,
        propsMd: '{{var.frekvens}}',
      );
      final station = Station(
        index: 1,
        name: 'Post B',
        criticalQuestionsMd: '{{var.frekvens}}',
      );
      // A first exercise with no reference, so the second exercise's
      // 1-based number (2) is exercised, not just the index (1).
      final exercise1 = _exercise(uuid: 'ex-1');
      final exercise2 = _exercise(
        uuid: 'ex-2',
        stations: [const Station(index: 0, name: 'Post A'), station],
        trainingFocusMd: '{{var.frekvens}}',
      );
      final program = _emptyProgram().copyWith(
        exercises: [exercise1, exercise2],
        rolePlays: [rolePlay],
      );

      final refs = variableReferences(program, 'frekvens');
      expect(refs, hasLength(3));

      final exerciseRef = refs.firstWhere(
        (r) => r.field == PlanVariableField.exerciseTrainingFocus,
      );
      expect(exerciseRef.exerciseNumber, 2);

      final stationRef = refs.firstWhere(
        (r) => r.field == PlanVariableField.stationCriticalQuestions,
      );
      expect(
        stationRef.stationCode,
        Numbering.station(
          StationNumberFormat.dotted,
          exerciseNumber: 2,
          stationIndex: 1,
        ),
      );

      final roleplayRef = refs.firstWhere(
        (r) => r.field == PlanVariableField.roleplayProps,
      );
      expect(roleplayRef.roleplayName, 'Turgåer');
    });

    test('an override key surfaces as its own reference', () {
      final exercise = _exercise(variableOverrides: const {'frekvens': 'X'});
      final program = _emptyProgram().copyWith(exercises: [exercise]);

      final refs = variableReferences(program, 'frekvens');
      expect(refs.single.field, PlanVariableField.exerciseOverride);
      expect(refs.single.exerciseNumber, 1);
    });
  });

  group('renameVariable', () {
    test('rewrites every markdown field and override key, and the registry entry', () {
      final rolePlay = RolePlay(
        uuid: 'rp-1',
        index: 0,
        exerciseUuid: 'ex-1',
        name: 'Rolle',
        stationIndex: 0,
        behavior: 'Sier {{var.frekvens}}',
        background: 'Bakgrunn {{ var.frekvens }}',
      );
      final station = Station(
        index: 0,
        name: 'Post',
        situationMd: 'Kanal {{var.frekvens}}',
        equipmentMd: 'Radio på {{var.frekvens}}',
        variableOverrides: const {'frekvens': 'Kanal 9'},
      );
      final exercise = _exercise(
        stations: [station],
        methodMd: 'Bruk {{var.frekvens}}',
        variableOverrides: const {'frekvens': 'Kanal 8'},
      );
      final program = _emptyProgram().copyWith(
        variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
        exercises: [exercise],
        rolePlays: [rolePlay],
        briefIntroMd: 'Plan kanal {{var.frekvens}}',
        commsMd: 'Talegruppe {{var.frekvens}}',
        beforeRoundMd: 'Før runden: {{var.frekvens}}',
      );

      final renamed = renameVariable(program, 'frekvens', 'kanal');

      expect(renamed.variables.single.name, 'kanal');
      expect(renamed.variables.single.value, 'Kanal 6');
      expect(renamed.briefIntroMd, 'Plan kanal {{var.kanal}}');
      expect(renamed.commsMd, 'Talegruppe {{var.kanal}}');
      expect(renamed.beforeRoundMd, 'Før runden: {{var.kanal}}');

      final renamedExercise = renamed.exercises.single;
      expect(renamedExercise.methodMd, 'Bruk {{var.kanal}}');
      expect(renamedExercise.variableOverrides, {'kanal': 'Kanal 8'});

      final renamedStation = renamedExercise.stations.single;
      expect(renamedStation.situationMd, 'Kanal {{var.kanal}}');
      expect(renamedStation.equipmentMd, 'Radio på {{var.kanal}}');
      expect(renamedStation.variableOverrides, {'kanal': 'Kanal 9'});

      final renamedRolePlay = renamed.rolePlays.single;
      expect(renamedRolePlay.behavior, 'Sier {{var.kanal}}');
      expect(renamedRolePlay.background, 'Bakgrunn {{var.kanal}}');

      expect(variableReferenceCount(renamed, 'frekvens'), 0);
      // briefIntroMd, commsMd, beforeRoundMd, methodMd, exercise override
      // key, situationMd, equipmentMd, station override key, behavior,
      // background = 10.
      expect(variableReferenceCount(renamed, 'kanal'), 10);
    });

    test('does not mutate the original program', () {
      final program = _emptyProgram().copyWith(
        variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
        briefIntroMd: '{{var.frekvens}}',
      );

      renameVariable(program, 'frekvens', 'kanal');

      expect(program.variables.single.name, 'frekvens');
      expect(program.briefIntroMd, '{{var.frekvens}}');
    });

    test('leaves fields referencing a different variable untouched', () {
      final program = _emptyProgram().copyWith(
        variables: const [
          DrillVariable(name: 'frekvens', value: 'Kanal 6'),
          DrillVariable(name: 'kode', value: 'Alfa'),
        ],
        briefIntroMd: '{{var.frekvens}} og {{var.kode}}',
      );

      final renamed = renameVariable(program, 'frekvens', 'radio');

      expect(renamed.briefIntroMd, '{{var.radio}} og {{var.kode}}');
      expect(renamed.variables.map((v) => v.name), ['radio', 'kode']);
    });
  });
}
