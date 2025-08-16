import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/station.dart';

part 'exercise.freezed.dart';
part 'exercise.g.dart';

typedef StationLocation = ((String, int), String, LatLng);

/// Represents an immutable exercise with a start and end time
@freezed
sealed class Exercise with _$Exercise {
  const factory Exercise({
    required String uuid,
    required String name,
    required SimpleTimeOfDay startTime,
    required int numberOfTeams,
    required int numberOfRounds,
    required int executionTime,
    required int evaluationTime,
    required int rotationTime,
    required List<Station> stations,
    required List<List<SimpleTimeOfDay>> schedule,
    required SimpleTimeOfDay endTime,
    ExerciseMetadata? metadata,
  }) = _Exercise;

  factory Exercise.fromJson(Map<String, dynamic> json) =>
      _$ExerciseFromJson(json);
}

extension ExerciseX on Exercise {
  List<StationLocation> getLocations([bool withExersiceName = true]) {
    int i = 0;
    final markers = <StationLocation>[];
    for (final s in stations.where((e) => e.position != null)) {
      markers.add((
        (uuid, i++),
        [if (withExersiceName) name, s.name].join(' | '),
        s.position!,
      ));
    }
    return markers;
  }

  /// Sanitizes and validates the exercise name.
  static String? sanitizeExerciseName(String name) {
    // Trim unnecessary spaces
    final sanitized = name.trim();

    // Check if the name is empty or too short/long
    if (sanitized.isEmpty) {
      return 'Exercise name cannot be empty.';
    }
    if (sanitized.length > 50) {
      return 'Exercise name must not exceed 50 characters.';
    }

    // Check for invalid characters (e.g., special symbols)
    final invalidCharacters = RegExp(r'''["'\\{}\[\]]''');
    if (invalidCharacters.hasMatch(sanitized)) {
      return 'Exercise name contains invalid characters.';
    }

    // If all checks pass, return null (indicating the name is valid)
    return null;
  }

  int teamIndex(int stationIndex, int roundIndex) {
    /*
        Station: 0 1 2 3
        ----------------
        Round 0: 0 1 - -
        Round 1: - 0 1 -
        Round 2: - - 0 1
        Round 3: 1 - - 0

        t0:0 = s0
        t0:1 = s1
        t0:2 = s2
        t0:3 = s3

        t1:0 = s1
        t1:1 = s2
        t1:2 = s3
        t1:3 = s0
     */

    final t = (stationIndex - roundIndex + stations.length) % stations.length;
    return (t < numberOfTeams) ? t : -1;
  }

  int stationIndex(int teamIndex, int roundIndex) {
    return (teamIndex + roundIndex) % stations.length;
  }
}

/// Represents an immutable drill program metadata
@freezed
sealed class ExerciseMetadata with _$ExerciseMetadata {
  const factory ExerciseMetadata({String? copyOfUuid}) = _ExerciseMetadata;

  factory ExerciseMetadata.fromJson(Map<String, dynamic> json) =>
      _$ExerciseMetadataFromJson(json);
}

/// Pure-Dart replacement for Flutter's [TimeOfDay].
/// Stores hours (0–23) and minutes (0–59).
@freezed
sealed class SimpleTimeOfDay with _$SimpleTimeOfDay {
  const SimpleTimeOfDay._();

  const factory SimpleTimeOfDay({required int hour, required int minute}) =
      _SimpleTimeOfDay;

  /// Create from total minutes since midnight
  factory SimpleTimeOfDay.fromMinutes(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    return SimpleTimeOfDay(hour: h, minute: m);
  }

  factory SimpleTimeOfDay.fromJson(Map<String, dynamic> json) =>
      _$SimpleTimeOfDayFromJson(json);

  /// Minutes since midnight
  int get inMinutes => hour * 60 + minute;

  /// Format as "HH:mm" (24h)
  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Compare times (earlier < later)
  int compareTo(SimpleTimeOfDay other) => inMinutes.compareTo(other.inMinutes);
}
