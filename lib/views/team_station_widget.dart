import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/views/round_occupancy.dart';
import 'package:ringdrill/theme.dart' show kDrillAccentFontSize;

class TeamStationWidget extends StatelessWidget {
  const TeamStationWidget({
    super.key,
    required this.isCurrent,
    required this.exercise,
    required this.teamIndex,
    required this.roundIndex,
  });

  final bool isCurrent;
  final int teamIndex;
  final int roundIndex;
  final Exercise exercise;

  /// The one-based station number, or × when the team is not placed this round.
  String get _label {
    final station = RoundOccupancy.stationOf(exercise, teamIndex, roundIndex);
    return station == null ? '×' : '${station + 1}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4),
      color: isCurrent ? Colors.blueAccent : Colors.transparent,
      child: Text(
        // × when the team is nowhere this round — possible from ADR-0062, where a
        // `split` round may hold a team back. Adding 1 to the raw index rendered
        // that as station "0", a station that does not exist.
        _label,
        style: TextStyle(
          // ADR-0037 drillAccent: match the sibling station-row numbers and
          // the "Post" label instead of a larger hardcoded 18.
          fontSize: kDrillAccentFontSize,
          fontWeight: isCurrent
              ? FontWeight.bold
              : FontWeight.normal, // Emphasize current round
          color: isCurrent ? Colors.white : null,
        ),
      ),
    );
  }
}
