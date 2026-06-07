import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/station.dart';

part 'exercise.freezed.dart';
part 'exercise.g.dart';

typedef StationLocation = ((String, int), String, LatLng);

/// Represents an immutable exercise with a start and end time
@freezed
sealed class Exercise with _$Exercise {
  const factory Exercise({
    required String uuid,
    @Default(0) int index,
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
    String? templateId,
    // Markdown brief fields — stored as exercises/<uuid>/<field>.md, not in JSON.
    @JsonKey(includeFromJson: false, includeToJson: false) String? methodMd,
    @JsonKey(includeFromJson: false, includeToJson: false)
    String? learningGoalsMd,
    @JsonKey(includeFromJson: false, includeToJson: false)
    String? trainingFocusMd,
    @JsonKey(includeFromJson: false, includeToJson: false) String? orderFormatMd,
    @JsonKey(includeFromJson: false, includeToJson: false)
    String? executionTipsMd,
    @JsonKey(includeFromJson: false, includeToJson: false) String? commsMd,
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

  /// Like [getLocations] but labels each positioned station with its station
  /// *number* (e.g. "1.2" / "1a") instead of its name, so map markers read the
  /// same token as [StationNumberBadge].
  ///
  /// [exerciseNumber] is the 1-based position of this exercise in the program
  /// (the caller knows the program order; the exercise itself does not). The
  /// sub-index is the station's ordinal in the index-sorted full station list
  /// — including stations without a position — so the numbers match the badges
  /// shown in the Stations list even when some stations are unplaced.
  ///
  /// The marker id stays the natural-order running index over positioned
  /// stations, exactly as [getLocations] and [activeLocationIds] assign it, so
  /// live-station highlighting keeps matching.
  List<StationLocation> getNumberedLocations({
    required int exerciseNumber,
    required StationNumberFormat format,
  }) {
    final sorted = [...stations]..sort((a, b) => a.index.compareTo(b.index));
    final subByStationIndex = <int, int>{};
    for (var s = 0; s < sorted.length; s++) {
      subByStationIndex[sorted[s].index] = s;
    }
    var positioned = 0;
    final markers = <StationLocation>[];
    for (final s in stations) {
      if (s.position == null) continue;
      markers.add((
        (uuid, positioned++),
        Numbering.station(
          format,
          exerciseNumber: exerciseNumber,
          stationIndex: subByStationIndex[s.index] ?? 0,
        ),
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

  /// Marker ids — matching the ids produced by [getLocations] — of the
  /// stations that have a team assigned in [roundIndex]. Used to highlight
  /// the "live" stations (the ones teams are currently at) on the map while
  /// the exercise is running.
  ///
  /// The id's integer is the running index over stations that have a
  /// position, exactly as [getLocations] assigns it, so the returned ids
  /// line up one-to-one with the markers built from [getLocations].
  Set<(String, int)> activeLocationIds(int roundIndex) {
    final ids = <(String, int)>{};
    var positioned = 0;
    for (var stationIndex = 0; stationIndex < stations.length; stationIndex++) {
      if (stations[stationIndex].position == null) continue;
      final id = (uuid, positioned++);
      if (teamIndex(stationIndex, roundIndex) >= 0) {
        ids.add(id);
      }
    }
    return ids;
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
