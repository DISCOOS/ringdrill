import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nanoid/nanoid.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Best-effort JSON decode + map. Returns `null` (and logs/reports) instead
/// of throwing when a stored entry can't be parsed. Used by every load*
/// method below so that a single corrupt entry in SharedPreferences cannot
/// take down `main()` and leave the web splash screen hanging — which was
/// the failure mode users hit when bad data (e.g. a station with NaN
/// coordinates) made it into storage.
T? _tryParseEntry<T>(
  String key,
  String value,
  T Function(Map<String, dynamic>) parse,
) {
  try {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) return null;
    return parse(decoded);
  } catch (e, st) {
    debugPrint('ProgramRepository: skipping corrupt entry "$key": $e');
    // Sentry may not be initialised yet during boot. Its global
    // captureException is a safe no-op in that case, so calling it
    // unconditionally is fine.
    unawaited(Sentry.captureException(e, stackTrace: st));
    return null;
  }
}

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
    final programs = <Program>[];
    for (final key in _prefs.getKeys().where((k) => k.startsWith('p:'))) {
      final value = _prefs.getString(key);
      if (value == null) continue;
      final parsed = _tryParseEntry(key, value, Program.fromJson);
      if (parsed != null) programs.add(parsed);
    }
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
    final items = <Exercise>[];
    for (final key in _prefs.getKeys().where((k) => k.startsWith('pe:$uuid:'))) {
      final value = _prefs.getString(key);
      if (value == null) continue;
      final parsed = _tryParseEntry(key, value, Exercise.fromJson);
      if (parsed != null) items.add(parsed);
    }
    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  Exercise? getExercise(String uuid, [String? programUuid]) {
    final programId = _requireProgramUuid(programUuid);
    final key = _exerciseKey(programId, uuid);
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return null;
    return _tryParseEntry(key, jsonString, Exercise.fromJson);
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
    final items = <Team>[];
    for (final key in _prefs.getKeys().where((k) => k.startsWith('pt:$uuid:'))) {
      final value = _prefs.getString(key);
      if (value == null) continue;
      final parsed = _tryParseEntry(key, value, Team.fromJson);
      if (parsed != null) items.add(parsed);
    }
    items.sort((a, b) => a.index.compareTo(b.index));
    return items;
  }

  Team? getTeam(String uuid, [String? programUuid]) {
    final programId = _requireProgramUuid(programUuid);
    final key = _teamKey(programId, uuid);
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return null;
    return _tryParseEntry(key, jsonString, Team.fromJson);
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
    final items = <Session>[];
    for (final key in _prefs.getKeys().where((k) => k.startsWith('ps:$uuid:'))) {
      final value = _prefs.getString(key);
      if (value == null) continue;
      final parsed = _tryParseEntry(key, value, Session.fromJson);
      if (parsed != null) items.add(parsed);
    }
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
    final key = _sessionKey(programId, uuid);
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return null;
    await _prefs.remove(key);
    await _touchProgram(programId);
    return _tryParseEntry(key, jsonString, Session.fromJson);
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
    final key = _programKey(uuid);
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return null;
    return _tryParseEntry(key, jsonString, Program.fromJson);
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
              key.startsWith('pa:$programUuid:') ||
              key.startsWith('pan:$programUuid:'),
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
      // Actor.notes is excluded from JSON (ADR-0022) — store separately.
      final notesKey = _actorNotesKey(programUuid, actor.uuid);
      if (actor.notes != null) {
        await _prefs.setString(notesKey, actor.notes!);
      }
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
    final items = <RolePlay>[];
    for (final key in _prefs.getKeys().where((k) => k.startsWith('pr:$uuid:'))) {
      final value = _prefs.getString(key);
      if (value == null) continue;
      final parsed = _tryParseEntry(key, value, RolePlay.fromJson);
      if (parsed != null) items.add(parsed);
    }
    items.sort((a, b) => a.index.compareTo(b.index));
    return items;
  }

  RolePlay? getRolePlay(String uuid, [String? programUuid]) {
    final programId = _requireProgramUuid(programUuid);
    final key = _rolePlayKey(programId, uuid);
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return null;
    return _tryParseEntry(key, jsonString, RolePlay.fromJson);
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
    final items = <Actor>[];
    for (final key in _prefs.getKeys().where((k) => k.startsWith('pa:$uuid:'))) {
      final value = _prefs.getString(key);
      if (value == null) continue;
      var parsed = _tryParseEntry(key, value, Actor.fromJson);
      if (parsed == null) continue;
      // Actor.notes is excluded from JSON (ADR-0022); restore from separate key.
      final notes = _prefs.getString(_actorNotesKey(uuid, parsed.uuid));
      if (notes != null) parsed = parsed.copyWith(notes: notes);
      items.add(parsed);
    }
    items.sort((a, b) => a.realName.compareTo(b.realName));
    return items;
  }

  Actor? getActor(String uuid, [String? programUuid]) {
    final programId = _requireProgramUuid(programUuid);
    final key = _actorKey(programId, uuid);
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return null;
    var actor = _tryParseEntry(key, jsonString, Actor.fromJson);
    if (actor == null) return null;
    // Actor.notes is excluded from JSON (ADR-0022); restore from separate key.
    final notes = _prefs.getString(_actorNotesKey(programId, uuid));
    if (notes != null) actor = actor.copyWith(notes: notes);
    return actor;
  }

  Future<void> saveActor(Actor actor, [String? programUuid]) async {
    final programId = _requireProgramUuid(programUuid);
    await _prefs.setString(
      _actorKey(programId, actor.uuid),
      jsonEncode(actor.toJson()),
    );
    // Actor.notes is excluded from JSON (ADR-0022) — store separately.
    final notesKey = _actorNotesKey(programId, actor.uuid);
    if (actor.notes != null) {
      await _prefs.setString(notesKey, actor.notes!);
    } else {
      await _prefs.remove(notesKey);
    }
    await _touchProgram(programId);
  }

  Future<Actor?> deleteActor(String uuid, [String? programUuid]) async {
    final programId = _requireProgramUuid(programUuid);
    final deleted = getActor(uuid, programId);
    if (deleted != null) {
      await _prefs.remove(_actorKey(programId, uuid));
      await _prefs.remove(_actorNotesKey(programId, uuid));
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
  // Actor.notes is excluded from JSON manifests (ADR-0022); stored under pan:.
  String _actorNotesKey(String programUuid, String uuid) =>
      'pan:$programUuid:$uuid';
}
