import 'dart:convert';

import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/team.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgramRepository {
  final SharedPreferences _prefs;

  ProgramRepository(this._prefs);

  /// Load all exercises from SharedPreferences
  List<Exercise> loadExercises() {
    final keys = _prefs.getKeys();
    final items = keys
        .where((key) => key.startsWith('e:'))
        .map((key) {
          final jsonString = _prefs.getString(key);
          if (jsonString == null) return null;
          return Exercise.fromJson(jsonDecode(jsonString));
        })
        .whereType<Exercise>() // Filter out invalid items
        .toList();
    items.sort((e1, e2) => e1.name.compareTo(e2.name));
    return items;
  }

  Exercise? getExercise(String uuid) {
    final jsonString = _prefs.getString(_exerciseKey(uuid));
    if (jsonString == null) return null;
    return Exercise.fromJson(jsonDecode(jsonString));
  }

  /// Add a new exercise to SharedPreferences, ensuring uniqueness by uuid
  Future<void> addExercise(Exercise exercise, [bool replace = false]) async {
    if (!replace && _prefs.containsKey(_exerciseKey(exercise.uuid))) {
      throw Exception(
        'An exercise with the uuid "${exercise.uuid}" already exists.',
      );
    }
    await saveExercise(exercise);
  }

  /// Save a single exercise to SharedPreferences with its uuid as the key
  Future<void> saveExercise(Exercise exercise) async {
    final exerciseJson = jsonEncode(exercise.toJson());
    await _prefs.setString(_exerciseKey(exercise.uuid), exerciseJson);
  }

  /// Delete an exercise from SharedPreferences using its uuid
  Future<Exercise?> deleteExercise(String uuid) async {
    final deleted = getExercise(uuid);
    if (deleted != null) {
      await _prefs.remove(_exerciseKey(uuid));
    }
    return deleted;
  }

  String _exerciseKey(String uuid) => 'e:$uuid';

  /// Delete all exercise from SharedPreferences
  Future<List<Exercise>> deleteAllExercises() async {
    final exercises = loadExercises();
    await Future.wait(exercises.map((e) => deleteExercise(e.uuid)));
    return exercises;
  }

  /// Load all teams from SharedPreferences
  List<Team> loadTeams() {
    final keys = _prefs.getKeys();
    final items = keys
        .where((key) => key.startsWith('t:'))
        .map((key) {
          final jsonString = _prefs.getString(key);
          if (jsonString == null) return null;
          return Team.fromJson(jsonDecode(jsonString));
        })
        .whereType<Team>() // Filter out invalid items
        .toList();
    items.sort((e1, e2) => e1.name.compareTo(e2.name));
    return items;
  }

  Team? getTeam(String uuid) {
    final jsonString = _prefs.getString(_teamKey(uuid));
    if (jsonString == null) return null;
    return Team.fromJson(jsonDecode(jsonString));
  }

  /// Add a new Team to SharedPreferences, ensuring uniqueness by uuid
  Future<void> addTeam(Team team, [bool replace = false]) async {
    if (!replace && _prefs.containsKey(_teamKey(team.uuid))) {
      throw Exception('An Team with the uuid "${team.uuid}" already exists.');
    }
    await saveTeam(team);
  }

  /// Save a single exercise to SharedPreferences with its uuid as the key
  Future<void> saveTeam(Team team) async {
    final teamJson = jsonEncode(team.toJson());
    await _prefs.setString(_teamKey(team.uuid), teamJson);
  }

  /// Delete an Team from SharedPreferences using its uuid
  Future<Team?> deleteTeam(String uuid) async {
    final deleted = getTeam(uuid);
    if (deleted != null) {
      await _prefs.remove(_teamKey(uuid));
    }
    return deleted;
  }

  String _teamKey(String uuid) => 't:$uuid';

  /// Delete all Team from SharedPreferences
  Future<List<Team>> deleteAllTeams() async {
    final teams = loadTeams();
    await Future.wait(teams.map((e) => deleteTeam(e.uuid)));
    return teams;
  }

  bool containsTeam(String uuid) {
    return _prefs.containsKey(_teamKey(uuid));
  }
}
