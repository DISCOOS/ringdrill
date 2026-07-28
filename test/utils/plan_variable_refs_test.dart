import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/utils/plan_variable_refs.dart';

final _start = SimpleTimeOfDay(hour: 8, minute: 0);
final _end = SimpleTimeOfDay(hour: 9, minute: 0);

Plan _emptyPlan() {
  final now = DateTime(2026);
  return Plan(
    uuid: 'prog-1',
    name: 'Plan',
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.2'),
    teams: const [],
    sessions: const [],
    exercises: const [],
    rolePlays: const [],
    staff: const [],
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
      final plan = _emptyPlan().copyWith(
        variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
        exercises: [
          _exercise(
            stations: const [Station(index: 0, name: 'Post')],
            methodMd: 'Ingen variabler her.',
          ),
        ],
      );

      expect(variableReferenceCount(plan, 'frekvens'), 0);
    });

    test(
      'counts across plan, exercise, station, roleplay and override maps',
      () {
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
        final plan = _emptyPlan().copyWith(
          variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
          exercises: [exercise],
          rolePlays: [rolePlay],
          briefIntroMd: 'Kanal {{var.frekvens}}',
        );

        // plan.briefIntroMd: 1, exercise.methodMd: 2, exercise override
        // key: 1, station.situationMd: 1, station override key: 1,
        // roleplay.behavior: 1 = 7.
        expect(variableReferenceCount(plan, 'frekvens'), 7);
      },
    );

    test('does not confuse a variable name that is a prefix of another', () {
      final plan = _emptyPlan().copyWith(
        variables: const [
          DrillVariable(name: 'kanal', value: 'A'),
          DrillVariable(name: 'kanal2', value: 'B'),
        ],
        briefIntroMd: '{{var.kanal2}}',
      );

      expect(variableReferenceCount(plan, 'kanal'), 0);
      expect(variableReferenceCount(plan, 'kanal2'), 1);
    });

    // DESIGN-008 follow-up 10: name/description fields are just as much a
    // resolution surface as the markdown fields (follow-ups 05/09), but
    // _hits originally never looked at them -- a reference living only in
    // a name/description was invisible to the delete guard.
    test('counts a reference in plan.name and plan.description', () {
      final plan = _emptyPlan().copyWith(
        name: 'Plan {{var.frekvens}}',
        description: 'Om {{var.frekvens}}',
        variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
      );

      expect(variableReferenceCount(plan, 'frekvens'), 2);
    });

    test('counts a reference in exercise.name', () {
      final plan = _emptyPlan().copyWith(
        exercises: [
          Exercise(
            uuid: 'ex-1',
            name: 'Øvelse {{var.frekvens}}',
            startTime: _start,
            endTime: _end,
            numberOfTeams: 1,
            numberOfRounds: 1,
            executionTime: 10,
            evaluationTime: 5,
            rotationTime: 5,
            stations: const [],
            schedule: const [],
          ),
        ],
      );

      expect(variableReferenceCount(plan, 'frekvens'), 1);
    });

    test('counts a reference in station.name and station.description', () {
      final station = Station(
        index: 0,
        name: 'Post {{var.frekvens}}',
        description: 'Ved {{var.frekvens}}',
      );
      final plan = _emptyPlan().copyWith(
        exercises: [
          _exercise(stations: [station]),
        ],
      );

      expect(variableReferenceCount(plan, 'frekvens'), 2);
    });

    test('counts a reference in rolePlay.name', () {
      final rolePlay = RolePlay(
        uuid: 'rp-1',
        index: 0,
        exerciseUuid: 'ex-1',
        name: 'Rolle {{var.frekvens}}',
      );
      final plan = _emptyPlan().copyWith(rolePlays: [rolePlay]);

      expect(variableReferenceCount(plan, 'frekvens'), 1);
    });
  });

  group('variableReferences', () {
    test('one entry per location, not per occurrence', () {
      final plan = _emptyPlan().copyWith(
        exercises: [
          _exercise(methodMd: 'Kanal {{var.frekvens}} og {{var.frekvens}}'),
        ],
      );

      final refs = variableReferences(plan, 'frekvens');
      expect(refs, hasLength(1));
      expect(refs.single.field, PlanVariableField.exerciseMethod);
      expect(refs.single.exerciseNumber, 1);
    });

    test(
      'locations carry the right exercise number, station code and roleplay name',
      () {
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
          stations: [
            const Station(index: 0, name: 'Post A'),
            station,
          ],
          trainingFocusMd: '{{var.frekvens}}',
        );
        final plan = _emptyPlan().copyWith(
          exercises: [exercise1, exercise2],
          rolePlays: [rolePlay],
        );

        final refs = variableReferences(plan, 'frekvens');
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
      },
    );

    test('an override key surfaces as its own reference', () {
      final exercise = _exercise(variableOverrides: const {'frekvens': 'X'});
      final plan = _emptyPlan().copyWith(exercises: [exercise]);

      final refs = variableReferences(plan, 'frekvens');
      expect(refs.single.field, PlanVariableField.exerciseOverride);
      expect(refs.single.exerciseNumber, 1);
    });

    test('a name-only reference surfaces with the right field', () {
      final station = Station(index: 0, name: 'Post {{var.frekvens}}');
      final exercise = _exercise(stations: [station]);
      final plan = _emptyPlan().copyWith(exercises: [exercise]);

      final refs = variableReferences(plan, 'frekvens');
      expect(refs.single.field, PlanVariableField.stationName);
      expect(refs.single.stationCode, isNotNull);
    });
  });

  group('renameVariable', () {
    test('carries a facet path over unchanged (DESIGN-008 follow-up 11): '
        '{{var.old.utm}} becomes {{var.new.utm}}, never a bare token', () {
      final plan = _emptyPlan().copyWith(
        variables: const [
          DrillVariable(name: 'oppmote', type: VariableType.location),
        ],
        briefIntroMd: 'Møt på {{var.oppmote.utm}} ({{var.oppmote.place}})',
      );
      final renamed = renameVariable(plan, 'oppmote', 'moetested');
      expect(
        renamed.briefIntroMd,
        'Møt på {{var.moetested.utm}} ({{var.moetested.place}})',
      );
    });

    test(
      'rewrites every markdown field and override key, and the registry entry',
      () {
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
        final plan = _emptyPlan().copyWith(
          variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
          exercises: [exercise],
          rolePlays: [rolePlay],
          briefIntroMd: 'Plan kanal {{var.frekvens}}',
          commsMd: 'Talegruppe {{var.frekvens}}',
          beforeRoundMd: 'Før runden: {{var.frekvens}}',
        );

        final renamed = renameVariable(plan, 'frekvens', 'kanal');

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
      },
    );

    test('does not mutate the original plan', () {
      final plan = _emptyPlan().copyWith(
        variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
        briefIntroMd: '{{var.frekvens}}',
      );

      renameVariable(plan, 'frekvens', 'kanal');

      expect(plan.variables.single.name, 'frekvens');
      expect(plan.briefIntroMd, '{{var.frekvens}}');
    });

    test('leaves fields referencing a different variable untouched', () {
      final plan = _emptyPlan().copyWith(
        variables: const [
          DrillVariable(name: 'frekvens', value: 'Kanal 6'),
          DrillVariable(name: 'kode', value: 'Alfa'),
        ],
        briefIntroMd: '{{var.frekvens}} og {{var.kode}}',
      );

      final renamed = renameVariable(plan, 'frekvens', 'radio');

      expect(renamed.briefIntroMd, '{{var.radio}} og {{var.kode}}');
      expect(renamed.variables.map((v) => v.name), ['radio', 'kode']);
    });

    // DESIGN-008 follow-up 10 regression: before this fix, renaming left
    // every name/description field pointing at the now-nonexistent old
    // name -- exactly the "silent breakage" ADR-0046's rename feature
    // exists to prevent.
    test('rewrites plan.name/description, exercise.name, station.name/'
        'description and rolePlay.name', () {
      final station = Station(
        index: 0,
        name: 'Post {{var.frekvens}}',
        description: 'Ved {{var.frekvens}}',
      );
      final rolePlay = RolePlay(
        uuid: 'rp-1',
        index: 0,
        exerciseUuid: 'ex-1',
        name: 'Rolle {{var.frekvens}}',
      );
      final exercise = _exercise(
        uuid: 'ex-1',
        stations: [station],
      ).copyWith(name: 'Øvelse {{var.frekvens}}');
      final plan = _emptyPlan().copyWith(
        name: 'Plan {{var.frekvens}}',
        description: 'Om {{var.frekvens}}',
        variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
        exercises: [exercise],
        rolePlays: [rolePlay],
      );

      final renamed = renameVariable(plan, 'frekvens', 'kanal');

      expect(renamed.name, 'Plan {{var.kanal}}');
      expect(renamed.description, 'Om {{var.kanal}}');
      expect(renamed.exercises.single.name, 'Øvelse {{var.kanal}}');
      final renamedStation = renamed.exercises.single.stations.single;
      expect(renamedStation.name, 'Post {{var.kanal}}');
      expect(renamedStation.description, 'Ved {{var.kanal}}');
      expect(renamed.rolePlays.single.name, 'Rolle {{var.kanal}}');

      // No reference is left pointing at the old (now nonexistent) name.
      expect(variableReferenceCount(renamed, 'frekvens'), 0);
    });
  });
}
