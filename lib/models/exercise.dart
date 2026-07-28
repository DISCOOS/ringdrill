import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/station.dart';

part 'exercise.freezed.dart';
part 'exercise.g.dart';

/// `(id, label, point, shortLabel)`. [shortLabel] is the compact on-map
/// chip text for overview zooms (a station's plan number, e.g. "1.2") —
/// null when a producer has none to offer, in which case [label] renders
/// at every zoom labels are visible at all (see
/// `MapConfig.labelDetailZoomFor`, `LatlngListX.toMarkerSpecs`).
typedef StationLocation = ((String, int), String, LatLng, String?);

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

    /// Per-scope value overrides for plan-global variables, keyed by
    /// DrillVariable.name. A key that does not name a declared variable is
    /// meaningless and is ignored at resolution time (ADR-0046). This scope
    /// never declares new variables.
    @Default(<String, String>{}) Map<String, String> variableOverrides,
    // Markdown brief fields — stored as exercises/<uuid>/<field>.md, not in JSON.
    @JsonKey(includeFromJson: false, includeToJson: false) String? methodMd,
    @JsonKey(includeFromJson: false, includeToJson: false)
    String? learningGoalsMd,
    @JsonKey(includeFromJson: false, includeToJson: false)
    String? trainingFocusMd,
    @JsonKey(includeFromJson: false, includeToJson: false)
    String? orderFormatMd,
    @JsonKey(includeFromJson: false, includeToJson: false)
    String? executionTipsMd,
    @JsonKey(includeFromJson: false, includeToJson: false) String? commsMd,
  }) = _Exercise;

  factory Exercise.fromJson(Map<String, dynamic> json) =>
      _$ExerciseFromJson(json);
}

/// An exercise's scheduled window resolved onto real dates.
typedef ExerciseWindow = ({DateTime start, DateTime end});

/// [time] on the calendar day of [day].
DateTime _onDayOf(DateTime day, SimpleTimeOfDay time) =>
    DateTime(day.year, day.month, day.day, time.hour, time.minute);

extension ExerciseX on Exercise {
  /// [startTime]/[endTime] resolved to real instants around [reference].
  ///
  /// A [SimpleTimeOfDay] is a clock face with no date, so a window that crosses
  /// midnight ("23:00–01:00") is ambiguous until anchored. Anchoring naively on
  /// *today* produced two visible bugs:
  ///
  /// - Starting a 23:00 exercise at 00:30 waited 22.5 hours instead of resuming 90
  ///   minutes in. The old code pushed the *end* to tomorrow and left the start on
  ///   today, so "now" fell before a window it was actually inside.
  /// - The plan list read "20:15 - 01:15 | 19 timer": the duration was computed
  ///   across one calendar day, giving 24h minus the real 5h.
  ///
  /// The rule here is that [reference] should land *inside* the window when any
  /// candidate day contains it, and otherwise the window is the next upcoming one.
  /// Only the previous day is considered — an exercise is a few hours long, so a
  /// reference more than a day out is genuinely "not started yet" rather than a
  /// stale anchor.
  ExerciseWindow windowAt(DateTime reference) {
    // Plain DateTime arithmetic, not the time_utils helpers: those import
    // package:flutter, and the CLI reaches the models (AGENTS.md). Importing them
    // here would also close a cycle — time_utils imports this file.
    var start = _onDayOf(reference, startTime);
    var end = _onDayOf(reference, endTime);
    // Same clock face for both, or an end before the start, means the window runs
    // past midnight.
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    if (reference.isBefore(start)) {
      final previous = (
        start: start.subtract(const Duration(days: 1)),
        end: end.subtract(const Duration(days: 1)),
      );
      // Yesterday's occurrence is still running: the case that made a post-midnight
      // start wait for the following evening.
      if (!reference.isBefore(previous.start) &&
          reference.isBefore(previous.end)) {
        return previous;
      }
    }
    return (start: start, end: end);
  }

  /// How long the exercise runs, midnight crossings included.
  ///
  /// Date-independent: [windowAt] resolves both ends onto the same anchor, so the
  /// difference is the real length whatever day it is asked on.
  Duration get scheduledDuration {
    // Anchored on the start itself, so the answer does not depend on the day it is
    // asked: the window resolver only ever needs the two clock faces plus a date to
    // hang them on.
    final anchor = _onDayOf(DateTime.now(), startTime);
    final window = windowAt(anchor);
    return window.end.difference(window.start);
  }

  List<StationLocation> getLocations([bool withExersiceName = true]) {
    int i = 0;
    final markers = <StationLocation>[];
    for (final s in stations.where((e) => e.position != null)) {
      markers.add((
        (uuid, i++),
        [if (withExersiceName) name, s.name].join(' | '),
        s.position!,
        null,
      ));
    }
    return markers;
  }

  /// Like [getLocations] but labels each positioned station with its number
  /// + name (e.g. "1.2 Turgåer") and carries the number alone (e.g. "1.2")
  /// as the marker's `shortLabel` — the app-wide map convention: the
  /// number-only chip shows at overview zooms (matching
  /// [StationNumberBadge]), expanding to the full label once zoomed in
  /// close enough to have room for it (`MapConfig.labelDetailZoomFor`).
  ///
  /// [exerciseNumber] is the 1-based position of this exercise in the plan
  /// (the caller knows the plan order; the exercise itself does not). The
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
      final number = Numbering.station(
        format,
        exerciseNumber: exerciseNumber,
        stationIndex: subByStationIndex[s.index] ?? 0,
      );
      markers.add((
        (uuid, positioned++),
        '$number ${s.name}',
        s.position!,
        number,
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

/// Represents an immutable drill plan metadata
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
