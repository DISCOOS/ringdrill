import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nanoid/nanoid.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
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
    debugPrint('PlanRepository: skipping corrupt entry "$key": $e');
    // Sentry may not be initialised yet during boot. Its global
    // captureException is a safe no-op in that case, so calling it
    // unconditionally is fine.
    unawaited(Sentry.captureException(e, stackTrace: st));
    return null;
  }
}

class PlanRepository {
  static const librarySchemaVersion = '1';

  final SharedPreferences _prefs;

  PlanRepository(this._prefs);

  Future<void> init() async {
    if (_prefs.getString(AppConfig.keyLibrarySchema) == librarySchemaVersion) {
      return;
    }

    final keys = _prefs.getKeys();
    final legacyExerciseKeys = keys.where(_isLegacyExerciseKey).toList();
    final legacyTeamKeys = keys.where(_isLegacyTeamKey).toList();

    if (legacyExerciseKeys.isNotEmpty || legacyTeamKeys.isNotEmpty) {
      final planUuid = nanoid(10);
      for (final key in legacyExerciseKeys) {
        final uuid = key.substring(2);
        final value = _prefs.getString(key);
        if (value != null) {
          await _prefs.setString(_exerciseKey(planUuid, uuid), value);
        }
      }
      for (final key in legacyTeamKeys) {
        final uuid = key.substring(2);
        final value = _prefs.getString(key);
        if (value != null) {
          await _prefs.setString(_teamKey(planUuid, uuid), value);
        }
      }

      final now = DateTime.now();
      await savePlanShell(
        Plan(
          uuid: planUuid,
          name: 'Default plan',
          description: '',
          metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
          source: const PlanSource.local(),
          teams: const [],
          sessions: const [],
          exercises: const [],
          rolePlays: const [],
          actors: const [],
        ),
      );
      await _prefs.setString(AppConfig.keyActivePlan, planUuid);
      await _prefs.setBool(AppConfig.keyLibrarySchemaJustMigrated, true);

      for (final key in [...legacyExerciseKeys, ...legacyTeamKeys]) {
        await _prefs.remove(key);
      }
    }

    await _prefs.setString(AppConfig.keyLibrarySchema, librarySchemaVersion);
  }

  List<Plan> listPlans() {
    final plans = <Plan>[];
    for (final key in _prefs.getKeys().where((k) => k.startsWith('p:'))) {
      final value = _prefs.getString(key);
      if (value == null) continue;
      final parsed = _tryParseEntry(key, value, Plan.fromJson);
      if (parsed != null) plans.add(parsed);
    }
    plans.sort((p, q) => p.name.compareTo(q.name));
    return plans;
  }

  Plan? loadPlan(String uuid) {
    final shell = _loadPlanShell(uuid);
    if (shell == null) return null;
    return shell.copyWith(
      exercises: loadExercises(uuid),
      teams: loadTeams(uuid),
      sessions: loadSessions(uuid),
      rolePlays: loadRolePlays(uuid),
      actors: loadActors(uuid),
    );
  }

  Future<void> savePlanShell(Plan plan) async {
    final shell = plan.copyWith(
      exercises: const [],
      teams: const [],
      sessions: const [],
      rolePlays: const [],
      actors: const [],
    );
    await _prefs.setString(_planKey(plan.uuid), jsonEncode(shell.toJson()));
    await _writePlanBrief(plan);
  }

  Future<void> savePlan(Plan plan) async {
    await savePlanShell(plan);
    await _replaceNested(
      plan.uuid,
      exercises: plan.exercises,
      teams: plan.teams,
      sessions: plan.sessions,
      rolePlays: plan.rolePlays,
      actors: plan.actors,
    );
  }

  Future<void> deletePlan(String uuid) async {
    await _prefs.remove(_planKey(uuid));
    await _prefs.remove(_planBriefKey(uuid));
    final keys = _prefs
        .getKeys()
        .where(
          (key) =>
              key.startsWith('pe:$uuid:') ||
              key.startsWith('pem:$uuid:') ||
              key.startsWith('pt:$uuid:') ||
              key.startsWith('ps:$uuid:') ||
              key.startsWith('pr:$uuid:') ||
              key.startsWith('prm:$uuid:') ||
              key.startsWith('pa:$uuid:') ||
              key.startsWith('pan:$uuid:'),
        )
        .toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
    if (activePlanUuid == uuid) {
      await _prefs.remove(AppConfig.keyActivePlan);
    }
  }

