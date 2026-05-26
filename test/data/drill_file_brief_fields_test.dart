import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Program _emptyProgram() {
  final now = DateTime(2026);
  return Program(
    uuid: 'prog-1',
    name: 'Test',
    description: '',
    metadata: ProgramMetadata(created: now, updated: now, version: '1.0'),
    teams: const [],
    sessions: const [],
    exercises: const [],
    rolePlays: const [],
    actors: const [],
  );
}

final _start = SimpleTimeOfDay(hour: 9, minute: 0);
final _end = SimpleTimeOfDay(hour: 10, minute: 0);

Station _station(int index, {String? variantSuffix}) => Station(
      index: index,
      name: 'Station $index',
      variantSuffix: variantSuffix,
      equipmentMd: 'equipment-$index',
      situationMd: 'situation-$index',
      missionMd: 'mission-$index',
      logisticsMd: 'logistics-$index',
      criticalQuestionsMd: 'crit-$index',
      leaderAnswersMd: 'leader-$index',
      directorNotesMd: 'director-$index',
    );

Exercise _exercise({String? templateId}) => Exercise(
      uuid: 'ex-1',
      name: 'Ex One',
      startTime: _start,
      endTime: _end,
      numberOfTeams: 1,
      numberOfRounds: 1,
      executionTime: 30,
      evaluationTime: 5,
      rotationTime: 5,
      stations: [_station(0), _station(1)],
      schedule: const [],
      templateId: templateId,
      methodMd: 'method',
      learningGoalsMd: 'goals',
      trainingFocusMd: 'focus',
      orderFormatMd: 'order',
      executionTipsMd: 'tips',
      commsMd: 'comms',
    );

const _rolePlay = RolePlay(
  uuid: 'rp-1',
  index: 0,
  exerciseUuid: 'ex-1',
  name: 'Anna',
  behavior: 'confused',
  background: 'head trauma',
  propsMd: 'props content',
);

