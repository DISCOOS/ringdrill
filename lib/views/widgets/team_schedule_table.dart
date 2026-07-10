import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';

/// One row of a [TeamScheduleTable]: a round's team assignment (DESIGN-010's
/// Post viewer Tidsplan card and Spill viewer Når-aktiv card) — the actual
/// clock times from `Exercise.schedule[roundIndex]`, not the rotation math
/// itself (the caller already computed `teamIndex` via
/// `Exercise.teamIndex`/`stationIndex`, the same helpers the live rotation
/// view uses; this widget only renders).
class TeamScheduleRow {
  const TeamScheduleRow({
    required this.roundIndex,
    required this.teamIndex,
    required this.phaseTimes,
    this.current = false,
    this.onTap,
  });

  final int roundIndex;

  /// `-1` when no team is assigned to this station this round (rendered
  /// muted + struck through, "×" — the live rotation view's own convention).
  final int teamIndex;

  /// Formatted drill/eval/roll clock times for this round, in that order.
  final List<String> phaseTimes;

  /// The round currently running (bold + accent), mirroring the live
  /// rotation view's `isCurrent` styling. Never true when [teamIndex] is
  /// `-1`.
  final bool current;

  /// Opens the team sheet — omitted (row not tappable) when [teamIndex] is
  /// `-1`.
  final VoidCallback? onTap;
}

/// A static per-round table (DESIGN-010's mockup `.tbl`): one header row
/// (Lag/Team, Øve/Eval/Rull) then one row per [TeamScheduleRow] — plain
/// clock-time text, no live progress bars (that stays `PhaseTile`'s own
/// job on the live coordinator/team surfaces). Built from the same
/// `Exercise.schedule` + `teamIndex`/`stationIndex` data the live rotation
/// view reads, not a duplicate of its rotation math.
class TeamScheduleTable extends StatelessWidget {
  const TeamScheduleTable({super.key, required this.rows});

  final List<TeamScheduleRow> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _TableRow(
            cells: [l10n.team(1), l10n.drill, l10n.eval, l10n.roll],
            header: true,
          ),
          for (final row in rows)
            _TableRow(
              onTap: row.onTap,
              muted: row.teamIndex == -1,
              current: row.current,
              cells: [
                row.teamIndex == -1
                    ? '${l10n.team(1)} ×'
                    : '${l10n.team(1)} ${row.teamIndex + 1}',
                for (final time in row.phaseTimes) time,
              ],
            ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.cells,
    this.header = false,
    this.muted = false,
    this.current = false,
    this.onTap,
  });

  final List<String> cells;
  final bool header;
  final bool muted;
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = header
        ? theme.colorScheme.onSurfaceVariant
        : muted
        ? theme.colorScheme.onSurfaceVariant
        : current
        ? theme.colorScheme.primary
        : null;
    final style =
        (header ? theme.textTheme.labelSmall : theme.textTheme.bodyMedium)
            ?.copyWith(
              color: color,
              fontWeight: header || current ? FontWeight.bold : null,
              decoration: muted ? TextDecoration.lineThrough : null,
            );
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: header ? theme.colorScheme.surfaceContainerHighest : null,
          border: header
              ? null
              : Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
        ),
        child: Row(
          children: [
            for (var i = 0; i < cells.length; i++)
              Expanded(
                flex: i == 0 ? 3 : 2,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: i == 0 ? 12 : 6,
                    vertical: 8,
                  ),
                  child: Text(
                    cells[i],
                    textAlign: i == 0 ? TextAlign.left : TextAlign.center,
                    style: style,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
