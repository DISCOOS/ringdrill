/// Who is at a station in a given round, said in the space a row actually has.
///
/// The question "which team is at this post now" had one answer for as long as a ring
/// route was the only shape: `Exercise.teamIndex` returned it, and thirteen call sites
/// each formatted `'${l10n.team(1)} ${i + 1}'` and `'… ×'` by hand. With
/// `mode: together` every team is on one station and with `mode: split` they divide
/// (ADR-0062), so the answer is a *list* — and thirteen copies of the formatting is
/// thirteen places for the modes to be got wrong differently.
///
/// This is the one place that knows how to say it. Deliberately not a widget: the
/// widgets that show this already exist and are right — `ScheduleTableRow`,
/// `PlayerStatusCell`, `TeamStationWidget` — they were simply being handed a string
/// computed at the call site. Only the string moves.
library;

import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';

/// Presentation of an exercise's per-round occupancy.
class RoundOccupancy {
  const RoundOccupancy._();

  /// Whether anyone is at [stationIndex] during [roundIndex].
  ///
  /// Replaces `teamIndex(...) >= 0`, which read as "the one team is real" and happens
  /// to mean the right thing only because -1 was the empty case.
  static bool isActive(Exercise exercise, int stationIndex, int roundIndex) =>
      exercise.teamsAt(stationIndex, roundIndex).isNotEmpty;

  /// The station [teamIndex] is at during [roundIndex], or null when it is nowhere.
  ///
  /// Null rather than -1, because -1 has been quietly rendering as station "0" and
  /// indexing one before the first station wherever a caller added 1 without checking.
  /// A team can legitimately be nowhere in `split` — held back for a round.
  static int? stationOf(Exercise exercise, int teamIndex, int roundIndex) {
    final station = exercise.stationIndex(teamIndex, roundIndex);
    return station < 0 ? null : station;
  }

  /// Who is at [stationIndex] during [roundIndex]: "Lag 1", "Lag 1,2", "Lag 1–4", or
  /// "Lag ×" when nobody is.
  ///
  /// The noun once, then numbers — a row that fits "Lag 1" does not fit
  /// "Lag 1, Lag 2", and in `together` it would have to fit every team the plan has.
  static String label(
    AppLocalizations l10n,
    Exercise exercise,
    int stationIndex,
    int roundIndex,
  ) => '${l10n.team(1)} '
      '${numbers(exercise.teamsAt(stationIndex, roundIndex))}';

  /// The team numbers alone, for a cell with no room for the noun.
  ///
  /// One-based, because that is what every other team label in the app shows, and
  /// contiguous runs collapse to a range: `together` puts every team on one station,
  /// so "1–6" rather than "1,2,3,4,5,6" is the common case and not a nicety.
  static String numbers(List<int> teams) {
    if (teams.isEmpty) return '×';
    final sorted = teams.toList()..sort();
    final parts = <String>[];
    var runStart = sorted.first;
    var previous = sorted.first;
    for (final team in sorted.skip(1)) {
      if (team == previous + 1) {
        previous = team;
        continue;
      }
      parts.add(_run(runStart, previous));
      runStart = team;
      previous = team;
    }
    parts.add(_run(runStart, previous));
    return parts.join(',');
  }

  /// A run of one is its own number; a run of two reads better as a pair than as a
  /// range, since "1–2" and "1,2" cost the same and the comma is plainer.
  static String _run(int first, int last) => switch (last - first) {
    0 => '${first + 1}',
    1 => '${first + 1},${last + 1}',
    _ => '${first + 1}–${last + 1}',
  };
}
