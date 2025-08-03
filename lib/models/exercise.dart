import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';
import 'package:nanoid/nanoid.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/time_utils.dart';

part 'exercise.freezed.dart';
part 'exercise.g.dart';

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
    required List<Team> teams,
    required List<Station> stations,
    @TimeOfDayConverter() required List<List<TimeOfDay>> schedule,
    @TimeOfDayConverter() required TimeOfDay endTime,
  }) = _Exercise;

  factory Exercise.fromJson(Map<String, dynamic> json) =>
      _$ExerciseFromJson(json);
}

@freezed
sealed class Station with _$Station {
  const factory Station({
    required int index,
    required String name,
    LatLng? position,
    String? description,
  }) = _Station;

  factory Station.fromJson(Map<String, dynamic> json) =>
      _$StationFromJson(json);
}

@freezed
sealed class Team with _$Team {
  const factory Team({
    required int index,
    required String name,
    LatLng? position,
  }) = _Team;

  factory Team.fromJson(Map<String, dynamic> json) => _$TeamFromJson(json);
}

extension ExerciseX on Exercise {
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
    List<Team> teams = const [],
    List<Station> stations = const [],
  }) {
    assert(
      numberOfTeams <= numberOfRounds,
      '<numberOfTeams> must be less or equal to <numberOfRounds>',
    );
    assert(
      teams.isEmpty || teams.length <= numberOfRounds,
      '<teams> must be less or equal to <numberOfRounds>',
    );
    assert(
      stations.isEmpty || stations.length == numberOfRounds,
      '<stations> must be empty or have length equal to <numberOfRounds>',
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
    final endTime =
        calcFromTimes
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
      teams: List.unmodifiable(
        teams.isEmpty
            ? List<Team>.generate(numberOfTeams, (index) {
              return Team(
                index: index,
                name: '${localizations.team(1)} ${index + 1}',
              );
            })
            : stations,
      ),
      stations: List.unmodifiable(
        stations.isEmpty
            ? List<Station>.generate(numberOfRounds, (index) {
              return Station(
                index: index,
                name: '${localizations.station(1)} ${index + 1}',
              );
            })
            : stations,
      ),
      schedule: List.unmodifiable(schedule),
      endTime: endTime,
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
    return (stationIndex + roundIndex) % stations.length;
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