  String? get activePlanUuid => _prefs.getString(AppConfig.keyActivePlan);

  Future<void> setActivePlanUuid(String uuid) async {
    if (!_prefs.containsKey(_planKey(uuid))) {
      throw StateError('Plan "$uuid" does not exist.');
    }
    await _prefs.setString(AppConfig.keyActivePlan, uuid);
  }

  List<Exercise> loadExercises([String? planUuid]) {
    final uuid = _requirePlanUuid(planUuid);
    final items = <Exercise>[];
    for (final key in _prefs.getKeys().where(
      (k) => k.startsWith('pe:$uuid:'),
    )) {
      final value = _prefs.getString(key);
      if (value == null) continue;
      final parsed = _tryParseEntry(key, value, Exercise.fromJson);
      if (parsed != null) items.add(_applyExerciseBrief(uuid, parsed));
    }
    return _normaliseExerciseOrder(items);
  }

  /// Sort [items] by their [Exercise.index] when the indices form a valid
  /// dense permutation (0..n-1). When they do not — the common case for plans
  /// created before ADR-0035 where every exercise defaults to 0 — fall back to
  /// the old alphabetical sort and reassign 0..n-1 in that order. This
  /// deterministic migration reproduces the pre-ADR-0035 visible order exactly.
  ///
  /// A single-exercise list is always valid: one item at index 0 is already a
  /// valid permutation.
  @visibleForTesting
  static List<Exercise> normaliseExerciseOrderForTest(List<Exercise> items) =>
      _normaliseExerciseOrder(items);

  static List<Exercise> _normaliseExerciseOrder(List<Exercise> items) {
    if (items.isEmpty) return items;
    final indices = items.map((e) => e.index).toSet();
    final n = items.length;
    // Valid permutation: exactly the set {0, 1, …, n-1}.
    final isValid =
        indices.length == n && indices.every((i) => i >= 0 && i < n);
    if (isValid) {
      return [...items]..sort((a, b) => a.index.compareTo(b.index));
    }
    // Migration path: sort by name (legacy behaviour) and renumber 0..n-1.
    final sorted = [...items]..sort((x, y) => x.name.compareTo(y.name));
    return [
      for (var i = 0; i < sorted.length; i++) sorted[i].copyWith(index: i),
    ];
  }

  Exercise? getExercise(String uuid, [String? planUuid]) {
    final planId = _requirePlanUuid(planUuid);
    final key = _exerciseKey(planId, uuid);
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return null;
    final parsed = _tryParseEntry(key, jsonString, Exercise.fromJson);
    if (parsed == null) return null;
    return _applyExerciseBrief(planId, parsed);
  }

  Future<void> addExercise(Exercise exercise, [bool replace = false]) async {
    if (!replace &&
        _prefs.containsKey(
          _exerciseKey(_requirePlanUuid(null), exercise.uuid),
        )) {
      throw Exception(
        'An exercise with the uuid "${exercise.uuid}" already exists.',
      );
    }
    await saveExercise(exercise);
  }

  Future<void> saveExercise(Exercise exercise, [String? planUuid]) async {
    final planId = _requirePlanUuid(planUuid);
    await _prefs.setString(
      _exerciseKey(planId, exercise.uuid),
      jsonEncode(exercise.toJson()),
    );
    await _writeExerciseBrief(planId, exercise);
    await _touchPlan(planId);
  }

  Future<Exercise?> deleteExercise(String uuid, [String? planUuid]) async {
    final planId = _requirePlanUuid(planUuid);
    final deleted = getExercise(uuid, planId);
    if (deleted != null) {
      await _prefs.remove(_exerciseKey(planId, uuid));
      await _prefs.remove(_exerciseBriefKey(planId, uuid));
      await _touchPlan(planId);
    }
    return deleted;
  }

  Future<List<Exercise>> deleteAllExercises([String? planUuid]) async {
    final planId = _requirePlanUuid(planUuid);
    final exercises = loadExercises(planId);
    for (final exercise in exercises) {
      await deleteExercise(exercise.uuid, planId);
    }
    return exercises;
  }

