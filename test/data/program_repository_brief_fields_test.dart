import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/program_repository.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Regression coverage for the brief-markdown save bug: the *Md fields are
// excluded from JSON (ADR-0022) so the in-app SharedPreferences path used to
// drop them silently. The repository now persists them in parallel sidecar
// keys; these tests assert they survive a save → reload round-trip.

const _programUuid = 'prog-1';

Program _shell({
  String? briefIntroMd,
  String? commsMd,
  String? beforeRoundMd,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return Program(
    uuid: _programUuid,
    name: 'Plan',
    description: '',
    metadata: ProgramMetadata(created: now, updated: now, version: '1.0'),
    teams: const [],
    sessions: const [],
    exercises: const [],
    briefIntroMd: briefIntroMd,
    commsMd: commsMd,
    beforeRoundMd: beforeRoundMd,
  );
}

Exercise _exercise({
  String uuid = 'ex-1',
  List<Station> stations = const [Station(index: 0, name: 'Post 1')],
  String? methodMd,
  String? learningGoalsMd,
  String? commsMd,
}) => Exercise(
  uuid: uuid,
  index: 0,
  name: 'Områdeøvelse Lier',
  startTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 15,
  evaluationTime: 5,
  rotationTime: 2,
  stations: stations,
  schedule: const [
    [
      SimpleTimeOfDay(hour: 9, minute: 0),
      SimpleTimeOfDay(hour: 9, minute: 15),
      SimpleTimeOfDay(hour: 9, minute: 20),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 9, minute: 22),
  methodMd: methodMd,
  learningGoalsMd: learningGoalsMd,
  commsMd: commsMd,
);

Future<ProgramRepository> _repo() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = ProgramRepository(prefs);
  await repo.saveProgramShell(_shell());
  await repo.setActiveProgramUuid(_programUuid);
  return repo;
}

void main() {
  group('Exercise brief fields survive a repository round-trip', () {
    test('exercise-level markdown is restored on getExercise and load', () async {
      final repo = await _repo();
      await repo.saveExercise(
        _exercise(
          methodMd: 'Metode-tekst',
          learningGoalsMd: 'Læringsmål-tekst',
          commsMd: 'Samband-tekst',
        ),
      );

      final fetched = repo.getExercise('ex-1');
      expect(fetched, isNotNull);
      expect(fetched!.methodMd, 'Metode-tekst');
      expect(fetched.learningGoalsMd, 'Læringsmål-tekst');
      expect(fetched.commsMd, 'Samband-tekst');

      final loaded = repo.loadExercises().single;
      expect(loaded.methodMd, 'Metode-tekst');
      expect(loaded.learningGoalsMd, 'Læringsmål-tekst');
      expect(loaded.commsMd, 'Samband-tekst');
    });

    test('nested station markdown is restored', () async {
      final repo = await _repo();
      await repo.saveExercise(
        _exercise(
          stations: const [
            Station(
              index: 0,
              name: 'Post 1',
              situationMd: 'Situasjon',
              missionMd: 'Oppdrag',
              directorNotesMd: 'Notat',
            ),
            Station(index: 1, name: 'Post 2'),
          ],
        ),
      );

      final station = repo.getExercise('ex-1')!.stations.first;
      expect(station.situationMd, 'Situasjon');
      expect(station.missionMd, 'Oppdrag');
      expect(station.directorNotesMd, 'Notat');
      // The station without markdown stays clean.
      expect(repo.getExercise('ex-1')!.stations[1].situationMd, isNull);
    });

    test('clearing a field removes it on the next save', () async {
      final repo = await _repo();
      await repo.saveExercise(_exercise(commsMd: 'Samband-tekst'));
      expect(repo.getExercise('ex-1')!.commsMd, 'Samband-tekst');

      await repo.saveExercise(_exercise(commsMd: null));
      expect(repo.getExercise('ex-1')!.commsMd, isNull);
    });
  });

  test('RolePlay brief fields survive a round-trip', () async {
    final repo = await _repo();
    await repo.saveRolePlay(
      const RolePlay(
        uuid: 'rp-1',
        index: 0,
        exerciseUuid: 'ex-1',
        name: 'Skadd',
        background: 'Bakgrunn',
        behavior: 'Oppførsel',
        propsMd: 'Rekvisitter',
      ),
    );

    final fetched = repo.getRolePlay('rp-1');
    expect(fetched!.background, 'Bakgrunn');
    expect(fetched.behavior, 'Oppførsel');
    expect(fetched.propsMd, 'Rekvisitter');
    expect(repo.loadRolePlays().single.background, 'Bakgrunn');
  });

  test('Program brief fields survive a round-trip', () async {
    final repo = await _repo();
    await repo.saveProgramShell(
      _shell(
        briefIntroMd: 'Intro',
        commsMd: 'Talegrupper',
        beforeRoundMd: 'Før runde',
      ),
    );

    final program = repo.loadProgram(_programUuid);
    expect(program!.briefIntroMd, 'Intro');
    expect(program.commsMd, 'Talegrupper');
    expect(program.beforeRoundMd, 'Før runde');
  });

  test('saveProgram round-trips nested exercise + roleplay markdown', () async {
    final repo = await _repo();
    final program = _shell(briefIntroMd: 'Intro').copyWith(
      exercises: [
        _exercise(methodMd: 'Metode'),
      ],
      rolePlays: const [
        RolePlay(
          uuid: 'rp-1',
          index: 0,
          exerciseUuid: 'ex-1',
          name: 'Skadd',
          behavior: 'Oppførsel',
        ),
      ],
    );
    await repo.saveProgram(program);

    final loaded = repo.loadProgram(_programUuid)!;
    expect(loaded.briefIntroMd, 'Intro');
    expect(loaded.exercises.single.methodMd, 'Metode');
    expect(loaded.rolePlays.single.behavior, 'Oppførsel');
  });
}
