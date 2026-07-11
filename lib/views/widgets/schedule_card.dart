import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/views/widgets/card_section_header.dart';
import 'package:ringdrill/views/widgets/schedule_table.dart';

/// The one round/phase-time schedule card every surface with its own `Card`
/// shows (DESIGN-010 stage 3e): a [CardSectionHeader] above a bordered,
/// fill-width [ScheduleTable]. The Post viewer's "Tidsplan" card, the Spill
/// viewer's "Når aktiv" card, and both team surfaces' own schedule now all
/// build from this one definition instead of four near-identical blocks.
class ScheduleCard extends StatelessWidget {
  const ScheduleCard({
    super.key,
    required this.title,
    required this.headerLabel,
    required this.rows,
    required this.event,
    required this.exercise,
    this.icon = Icons.access_time_filled,
    this.labelWidth = 90,
  });

  /// The card's own section title (e.g. "Tidsplan"/"Når aktiv") — distinct
  /// from [headerLabel], the schedule table's first-column header.
  final String title;
  final String headerLabel;
  final List<ScheduleTableRow> rows;
  final ExerciseEvent event;
  final Exercise exercise;
  final IconData icon;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardSectionHeader(icon: icon, title: title),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ScheduleTable(
              headerLabel: headerLabel,
              labelWidth: labelWidth,
              rows: rows,
              event: event,
              exercise: exercise,
              bordered: true,
            ),
          ),
        ],
      ),
    );
  }
}