  List<Team> loadTeams([String? planUuid]) {
    final uuid = _requirePlanUuid(planUuid);
    final items = <Team>[];
    for (final key in _prefs.getKeys().where(
      (k) => k.startsWith('pt:$uuid:'),
    )) {
      final value = _prefs.getString(key);
      if (value == null) continue;
      final parsed = _tryParseEntry(key, value, Team.fromJson);
      if (parsed != null) items.add(parsed);
    }
    items.sort((a, b) => a.index.compareTo(b.index));
    return items;
  }

  Team? getTeam(String uuid, [String? planUuid]) {
    final planId = _requirePlanUuid(planUuid);
    final key = _teamKey(planId, uuid);
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return null;
    return _tryParseEntry(key, jsonString, Team.fromJson);
  }

  Future<void> addTeam(Team team, [bool replace = false]) async {
    if (!replace &&
        _prefs.containsKey(_teamKey(_requirePlanUuid(null), team.uuid))) {
      throw Exception('An Team with the uuid "${team.uuid}" already exists.');
    }
    await saveTeam(team);
  }

  Future<void> saveTeam(Team team, [String? planUuid]) async {
    final planId = _requirePlanUuid(planUuid);
    await _prefs.setString(
      _teamKey(planId, team.uuid),
      jsonEncode(team.toJson()),
    );
    await _touchPlan(planId);
  }

  Future<Team?> deleteTeam(String uuid, [String? planUuid]) async {
    final planId = _requirePlanUuid(planUuid);
    final deleted = getTeam(uuid, planId);
    if (deleted != null) {
      await _prefs.remove(_teamKey(planId, uuid));
      await _touchPlan(planId);
    }
    return deleted;
  }

  Future<List<Team>> deleteAllTeams([String? planUuid]) async {
    final planId = _requirePlanUuid(planUuid);
    final teams = loadTeams(planId);
    for (final team in teams) {
      await deleteTeam(team.uuid, planId);
    }
    return teams;
  }

  bool containsTeam(String uuid, [String? planUuid]) {
    final planId = _requirePlanUuid(planUuid);
    return _prefs.containsKey(_teamKey(planId, uuid));
  }

  List<Session> loadSessions([String? planUuid]) {
    final uuid = _requirePlanUuid(planUuid);
    final items = <Session>[];
    for (final key in _prefs.getKeys().where(
      (k) => k.startsWith('ps:$uuid:'),
    )) {
      final value = _prefs.getString(key);
      if (value == null) continue;
      final parsed = _tryParseEntry(key, value, Session.fromJson);
      if (parsed != null) items.add(parsed);
    }
    items.sort((a, b) => a.startTime.compareTo(b.startTime));
    return items;
  }

  Future<void> saveSession(Session session, [String? planUuid]) async {
    final planId = _requirePlanUuid(planUuid);
    await _prefs.setString(
      _sessionKey(planId, session.uuid),
      jsonEncode(session.toJson()),
    );
    await _touchPlan(planId);
  }

