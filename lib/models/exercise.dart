import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';
import 'package:nanoid/nanoid.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/utils/time_utils.dart';

part 'exercise.freezed.dart';
part 'exercise.g.dart';

typedef StationLocation = ((String, int), String, LatLng);

/// Represents an immutable exercise with a start and end time
@freezed
sealed class Exercise with _$Exercise {
  const factory Exercise({
    required String uuid,
    required String name,
    @TimeOfDayConverter() required TimeOfDay startTime,
    required int numberOfTeams,
    required int numberOfRounds,
    required int executionTime,
    required int evaluationTime,
    required int rotationTime,
    required List<Station> stations,
    @TimeOfDayConverter() required List<List<TimeOfDay>> schedule,
    @TimeOfDayConverter() required TimeOfDay endTime,
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

  /// Static factory extension to generate a schedule and return an Exercise instance
  static Exercise generateSchedule({
    String? uuid,
    required String name,
    required TimeOfDay startTime,
    required int numberOfTeams,
    required int numberOfRounds,
    required int executionTime,
    required int evaluationTime,
    required int rotationTime,
    required AppLocalizations localizations,
    bool calcFromTimes = true,
    List<Station> stations = const [],
  }) {
    assert(
      numberOfTeams <= numberOfRounds,
      '<numberOfTeams> must be less or equal to <numberOfRounds>',
    );
    // Generate the schedule matrix
    final schedule = List<List<TimeOfDay>>.generate(numberOfRounds, (
      stationIndex,
    ) {
      TimeOfDay currentStartTime = _addMinutesToTime(
        startTime,
        stationIndex * (executionTime + evaluationTime + rotationTime),
      );

      return List.generate(3, (phaseIndex) {
        final phaseDuration = switch (phaseIndex) {
          0 => calcFromTimes ? 0 : executionTime,
          1 => calcFromTimes ? executionTime : evaluationTime,
          2 => calcFromTimes ? evaluationTime : rotationTime,
          _ => throw UnimplementedError(),
        };
        phaseIndex == 0
            ? executionTime
            : (phaseIndex == 1 ? evaluationTime : rotationTime);
        final phaseTime = _addMinutesToTime(currentStartTime, phaseDuration);

        // Update currentStartTime to the end of the current phase
        currentStartTime = phaseTime;
        return phaseTime;
      });
    });

    // Compute the endTime from the last phase of the last round
    final lastRound = schedule.last;
    final lastPhase = lastRound.last;
    final endTime = calcFromTimes
        ? TimeOfDay.fromDateTime(
            lastPhase.toDateTime().add(Duration(minutes: rotationTime)),
          )
        : lastPhase; // End time is when the last phase ends

    // Return a new Exercise instance
    return Exercise(
      name: name,
      uuid: uuid ?? nanoid(8),
      startTime: startTime,
      executionTime: executionTime,
      evaluationTime: evaluationTime,
      rotationTime: rotationTime,
      numberOfTeams: numberOfTeams,
      numberOfRounds: numberOfRounds,
      stations: ensureStations(localizations, numberOfRounds, stations),
      schedule: List.unmodifiable(schedule),
      endTime: endTime,
    );
  }

  static List<Station> ensureStations(
    AppLocalizations localizations,
    int numberOfRounds,
    List<Station> stations,
  ) {
    return List.unmodifiable(
      List<Station>.generate(numberOfRounds, (index) {
        return index < stations.length
            ? stations[index]
            : Station(
                index: index,
                name: '${localizations.station(1)} ${index + 1}',
              );
      }),
    );
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

  /// Check if the current time falls within the exercise time range
  bool isActiveNow(TimeOfDay currentTime) {
    final nowMinutes = currentTime.hour * 60 + currentTime.minute;
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;

    return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
  }

  /// Helper function: Add a duration (in minutes) to a TimeOfDay
  static TimeOfDay _addMinutesToTime(TimeOfDay time, int minutesToAdd) {
    final totalMinutes = time.hour * 60 + time.minute + minutesToAdd;
    final addedHours = totalMinutes ~/ 60;
    final addedMinutes = totalMinutes % 60;

    return TimeOfDay(
      hour: addedHours % 24, // Wrap around 24-hour clock
      minute: addedMinutes,
    );
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

class TimeOfDayConverter
    implements JsonConverter<TimeOfDay, Map<String, dynamic>> {
  const TimeOfDayConverter();

  @override
  TimeOfDay fromJson(Map<String, dynamic> json) {
    return TimeOfDay(hour: json['hour']!, minute: json['minute']!);
  }

  @override
  Map<String, dynamic> toJson(TimeOfDay object) {
    return {'hour': object.hour, 'minute': object.minute};
  }
}

/// Represents an immutable drill program metadata
@freezed
sealed class ExerciseMetadata with _$ExerciseMetadata {
  const factory ExerciseMetadata({String? copyOfUuid}) = _ExerciseMetadata;

  factory ExerciseMetadata.fromJson(Map<String, dynamic> json) =>
      _$ExerciseMetadataFromJson(json);
}
