import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4),
      color: isCurrent ? Colors.blueAccent : Colors.transparent,
      child: Text(
        '${exercise.stationIndex(teamIndex, roundIndex) + 1}',
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
