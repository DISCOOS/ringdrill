import 'dart:convert';

import 'package:ringdrill/models/exercise.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExerciseRepository {
  final SharedPreferences _prefs;

  ExerciseRepository(this._prefs);

  /// Save a single exercise to SharedPreferences with its uuid as the key
  Future<void> saveExercise(Exercise exercise) async {
    final exerciseJson = jsonEncode(exercise.toJson());
    await _prefs.setString(exercise.uuid, exerciseJson);
  }

  /// Load all exercises from SharedPreferences
  List<Exercise> loadExercises() {
    final keys = _prefs.getKeys();
    return keys
        .where((key) => !key.startsWith('app:'))
        .map((key) {
          final jsonString = _prefs.getString(key);
          if (jsonString == null) return null;
          return Exercise.fromJson(jsonDecode(jsonString));
        })
        .whereType<Exercise>() // Filter out invalid items
        .toList();
  }

  Future<Exercise?> getExercise(String uuid) async {
    final jsonString = _prefs.getString(uuid);
    if (jsonString == null) return null;
    return Exercise.fromJson(jsonDecode(jsonString));
  }

  /// Add a new exercise to SharedPreferences, ensuring uniqueness by uuid
  Future<void> addExercise(Exercise exercise, [bool replace = false]) async {
    if (!replace && _prefs.containsKey(exercise.uuid)) {
      throw Exception(
        'An exercise with the name "${exercise.uuid}" already exists.',
      );
    }
    await saveExercise(exercise);
  }

  /// Delete an exercise from SharedPreferences using its uuid
  Future<void> deleteExercise(String uuid) async {
    if (_prefs.containsKey(uuid)) {
      await _prefs.remove(uuid);
    }
  }
}
