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
  // Modulo, not a bare subtraction: these are clock faces, so a window running
  // past midnight (23:00 -> 01:00) gave 60 - 1380 = -1320 minutes and rendered a
  // negative duration on every surface that shows this summary — the Post viewer's
  // Tidsplan card, the Spill viewer's "Når aktiv" card and both team schedules.
  // Same root cause as an exercise started after midnight waiting a day; see
  // Exercise.windowAt.
  final durationMinutes = (end.inMinutes - start.inMinutes + 1440) % 1440;
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
    this.badge,
    this.emptyNote,
  });

  /// Optional one-line summary appended to [title] in the header while the
  /// card is collapsed (e.g. the Når aktiv card's "{start} - {end}
  /// (duration)"), so the reader sees it without expanding. Null keeps the
  /// plain icon + title header.
  final String? collapsedSummary;

  /// A short qualifier for the card's header, beside the title.
  ///
  /// Added for the exercise's conduct mode (ADR-0062): a reader could tell a `split`
  /// exercise from a ring route only by noticing that its round rows named several
  /// teams, which is inference rather than information. In the header rather than
  /// above the table because it qualifies the whole card — it says what kind of
  /// schedule this is — and the header had the room already.
  ///
  /// Rendered in [CollapsibleSectionCard]'s own `trailing` slot, so it survives
  /// collapsing and needs no new header layout.
  final String? badge;

  /// Shown instead of the table when there are no rows.
  ///
  /// A station that no round uses is a state ADR-0062 made reachable: once a round is
  /// a group rather than a rotation over every station, a station can belong to no
  /// group at all. Rendering its timetable as every row struck through says so only by
  /// implication, and asks the reader to notice an absence; a sentence says it.
  final String? emptyNote;

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
      trailing: badge == null ? null : _badgeChip(context, badge!),
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
        child: (rows.isEmpty && emptyNote != null)
            ? Text(
                emptyNote!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            : ScheduleTable(
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

  /// Quiet by design: this qualifies the title, it is not a status. The app's other
  /// header trailings are counts in the same muted weight.
  Widget _badgeChip(BuildContext context, String label) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