  Future<Session?> deleteSession(String uuid, [String? planUuid]) async {
    final planId = _requirePlanUuid(planUuid);
    final key = _sessionKey(planId, uuid);
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return null;
    await _prefs.remove(key);
    await _touchPlan(planId);
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

  Plan? _loadPlanShell(String uuid) {
    final key = _planKey(uuid);
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return null;
    final parsed = _tryParseEntry(key, jsonString, Plan.fromJson);
    if (parsed == null) return null;
    return _applyPlanBrief(parsed);
  }

  Future<void> _replaceNested(
    String planUuid, {
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
              key.startsWith('pe:$planUuid:') ||
              key.startsWith('pem:$planUuid:') ||
              key.startsWith('pt:$planUuid:') ||
              key.startsWith('ps:$planUuid:') ||
              key.startsWith('pr:$planUuid:') ||
              key.startsWith('prm:$planUuid:') ||
              key.startsWith('pa:$planUuid:') ||
              key.startsWith('pan:$planUuid:'),
        )
        .toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
    for (final exercise in exercises) {
      await _prefs.setString(
        _exerciseKey(planUuid, exercise.uuid),
        jsonEncode(exercise.toJson()),
      );
      await _writeExerciseBrief(planUuid, exercise);
    }
    for (final team in teams) {
      await _prefs.setString(
        _teamKey(planUuid, team.uuid),
        jsonEncode(team.toJson()),
      );
    }
    for (final session in sessions) {
      await _prefs.setString(
        _sessionKey(planUuid, session.uuid),
        jsonEncode(session.toJson()),
      );
    }
    for (final rolePlay in rolePlays) {
      await _prefs.setString(
        _rolePlayKey(planUuid, rolePlay.uuid),
        jsonEncode(rolePlay.toJson()),
      );
      await _writeRolePlayBrief(planUuid, rolePlay);
    }
    for (final actor in actors) {
      await _prefs.setString(
        _actorKey(planUuid, actor.uuid),
        jsonEncode(actor.toJson()),
      );
      // Actor.notes is excluded from JSON (ADR-0022) — store separately.
      final notesKey = _actorNotesKey(planUuid, actor.uuid);
      if (actor.notes != null) {
        await _prefs.setString(notesKey, actor.notes!);
      }
    }
  }

  Future<void> _touchPlan(String planUuid) async {
    final shell = _loadPlanShell(planUuid);
    if (shell == null) return;
    await savePlanShell(
      shell.copyWith(
        metadata: shell.metadata.copyWith(updated: DateTime.now()),
      ),
    );
  }

  String _requirePlanUuid(String? uuid) {
    final resolved = uuid ?? activePlanUuid;
    if (resolved == null) {
      throw StateError('No active plan.');
    }
    return resolved;
  }

  static bool _isLegacyExerciseKey(String key) =>
      key.startsWith('e:') && key.split(':').length == 2;

  static bool _isLegacyTeamKey(String key) =>
      key.startsWith('t:') && key.split(':').length == 2;

  List<RolePlay> loadRolePlays([String? planUuid]) {
    final uuid = _requirePlanUuid(planUuid);
    final items = <RolePlay>[];
    for (final key in _prefs.getKeys().where(
      (k) => k.startsWith('pr:$uuid:'),
    )) {
      final value = _prefs.getString(key);
      if (value == null) continue;
      final parsed = _tryParseEntry(key, value, RolePlay.fromJson);
      if (parsed != null) items.add(_applyRolePlayBrief(uuid, parsed));
    }
    items.sort((a, b) => a.index.compareTo(b.index));
    return items;
  }

  RolePlay? getRolePlay(String uuid, [String? planUuid]) {
    final planId = _requirePlanUuid(planUuid);
    final key = _rolePlayKey(planId, uuid);
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return null;
    final parsed = _tryParseEntry(key, jsonString, RolePlay.fromJson);
    if (parsed == null) return null;
    return _applyRolePlayBrief(planId, parsed);
  }

  Future<void> saveRolePlay(RolePlay rolePlay, [String? planUuid]) async {
    final planId = _requirePlanUuid(planUuid);
    await _prefs.setString(
      _rolePlayKey(planId, rolePlay.uuid),
      jsonEncode(rolePlay.toJson()),
    );
    await _writeRolePlayBrief(planId, rolePlay);
    await _touchPlan(planId);
  }

  Future<RolePlay?> deleteRolePlay(String uuid, [String? planUuid]) async {
    final planId = _requirePlanUuid(planUuid);
    final deleted = getRolePlay(uuid, planId);
    if (deleted != null) {
      await _prefs.remove(_rolePlayKey(planId, uuid));
      await _prefs.remove(_rolePlayBriefKey(planId, uuid));
      await _touchPlan(planId);
    }
    return deleted;
  }

  List<Actor> loadActors([String? planUuid]) {
    final uuid = _requirePlanUuid(planUuid);
    final items = <Actor>[];
    for (final key in _prefs.getKeys().where(
      (k) => k.startsWith('pa:$uuid:'),
    )) {
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

  Actor? getActor(String uuid, [String? planUuid]) {
    final planId = _requirePlanUuid(planUuid);
    final key = _actorKey(planId, uuid);
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return null;
    var actor = _tryParseEntry(key, jsonString, Actor.fromJson);
    if (actor == null) return null;
    // Actor.notes is excluded from JSON (ADR-0022); restore from separate key.
    final notes = _prefs.getString(_actorNotesKey(planId, uuid));
    if (notes != null) actor = actor.copyWith(notes: notes);
    return actor;
  }

  Future<void> saveActor(Actor actor, [String? planUuid]) async {
    final planId = _requirePlanUuid(planUuid);
    await _prefs.setString(
      _actorKey(planId, actor.uuid),
      jsonEncode(actor.toJson()),
    );
    // Actor.notes is excluded from JSON (ADR-0022) — store separately.
    final notesKey = _actorNotesKey(planId, actor.uuid);
    if (actor.notes != null) {
      await _prefs.setString(notesKey, actor.notes!);
    } else {
      await _prefs.remove(notesKey);
    }
    await _touchPlan(planId);
  }

  Future<Actor?> deleteActor(String uuid, [String? planUuid]) async {
    final planId = _requirePlanUuid(planUuid);
    final deleted = getActor(uuid, planId);
    if (deleted != null) {
      await _prefs.remove(_actorKey(planId, uuid));
      await _prefs.remove(_actorNotesKey(planId, uuid));
      await _touchPlan(planId);
    }
    return deleted;
  }

  String _planKey(String uuid) => 'p:$uuid';
  String _exerciseKey(String planUuid, String uuid) => 'pe:$planUuid:$uuid';
  String _teamKey(String planUuid, String uuid) => 'pt:$planUuid:$uuid';
  String _sessionKey(String planUuid, String uuid) => 'ps:$planUuid:$uuid';
  String _rolePlayKey(String planUuid, String uuid) => 'pr:$planUuid:$uuid';
  String _actorKey(String planUuid, String uuid) => 'pa:$planUuid:$uuid';
  // Actor.notes is excluded from JSON manifests (ADR-0022); stored under pan:.
  String _actorNotesKey(String planUuid, String uuid) => 'pan:$planUuid:$uuid';

  // Brief markdown sidecars (ADR-0022). The *Md/brief fields on Plan,
  // Exercise, Station and RolePlay are annotated includeToJson:false because
  // the .drill archive stores them as standalone <field>.md files. The in-app
  // store is SharedPreferences JSON, so without a parallel sidecar here those
  // fields are silently dropped on every save (and read back as null). Each
  // key holds a small JSON blob of just the markdown fields, mirroring the
  // pan: precedent for Actor.notes.
  String _planBriefKey(String uuid) => 'pgm:$uuid';
  String _exerciseBriefKey(String planUuid, String uuid) =>
      'pem:$planUuid:$uuid';
  String _rolePlayBriefKey(String planUuid, String uuid) =>
      'prm:$planUuid:$uuid';

  static Map<String, dynamic>? _tryDecodeMap(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static void _putIfPresent(
    Map<String, dynamic> map,
    String key,
    String? value,
  ) {
    if (value != null) map[key] = value;
  }

  // --- Plan brief sidecar ------------------------------------------------

  static Map<String, dynamic> _planBriefBlob(Plan plan) {
    final map = <String, dynamic>{};
    _putIfPresent(map, 'briefIntro', plan.briefIntroMd);
    _putIfPresent(map, 'comms', plan.commsMd);
    _putIfPresent(map, 'beforeRound', plan.beforeRoundMd);
    return map;
  }

  Future<void> _writePlanBrief(Plan plan) async {
    final blob = _planBriefBlob(plan);
    final key = _planBriefKey(plan.uuid);
    if (blob.isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, jsonEncode(blob));
    }
  }

  Plan _applyPlanBrief(Plan plan) {
    final raw = _prefs.getString(_planBriefKey(plan.uuid));
    if (raw == null) return plan;
    final blob = _tryDecodeMap(raw);
    if (blob == null) return plan;
    return plan.copyWith(
      briefIntroMd: blob['briefIntro'] as String?,
      commsMd: blob['comms'] as String?,
      beforeRoundMd: blob['beforeRound'] as String?,
    );
  }

  // --- Exercise brief sidecar (incl. nested stations) -----------------------

  static Map<String, dynamic> _stationBriefMap(Station station) {
    final map = <String, dynamic>{};
    _putIfPresent(map, 'equipment', station.equipmentMd);
    _putIfPresent(map, 'situation', station.situationMd);
    _putIfPresent(map, 'mission', station.missionMd);
    _putIfPresent(map, 'logistics', station.logisticsMd);
    _putIfPresent(map, 'criticalQuestions', station.criticalQuestionsMd);
    _putIfPresent(map, 'leaderAnswers', station.leaderAnswersMd);
    _putIfPresent(map, 'directorNotes', station.directorNotesMd);
    return map;
  }

  static Station _applyStationBrief(Station station, Map<String, dynamic> m) {
    return station.copyWith(
      equipmentMd: m['equipment'] as String?,
      situationMd: m['situation'] as String?,
      missionMd: m['mission'] as String?,
      logisticsMd: m['logistics'] as String?,
      criticalQuestionsMd: m['criticalQuestions'] as String?,
      leaderAnswersMd: m['leaderAnswers'] as String?,
      directorNotesMd: m['directorNotes'] as String?,
    );
  }

  static Map<String, dynamic> _exerciseBriefBlob(Exercise exercise) {
    final blob = <String, dynamic>{};
    final ex = <String, dynamic>{};
    _putIfPresent(ex, 'method', exercise.methodMd);
    _putIfPresent(ex, 'learningGoals', exercise.learningGoalsMd);
    _putIfPresent(ex, 'trainingFocus', exercise.trainingFocusMd);
    _putIfPresent(ex, 'orderFormat', exercise.orderFormatMd);
    _putIfPresent(ex, 'executionTips', exercise.executionTipsMd);
    _putIfPresent(ex, 'comms', exercise.commsMd);
    if (ex.isNotEmpty) blob['exercise'] = ex;

    final stations = <String, dynamic>{};
    for (final station in exercise.stations) {
      final sm = _stationBriefMap(station);
      if (sm.isNotEmpty) stations['${station.index}'] = sm;
    }
    if (stations.isNotEmpty) blob['stations'] = stations;
    return blob;
  }

  Future<void> _writeExerciseBrief(String planUuid, Exercise exercise) async {
    final blob = _exerciseBriefBlob(exercise);
    final key = _exerciseBriefKey(planUuid, exercise.uuid);
    if (blob.isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, jsonEncode(blob));
    }
  }

  Exercise _applyExerciseBrief(String planUuid, Exercise exercise) {
    final raw = _prefs.getString(_exerciseBriefKey(planUuid, exercise.uuid));
    if (raw == null) return exercise;
    final blob = _tryDecodeMap(raw);
    if (blob == null) return exercise;

    var result = exercise;
    final ex = blob['exercise'];
    if (ex is Map<String, dynamic>) {
      result = result.copyWith(
        methodMd: ex['method'] as String?,
        learningGoalsMd: ex['learningGoals'] as String?,
        trainingFocusMd: ex['trainingFocus'] as String?,
        orderFormatMd: ex['orderFormat'] as String?,
        executionTipsMd: ex['executionTips'] as String?,
        commsMd: ex['comms'] as String?,
      );
    }

    final stationsBlob = blob['stations'];
    if (stationsBlob is Map<String, dynamic> && result.stations.isNotEmpty) {
      result = result.copyWith(
        stations: [
          for (final station in result.stations)
            if (stationsBlob['${station.index}'] is Map<String, dynamic>)
              _applyStationBrief(
                station,
                stationsBlob['${station.index}'] as Map<String, dynamic>,
              )
            else
              station,
        ],
      );
    }
    return result;
  }

  // --- RolePlay brief sidecar -----------------------------------------------

  static Map<String, dynamic> _rolePlayBriefBlob(RolePlay rolePlay) {
    final map = <String, dynamic>{};
    _putIfPresent(map, 'background', rolePlay.background);
    _putIfPresent(map, 'behavior', rolePlay.behavior);
    _putIfPresent(map, 'props', rolePlay.propsMd);
    return map;
  }

  Future<void> _writeRolePlayBrief(String planUuid, RolePlay rolePlay) async {
    final blob = _rolePlayBriefBlob(rolePlay);
    final key = _rolePlayBriefKey(planUuid, rolePlay.uuid);
    if (blob.isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, jsonEncode(blob));
    }
  }

  RolePlay _applyRolePlayBrief(String planUuid, RolePlay rolePlay) {
    final raw = _prefs.getString(_rolePlayBriefKey(planUuid, rolePlay.uuid));
    if (raw == null) return rolePlay;
    final blob = _tryDecodeMap(raw);
    if (blob == null) return rolePlay;
    return rolePlay.copyWith(
      background: blob['background'] as String?,
      behavior: blob['behavior'] as String?,
      propsMd: blob['props'] as String?,
    );
  }
}
