import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/views/widgets/card_section_header.dart';
import 'package:ringdrill/views/widgets/collapsible_section_card.dart';
import 'package:ringdrill/views/widgets/schedule_table.dart';

/// The collapsed-header window summary "{start} - {end} ({duration})" shared
/// by the Post viewer's Tidsplan card (the whole exercise window) and the
/// Spill viewer's Når aktiv card (the marker's active window). Drops a
/// trailing "0 min" so whole hours read as e.g. "3 t".
String scheduleWindowSummary(
  AppLocalizations l10n,
  SimpleTimeOfDay start,
  SimpleTimeOfDay end,
) {
  final durationMinutes = end.inMinutes - start.inMinutes;
  final hours = durationMinutes ~/ 60;
  final rest = durationMinutes % 60;
  final durationText = hours == 0
      ? l10n.minute(rest)
      : rest == 0
      ? '$hours ${l10n.variableDurationHourUnit}'
      : l10n.hoursMinutesShort(hours, rest);
  return '$start - $end ($durationText)';
}

/// The one round/phase-time schedule card every surface with its own `Card`
/// shows (DESIGN-010 stage 3e): a foldable [CollapsibleSectionCard] header
/// above a bordered, fill-width [ScheduleTable]. The Post viewer's
/// "Tidsplan" card, the Spill viewer's "Når aktiv" card, and both team
/// surfaces' own schedule now all build from this one definition instead
/// of four near-identical blocks.
class ScheduleCard extends StatelessWidget {
  const ScheduleCard({
    super.key,
    required this.sectionId,
    required this.title,
    required this.headerLabel,
    required this.rows,
    required this.event,
    required this.exercise,
    this.icon = Icons.access_time_filled,
    this.labelWidth = 90,
    this.collapsedSummary,
  });

  /// Optional one-line summary appended to [title] in the header while the
  /// card is collapsed (e.g. the Når aktiv card's "{start} - {end}
  /// (duration)"), so the reader sees it without expanding. Null keeps the
  /// plain icon + title header.
  final String? collapsedSummary;

  /// Stable identifier for the persisted collapsed preference (DESIGN-010
  /// follow-up: collapsible-section-cards) — distinct per kind of schedule
  /// card (e.g. the Post viewer's "schedule" vs. the Spill viewer's
  /// "activeSchedule"), never [title], which is localized.
  final String sectionId;

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
    return CollapsibleSectionCard(
      sectionId: sectionId,
      icon: icon,
      title: title,
      headerBuilder: collapsedSummary == null
          ? null
          : (collapsed) => kickerHeaderContent(
              context,
              icon: icon,
              // Kicker upper-cased; the summary (times, duration) keeps its
              // natural case.
              title: collapsed
                  ? '${title.toUpperCase()} · $collapsedSummary'
                  : title.toUpperCase(),
            ),
      body: Padding(
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
    );
  }
}
