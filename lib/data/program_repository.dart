import 'dart:convert';

import 'package:nanoid/nanoid.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgramRepository {
  static const librarySchemaVersion = '1';

  final SharedPreferences _prefs;

  ProgramRepository(this._prefs);

  Future<void> init() async {
    if (_prefs.getString(AppConfig.keyLibrarySchema) == librarySchemaVersion) {
      return;
    }

    final keys = _prefs.getKeys();
    final legacyExerciseKeys = keys.where(_isLegacyExerciseKey).toList();
    final legacyTeamKeys = keys.where(_isLegacyTeamKey).toList();

    if (legacyExerciseKeys.isNotEmpty || legacyTeamKeys.isNotEmpty) {
      final programUuid = nanoid(10);
      for (final key in legacyExerciseKeys) {
        final uuid = key.substring(2);
        final value = _prefs.getString(key);
        if (value != null) {
          await _prefs.setString(_exerciseKey(programUuid, uuid), value);
        }
      }
      for (final key in legacyTeamKeys) {
        final uuid = key.substring(2);
        final value = _prefs.getString(key);
        if (value != null) {
          await _prefs.setString(_teamKey(programUuid, uuid), value);
        }
      }

      final now = DateTime.now();
      await saveProgramShell(
        Program(
          uuid: programUuid,
          name: 'Default plan',
          description: '',
          metadata: ProgramMetadata(created: now, updated: now, version: '1.0'),
          source: const ProgramSource.local(),
          teams: const [],
          sessions: const [],
          exercises: const [],
          rolePlays: const [],
          actors: const [],
        ),
      );
      await _prefs.setString(AppConfig.keyActiveProgram, programUuid);
      await _prefs.setBool(AppConfig.keyLibrarySchemaJustMigrated, true);

      for (final key in [...legacyExerciseKeys, ...legacyTeamKeys]) {
        await _prefs.remove(key);
      }
    }

    await _prefs.setString(AppConfig.keyLibrarySchema, librarySchemaVersion);
  }

  List<Program> listPrograms() {
    final programs = _prefs
        .getKeys()
        .where((key) => key.startsWith('p:'))
        .map((key) => _prefs.getString(key))
        .whereType<String>()
        .map((value) => Program.fromJson(jsonDecode(value)))
        .toList();
    programs.sort((a, b) => a.name.compareTo(b.name));
    return programs;
  }

  Program? loadProgram(String uuid) {
    final shell = _loadProgramShell(uuid);
    if (shell == null) return null;
    return shell.copyWith(
      exercises: loadExercises(uuid),
      teams: loadTeams(uuid),
      sessions: loadSessions(uuid),
      rolePlays: loadRolePlays(uuid),
      actors: loadActors(uuid),
    );
  }

  Future<void> saveProgramShell(Program program) async {
    final shell = program.copyWith(
      exercises: const [],
      teams: const [],
      sessions: const [],
      rolePlays: const [],
      actors: const [],
    );
    await _prefs.setString(
      _programKey(program.uuid),
      jsonEncode(shell.toJson()),
    );
  }

  Future<void> saveProgram(Program program) async {
    await saveProgramShell(program);
    await _replaceNested(
      program.uuid,
      exercises: program.exercises,
      teams: program.teams,
      sessions: program.sessions,
      rolePlays: program.rolePlays,
      actors: program.actors,
    );
  }

  Future<void> deleteProgram(String uuid) async {
    await _prefs.remove(_programKey(uuid));
    final keys = _prefs
        .getKeys()
        .where(
          (key) =>
              key.startsWith('pe:$uuid:') ||
              key.startsWith('pt:$uuid:') ||
              key.startsWith('ps:$uuid:') ||
              key.startsWith('pr:$uuid:') ||
              key.startsWith('pa:$uuid:'),
        )
        .toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
    if (activeProgramUuid == uuid) {
      await _prefs.remove(AppConfig.keyActiveProgram);
    }
  }

  String? get activeProgramUuid => _prefs.getString(AppConfig.keyActiveProgram);

  Future<void> setActiveProgramUuid(String uuid) async {
    if (!_prefs.containsKey(_programKey(uuid))) {
      throw StateError('Program "$uuid" does not exist.');
    }
    await _prefs.setString(AppConfig.keyActiveProgram, uuid);
  }

  List<Exercise> loadExercises([String? programUuid]) {
    final uuid = _requireProgramUuid(programUuid);
    final items = _prefs
        .getKeys()
        .where((key) => key.startsWith('pe:$uuid:'))
        .map((key) => _prefs.getString(key))
        .whereType<String>()
        .map((value) => Exercise.fromJson(jsonDecode(value)))
        .toList();
    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  Exercise? getExercise(String uuid, [String? programUuid]) {
    final programId = _requireProgramUuid(programUuid);
    final jsonString = _prefs.getString(_exerciseKey(programId, uuid));
    if (jsonString == null) return null;
    return Exercise.fromJson(jsonDecode(jsonString));
  }

  Future<void> addExercise(Exercise exercise, [bool replace = false]) async {
    if (!replace &&
        _prefs.containsKey(
          _exerciseKey(_requireProgramUuid(null), exercise.uuid),
        )) {
      throw Exception(
        'An exercise with the uuid "${exercise.uuid}" already exists.',
      );
    }
    await saveExercise(exercise);
  }

  Future<void> saveExercise(Exercise exercise, [String? programUuid]) async {
    final programId = _requireProgramUuid(programUuid);
    await _prefs.setString(
      _exerciseKey(programId, exercise.uuid),
      jsonEncode(exercise.toJson()),
    );
    await _touchProgram(programId);
  }

  Future<Exercise?> deleteExercise(String uuid, [String? programUuid]) async {
    final programId = _requireProgramUuid(programUuid);
    final deleted = getExercise(uuid, programId);
    if (deleted != null) {
      await _prefs.remove(_exerciseKey(programId, uuid));
      await _touchProgram(programId);
    }
    return deleted;
  }

  Future<List<Exercise>> deleteAllExercises([String? programUuid]) async {
    final programId = _requireProgramUuid(programUuid);
    final exercises = loadExercises(programId);
    for (final exercise in exercises) {
      await deleteExercise(exercise.uuid, programId);
    }
    return exercises;
  }

  List<Team> loadTeams([String? programUuid]) {
    final uuid = _requireProgramUuid(programUuid);
    final items = _prefs
        .getKeys()
        .where((key) => key.startsWith('pt:$uuid:'))
        .map((key) => _prefs.getString(key))
        .whereType<String>()
        .map((value) => Team.fromJson(jsonDecode(value)))
        .toList();
    items.sort((a, b) => a.index.compareTo(b.index));
    return items;
  }

  Team? getTeam(String uuid, [String? programUuid]) {
    final programId = _requireProgramUuid(programUuid);
    final jsonString = _prefs.getString(_teamKey(programId, uuid));
    if (jsonString == null) return null;
    return Team.fromJson(jsonDecode(jsonString));
  }

  Future<void> addTeam(Team team, [bool replace = false]) async {
    if (!replace &&
        _prefs.containsKey(_teamKey(_requireProgramUuid(null), team.uuid))) {
      throw Exception('An Team with the uuid "${team.uuid}" already exists.');
    }
    await saveTeam(team);
  }

  Future<void> saveTeam(Team team, [String? programUuid]) async {
    final programId = _requireProgramUuid(programUuid);
    await _prefs.setString(
      _teamKey(programId, team.uuid),
      jsonEncode(team.toJson()),
    );
    await _touchProgram(programId);
  }

  Future<Team?> deleteTeam(String uuid, [String? programUuid]) async {
    final programId = _requireProgramUuid(programUuid);
    final deleted = getTeam(uuid, programId);
    if (deleted != null) {
      await _prefs.remove(_teamKey(programId, uuid));
      await _touchProgram(programId);
    }
    return deleted;
  }

  Future<List<Team>> deleteAllTeams([String? programUuid]) async {
    final programId = _requireProgramUuid(programUuid);
    final teams = loadTeams(programId);
    for (final team in teams) {
      await deleteTeam(team.uuid, programId);
    }
    return teams;
  }

  bool containsTeam(String uuid, [String? programUuid]) {
    final programId = _requireProgramUuid(programUuid);
    return _prefs.containsKey(_teamKey(programId, uuid));
  }

  List<Session> loadSessions([String? programUuid]) {
    final uuid = _requireProgramUuid(programUuid);
    final items = _prefs
        .getKeys()
        .where((key) => key.startsWith('ps:$uuid:'))
        .map((key) => _prefs.getString(key))
        .whereType<String>()
        .map((value) => Session.fromJson(jsonDecode(value)))
        .toList();
    items.sort((a, b) => a.startTime.compareTo(b.startTime));
    return items;
  }

  Future<void> saveSession(Session session, [String? programUuid]) async {
    final programId = _requireProgramUuid(programUuid);
    await _prefs.setString(
      _sessionKey(programId, session.uuid),
      jsonEncode(session.toJson()),
    );
    await _touchProgram(programId);
  }

  Future<Session?> deleteSession(String uuid, [String? programUuid]) async {
    final programId = _requireProgramUuid(programUuid);
    final jsonString = _prefs.getString(_sessionKey(programId, uuid));
    if (jsonString == null) return null;
    await _prefs.remove(_sessionKey(programId, uuid));
    await _touchProgram(programId);
    return Session.fromJson(jsonDecode(jsonString));
  }

  bool get librarySchemaJustMigrated =>
      _prefs.getBool(AppConfig.keyLibrarySchemaJustMigrated) ?? false;

  Future<void> clearLibrarySchemaJustMigrated() =>
      _prefs.remove(AppConfig.keyLibrarySchemaJustMigrated);

  bool ownsCatalogSlug(String slug) =>
      _prefs.getBool(AppConfig.catalogOwnershipKey(slug)) ?? false;

  Future<void> setOwnsCatalogSlug(String slug, bool value) =>
      _prefs.setBool(AppConfig.catalogOwnershipKey(slug), value);

  Program? _loadProgramShell(String uuid) {
    final jsonString = _prefs.getString(_programKey(uuid));
    if (jsonString == null) return null;
    return Program.fromJson(jsonDecode(jsonString));
  }

  Future<void> _replaceNested(
    String programUuid, {
    required List<Exercise> exercises,
    required List<Team> teams,
    required List<Session> sessions,
    required List<RolePlay> rolePlays,
    required List<Actor> actors,
  }) async {
    final keys = _prefs
        .getKeys()
        .where(
          (key) =>
              key.startsWith('pe:$programUuid:') ||
              key.startsWith('pt:$programUuid:') ||
              key.startsWith('ps:$programUuid:') ||
              key.startsWith('pr:$programUuid:') ||
              key.startsWith('pa:$programUuid:'),
        )
        .toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
    for (final exercise in exercises) {
      await _prefs.setString(
        _exerciseKey(programUuid, exercise.uuid),
        jsonEncode(exercise.toJson()),
      );
    }
    for (final team in teams) {
      await _prefs.setString(
        _teamKey(programUuid, team.uuid),
        jsonEncode(team.toJson()),
      );
    }
    for (final session in sessions) {
      await _prefs.setString(
        _sessionKey(programUuid, session.uuid),
        jsonEncode(session.toJson()),
      );
    }
    for (final rolePlay in rolePlays) {
      await _prefs.setString(
        _rolePlayKey(programUuid, rolePlay.uuid),
        jsonEncode(rolePlay.toJson()),
      );
    }
    for (final actor in actors) {
      await _prefs.setString(
        _actorKey(programUuid, actor.uuid),
        jsonEncode(actor.toJson()),
      );
    }
  }

  Future<void> _touchProgram(String programUuid) async {
    final shell = _loadProgramShell(programUuid);
    if (shell == null) return;
    await saveProgramShell(
      shell.copyWith(
        metadata: shell.metadata.copyWith(updated: DateTime.now()),
      ),
    );
  }

  String _requireProgramUuid(String? uuid) {
    final resolved = uuid ?? activeProgramUuid;
    if (resolved == null) {
      throw StateError('No active program.');
    }
    return resolved;
  }

  static bool _isLegacyExerciseKey(String key) =>
      key.startsWith('e:') && key.split(':').length == 2;

  static bool _isLegacyTeamKey(String key) =>
      key.startsWith('t:') && key.split(':').length == 2;

  List<RolePlay> loadRolePlays([String? programUuid]) {
    final uuid = _requireProgramUuid(programUuid);
    return _prefs
        .getKeys()
        .where((key) => key.startsWith('pr:$uuid:'))
        .map((key) => _prefs.getString(key))
        .whereType<String>()
        .map((value) => RolePlay.fromJson(jsonDecode(value)))
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));
  }

  RolePlay? getRolePlay(String uuid, [String? programUuid]) {
    final programId = _requireProgramUuid(programUuid);
    final jsonString = _prefs.getString(_rolePlayKey(programId, uuid));
    if (jsonString == null) return null;
    return RolePlay.fromJson(jsonDecode(jsonString));
  }

  Future<void> saveRolePlay(RolePlay rolePlay, [String? programUuid]) async {
    final programId = _requireProgramUuid(programUuid);
    await _prefs.setString(
      _rolePlayKey(programId, rolePlay.uuid),
      jsonEncode(rolePlay.toJson()),
    );
    await _touchProgram(programId);
  }

  Future<RolePlay?> deleteRolePlay(
    String uuid, [
    String? programUuid,
  ]) async {
    final programId = _requireProgramUuid(programUuid);
    final deleted = getRolePlay(uuid, programId);
    if (deleted != null) {
      await _prefs.remove(_rolePlayKey(programId, uuid));
      await _touchProgram(programId);
    }
    return deleted;
  }

  List<Actor> loadActors([String? programUuid]) {
    final uuid = _requireProgramUuid(programUuid);
    return _prefs
        .getKeys()
        .where((key) => key.startsWith('pa:$uuid:'))
        .map((key) => _prefs.getString(key))
        .whereType<String>()
        .map((value) => Actor.fromJson(jsonDecode(value)))
        .toList()
      ..sort((a, b) => a.realName.compareTo(b.realName));
  }

  Actor? getActor(String uuid, [String? programUuid]) {
    final programId = _requireProgramUuid(programUuid);
    final jsonString = _prefs.getString(_actorKey(programId, uuid));
    if (jsonString == null) return null;
    return Actor.fromJson(jsonDecode(jsonString));
  }

  Future<void> saveActor(Actor actor, [String? programUuid]) async {
    final programId = _requireProgramUuid(programUuid);
    await _prefs.setString(
      _actorKey(programId, actor.uuid),
      jsonEncode(actor.toJson()),
    );
    await _touchProgram(programId);
  }

  Future<Actor?> deleteActor(String uuid, [String? programUuid]) async {
    final programId = _requireProgramUuid(programUuid);
    final deleted = getActor(uuid, programId);
    if (deleted != null) {
      await _prefs.remove(_actorKey(programId, uuid));
      await _touchProgram(programId);
    }
    return deleted;
  }

  String _programKey(String uuid) => 'p:$uuid';
  String _exerciseKey(String programUuid, String uuid) =>
      'pe:$programUuid:$uuid';
  String _teamKey(String programUuid, String uuid) => 'pt:$programUuid:$uuid';
  String _sessionKey(String programUuid, String uuid) =>
      'ps:$programUuid:$uuid';
  String _rolePlayKey(String programUuid, String uuid) =>
      'pr:$programUuid:$uuid';
  String _actorKey(String programUuid, String uuid) => 'pa:$programUuid:$uuid';
}
