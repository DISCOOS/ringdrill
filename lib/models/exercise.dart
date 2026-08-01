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

/// How an exercise's teams relate to its stations (ADR-0062).
///
/// One structure underneath: a round is a set of *groups*, and a group is one station
/// with some teams on it. These are group sizes, and two of the three are generated —
/// which is why picking one costs the author nothing.
enum ExerciseMode {
  /// One team per station, rotating. The default, and every plan written before
  /// ADR-0062 — an archive with no mode reads as this.
  @JsonValue('ring')
  ring,

  /// One group holding every team: all teams work one station at a time and move on
  /// together. A round *is* a station, so `numberOfRounds` is derived, and the
  /// `numberOfTeams: 1` workaround this replaces stops misreporting the team.
  @JsonValue('together')
  together,

  /// Any number of groups of any size, running at once, with the teams divided
  /// between them. The one mode whose assignment is authored rather than generated,
  /// because which teams take which station is a decision the app cannot infer.
  @JsonValue('split')
  split;

  /// Whether a round is one station (or a group of them) rather than all of them.
  bool get roundsAreStations => this != ExerciseMode.ring;
}

/// One station in a parallel group, with the teams placed on it (ADR-0062).
///
/// Authored, not derived: which teams take the missing child and which take the
/// shoreline is a decision about competence, travel and who has the dog, and the app
/// has no basis for guessing it. [stationIndex] refers to `Station.index` and [teams]
/// to positions in `Plan.teams`, so nothing here is a name and nothing is parsed.
@freezed
sealed class GroupSlot with _$GroupSlot {
  const factory GroupSlot({
    required int stationIndex,
    @Default(<int>[]) List<int> teams,
  }) = _GroupSlot;

  factory GroupSlot.fromJson(Map<String, dynamic> json) =>
      _$GroupSlotFromJson(json);
}

/// One round of an [ExerciseMode.split] exercise: the stations running at the same
/// time, and who is on each.
///
/// Groups are of any size and need not match each other — four teams across three
/// stations is 2 + 1 + 1. A group holding exactly one station with every team on it
/// is [ExerciseMode.together]; one holding one team per station is
/// [ExerciseMode.ring]. Those two are generated rather than authored, which is what
/// makes them free.
@freezed
sealed class ExerciseGroup with _$ExerciseGroup {
  const factory ExerciseGroup({
    @Default(<GroupSlot>[]) List<GroupSlot> stations,
  }) = _ExerciseGroup;

  factory ExerciseGroup.fromJson(Map<String, dynamic> json) =>
      _$ExerciseGroupFromJson(json);
}

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

    /// How teams relate to stations (ADR-0062). Absent in every archive written
    /// before it, which is why the default is [ExerciseMode.ring] rather than a
    /// migration rung: an old plan *is* a ring route, and says so by omission.
    @Default(ExerciseMode.ring) ExerciseMode mode,

    /// One entry per round, for [ExerciseMode.split] only: the stations running at
    /// once and the teams on each (ADR-0062). Empty in every other mode, where the
    /// grouping is generated from the stations instead.
    @Default(<ExerciseGroup>[]) List<ExerciseGroup> groups,
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
      return (start: start, end: end);
    }
    if (!reference.isBefore(end)) {
      // Today's slot has already passed, so the next occurrence is tomorrow's. This
      // is long-standing behaviour — starting an 08:00 exercise at 17:44 reports
      // *pending until tomorrow*, not "done" — and it is easy to lose while fixing
      // the midnight case, since both are about which day a clock face means. Four
      // tests caught exactly that.
      return (
        start: start.add(const Duration(days: 1)),
        end: end.add(const Duration(days: 1)),
      );
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

    final teams = teamsAt(stationIndex, roundIndex);
    return teams.isEmpty ? -1 : teams.first;
  }

  /// Every team at [stationIndex] during [roundIndex] (ADR-0062).
  ///
  /// A ring route has at most one, which is why [teamIndex] existed alone for as
  /// long as `ring` was the only mode. `together` puts all of them on one station and
  /// `split` divides them, so "the team at this post" stopped being a single answer
  /// and callers that show a post's occupants want the list.
  ///
  /// Empty means nobody is there this round — a station outside the round's group, or
  /// a ring position no team has reached.
  List<int> teamsAt(int stationIndex, int roundIndex) {
    if (stations.isEmpty) return const [];
    switch (mode) {
      case ExerciseMode.ring:
        final t =
            (stationIndex - roundIndex + stations.length) % stations.length;
        return t < numberOfTeams ? [t] : const [];
      case ExerciseMode.together:
        return _everyoneIfRoundsStation(stationIndex, roundIndex);
      case ExerciseMode.split:
        final group = _groupFor(roundIndex);
        // No groups declared yet: read it as `together`, the same fallback the
        // schedule derivation makes, rather than reporting an empty exercise.
        if (group == null) {
          return _everyoneIfRoundsStation(stationIndex, roundIndex);
        }
        for (final slot in group.stations) {
          if (slot.stationIndex == stationIndex) return slot.teams;
        }
        return const [];
    }
  }

  /// Which station [teamIndex] is at during [roundIndex], or -1 when it is nowhere.
  ///
  /// -1 is reachable outside a ring route: `split` may leave a team unplaced in a
  /// round, which `analyze` warns about but does not forbid — holding a team back is
  /// legitimate.
  int stationIndex(int teamIndex, int roundIndex) {
    if (stations.isEmpty) return -1;
    switch (mode) {
      case ExerciseMode.ring:
        return (teamIndex + roundIndex) % stations.length;
      case ExerciseMode.together:
        return _stationForRound(roundIndex);
      case ExerciseMode.split:
        final group = _groupFor(roundIndex);
        if (group == null) return _stationForRound(roundIndex);
        for (final slot in group.stations) {
          if (slot.teams.contains(teamIndex)) return slot.stationIndex;
        }
        return -1;
    }
  }

  /// Every team, but only at the station this round runs — a `together` round puts
  /// all of them on one station and nobody on the others.
  List<int> _everyoneIfRoundsStation(int stationIndex, int roundIndex) =>
      _stationForRound(roundIndex) == stationIndex
      ? [for (var t = 0; t < numberOfTeams; t++) t]
      : const [];

  /// The station a `together` round runs, by position. Wraps, so a round count that
  /// outran the stations still names one rather than throwing.
  int _stationForRound(int roundIndex) =>
      stations.isEmpty ? -1 : roundIndex % stations.length;

  /// The group for [roundIndex], or null when none is declared — a split exercise
  /// mid-edit has stations before it has groups, and reading it as `together` until
  /// then is the same fallback the schedule derivation makes.
  ExerciseGroup? _groupFor(int roundIndex) =>
      (roundIndex >= 0 && roundIndex < groups.length)
      ? groups[roundIndex]
      : null;
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