const _actor = Actor(
  uuid: 'actor-1',
  realName: 'Kari',
  notes: 'PII notes',
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Stage 1b writer', () {
    test('writes Stage 1b markdown fields as .md files in archive', () {
      final program = _emptyProgram().copyWith(
        briefIntroMd: 'intro',
        commsMd: 'comms-prog',
        exercises: [_exercise()],
        rolePlays: [_rolePlay],
        actors: [_actor],
      );

      final drillFile = DrillFile.fromProgram(program, 'test');
      final archive = ZipDecoder().decodeBytes(drillFile.content);
      final byName = {
        for (final f in archive.files.where((f) => f.isFile))
          f.name: utf8.decode(f.content as List<int>),
      };

      // Program-level
      expect(byName['program/intro.md'], 'intro');
      expect(byName['program/comms.md'], 'comms-prog');

      // Exercise-level
      expect(byName['exercises/ex-1/method.md'], 'method');
      expect(byName['exercises/ex-1/learning-goals.md'], 'goals');
      expect(byName['exercises/ex-1/training-focus.md'], 'focus');
      expect(byName['exercises/ex-1/order-format.md'], 'order');
      expect(byName['exercises/ex-1/execution-tips.md'], 'tips');
      expect(byName['exercises/ex-1/comms.md'], 'comms');

      // Station-level (index 0)
      expect(byName['exercises/ex-1/stations/0/equipment.md'], 'equipment-0');
      expect(byName['exercises/ex-1/stations/0/situation.md'], 'situation-0');
      expect(byName['exercises/ex-1/stations/0/mission.md'], 'mission-0');
      expect(byName['exercises/ex-1/stations/0/logistics.md'], 'logistics-0');
      expect(byName['exercises/ex-1/stations/0/critical-questions.md'], 'crit-0');
      expect(byName['exercises/ex-1/stations/0/leader-answers.md'], 'leader-0');
      expect(byName['exercises/ex-1/stations/0/director-notes.md'], 'director-0');

      // Station-level (index 1)
      expect(byName['exercises/ex-1/stations/1/equipment.md'], 'equipment-1');

      // RolePlay-level
      expect(byName['roleplays/rp-1/props.md'], 'props content');

      // JSON manifests must NOT contain any *Md keys
      final exJson =
          jsonDecode(byName['exercises/ex-1.json']!) as Map<String, dynamic>;
      expect(exJson.keys.any((k) => k.endsWith('Md')), isFalse,
          reason: 'exercise JSON must not contain *Md keys');

      final rpJson =
          jsonDecode(byName['roleplays/rp-1.json']!) as Map<String, dynamic>;
      expect(rpJson.keys.any((k) => k.endsWith('Md')), isFalse,
          reason: 'roleplay JSON must not contain *Md keys');

      final progJson =
          jsonDecode(byName['program.json']!) as Map<String, dynamic>;
      expect(progJson.keys.any((k) => k.endsWith('Md')), isFalse,
          reason: 'program JSON must not contain *Md keys');
    });

    test('writes templateId and variantSuffix into JSON manifests (not .md)',
        () {
      final exercise = _exercise(templateId: 'my-template').copyWith(
        stations: [_station(0, variantSuffix: 'Alpha')],
      );
      final program = _emptyProgram().copyWith(exercises: [exercise]);

      final drillFile = DrillFile.fromProgram(program, 'test');
      final archive = ZipDecoder().decodeBytes(drillFile.content);
      final byName = {
        for (final f in archive.files.where((f) => f.isFile))
          f.name: utf8.decode(f.content as List<int>),
      };

      final exJson =
          jsonDecode(byName['exercises/ex-1.json']!) as Map<String, dynamic>;
      expect(exJson['templateId'], 'my-template');

      final stationsJson = exJson['stations'] as List<dynamic>;
      final s0 = stationsJson[0] as Map<String, dynamic>;
      expect(s0['variantSuffix'], 'Alpha');

      // No companion .md files for structural fields
      expect(byName.containsKey('exercises/ex-1/templateId.md'), isFalse);
      expect(byName.containsKey('exercises/ex-1/stations/0/variantSuffix.md'),
          isFalse);
    });
  });

  group('Stage 1b reader', () {
    test('reads back Stage 1b markdown fields from archive (roundtrip)', () {
      final program = _emptyProgram().copyWith(
        briefIntroMd: 'intro',
        commsMd: 'comms-prog',
        exercises: [_exercise()],
        rolePlays: [_rolePlay],
      );

      final drillFile = DrillFile.fromProgram(program, 'test');
      final decoded = drillFile.program();

      expect(decoded.briefIntroMd, 'intro');
      expect(decoded.commsMd, 'comms-prog');

      expect(decoded.exercises.length, 1);
      final ex = decoded.exercises.first;
      expect(ex.methodMd, 'method');
      expect(ex.learningGoalsMd, 'goals');
      expect(ex.trainingFocusMd, 'focus');
      expect(ex.orderFormatMd, 'order');
      expect(ex.executionTipsMd, 'tips');
      expect(ex.commsMd, 'comms');

      expect(ex.stations.length, 2);
      final s0 = ex.stations.firstWhere((s) => s.index == 0);
      expect(s0.equipmentMd, 'equipment-0');
      expect(s0.situationMd, 'situation-0');
      expect(s0.missionMd, 'mission-0');
      expect(s0.logisticsMd, 'logistics-0');
      expect(s0.criticalQuestionsMd, 'crit-0');
      expect(s0.leaderAnswersMd, 'leader-0');
      expect(s0.directorNotesMd, 'director-0');

      final rp = decoded.rolePlays.firstWhere((r) => r.uuid == 'rp-1');
      expect(rp.propsMd, 'props content');
    });

    test('Stage 1b empty md file roundtrips as empty string, missing as null',
        () {
      final exercise = Exercise(
        uuid: 'ex-1',
        name: 'Ex',
        startTime: _start,
        endTime: _end,
        numberOfTeams: 1,
        numberOfRounds: 1,
        executionTime: 30,
        evaluationTime: 5,
        rotationTime: 5,
        stations: [
          const Station(
            index: 0,
            name: 'S0',
            equipmentMd: '', // empty -> zero-byte file
            situationMd: null, // null -> no file
          ),
        ],
        schedule: const [],
        methodMd: '', // empty
        learningGoalsMd: null, // null
      );

      final program = _emptyProgram().copyWith(
        briefIntroMd: '', // empty
        commsMd: null, // null
        exercises: [exercise],
      );

      final drillFile = DrillFile.fromProgram(program, 'test');
      final archiveRaw = ZipDecoder().decodeBytes(drillFile.content);
      final names =
          archiveRaw.files.where((f) => f.isFile).map((f) => f.name).toSet();

      // Empty-string fields produce zero-byte files.
      expect(names.contains('program/intro.md'), isTrue);
      expect(names.contains('exercises/ex-1/method.md'), isTrue);
      expect(names.contains('exercises/ex-1/stations/0/equipment.md'), isTrue);

      // Null fields produce no file.
      expect(names.contains('program/comms.md'), isFalse);
      expect(names.contains('exercises/ex-1/learning-goals.md'), isFalse);
      expect(names.contains('exercises/ex-1/stations/0/situation.md'), isFalse);

      final decoded = drillFile.program();
      expect(decoded.briefIntroMd, '');
      expect(decoded.commsMd, isNull);

      final ex = decoded.exercises.first;
      expect(ex.methodMd, '');
      expect(ex.learningGoalsMd, isNull);

      final s0 = ex.stations.first;
      expect(s0.equipmentMd, '');
      expect(s0.situationMd, isNull);
    });
  });

  group('Stage 1b content hash', () {
    test('includes new markdown fields', () {
      final base = _emptyProgram().copyWith(exercises: [_exercise()]);

      // briefIntroMd
      final h1 = base.computeContentHash();
      final h2 = base.copyWith(briefIntroMd: 'changed').computeContentHash();
      expect(h2, isNot(h1), reason: 'briefIntroMd must affect hash');

      // methodMd on exercise
      final h3 = base
          .copyWith(exercises: [_exercise().copyWith(methodMd: 'changed')])
          .computeContentHash();
      expect(h3, isNot(h1), reason: 'methodMd must affect hash');

      // equipmentMd on station
      final modStation = _station(0).copyWith(equipmentMd: 'changed');
      final modEx = _exercise().copyWith(
        stations: [modStation, _station(1)],
      );
      final h4 = base.copyWith(exercises: [modEx]).computeContentHash();
      expect(h4, isNot(h1), reason: 'equipmentMd must affect hash');

      // directorNotesMd on station
      final modStation2 = _station(0).copyWith(directorNotesMd: 'changed');
      final modEx2 = _exercise().copyWith(
        stations: [modStation2, _station(1)],
      );
      final h5 = base.copyWith(exercises: [modEx2]).computeContentHash();
      expect(h5, isNot(h1), reason: 'directorNotesMd must affect hash');

      // propsMd on rolePlay
      const rp = RolePlay(
        uuid: 'rp-1',
        index: 0,
        exerciseUuid: 'ex-1',
        name: 'Anna',
      );
      final withRp = base.copyWith(rolePlays: [rp]);
      final withRpProp = base.copyWith(
        rolePlays: [rp.copyWith(propsMd: 'props')],
      );
      expect(withRpProp.computeContentHash(), isNot(withRp.computeContentHash()),
          reason: 'propsMd must affect hash');

      // templateId and variantSuffix (structural, always in JSON)
      final withTemplate =
          base.copyWith(exercises: [_exercise(templateId: 'tmpl')]);
      expect(withTemplate.computeContentHash(), isNot(h1),
          reason: 'templateId must affect hash');

      final modVariant = _exercise().copyWith(
        stations: [_station(0).copyWith(variantSuffix: 'Alpha'), _station(1)],
      );
      final withVariant = base.copyWith(exercises: [modVariant]);
      expect(withVariant.computeContentHash(), isNot(h1),
          reason: 'variantSuffix must affect hash');
    });

    test(
        'Stage 1b content hash is deterministic across exercise/station order',
        () {
      final ex1 = Exercise(
        uuid: 'aaa-ex',
        name: 'A',
        startTime: _start,
        endTime: _end,
        numberOfTeams: 1,
        numberOfRounds: 1,
        executionTime: 30,
        evaluationTime: 5,
        rotationTime: 5,
        stations: [
          const Station(index: 0, name: 'S0', equipmentMd: 'eq0'),
          const Station(index: 1, name: 'S1', equipmentMd: 'eq1'),
        ],
        schedule: const [],
        methodMd: 'method-a',
      );
      final ex2 = Exercise(
        uuid: 'zzz-ex',
        name: 'Z',
        startTime: _start,
        endTime: _end,
        numberOfTeams: 1,
        numberOfRounds: 1,
        executionTime: 30,
        evaluationTime: 5,
        rotationTime: 5,
        stations: [
          const Station(index: 0, name: 'S0', situationMd: 'sit0'),
        ],
        schedule: const [],
        methodMd: 'method-z',
      );

      final programA = _emptyProgram().copyWith(exercises: [ex1, ex2]);
      final programB = _emptyProgram().copyWith(exercises: [ex2, ex1]);

      expect(programA.computeContentHash(), programB.computeContentHash(),
          reason: 'hash must be independent of exercise list order');
    });

    test('Stage 1b content hash is stable across save/load roundtrip', () {
      final program = _emptyProgram().copyWith(
        briefIntroMd: 'intro',
        commsMd: 'comms',
        exercises: [_exercise()],
        rolePlays: [_rolePlay],
        actors: [_actor],
      );

      final hashBefore = program.computeContentHash();
      final drillFile = DrillFile.fromProgram(program, 'test');
      final decoded = drillFile.program();
      final hashAfter = decoded.computeContentHash();

      expect(hashAfter, hashBefore,
          reason: 'hash must survive fromProgram -> program() roundtrip');
    });

    test('actor.notes still excluded from content hash', () {
      const actorA = Actor(uuid: 'a-1', realName: 'Alice', notes: 'note A');
      const actorB = Actor(uuid: 'a-1', realName: 'Alice', notes: 'note B');

      final programA = _emptyProgram().copyWith(actors: [actorA]);
      final programB = _emptyProgram().copyWith(actors: [actorB]);

      expect(programA.computeContentHash(), programB.computeContentHash(),
          reason: 'actor.notes must not affect the content hash (ADR-0018)');
    });
  });
}
