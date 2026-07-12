import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/utils/time_utils.dart';

/// Shared horizontal inset every player/overview surface (Post, Lag, Spill,
/// Coordinator) applies around its status-card-and-schedule-card stack. One
/// constant, not four per-surface literals, so the two cards can't drift out
/// of alignment with each other.
const double kPlayerSurfaceHorizontalPadding = 16;

/// One cell of [PlayerStatusCard]'s now/next row: an icon+label header
/// (optionally with an inline time, e.g. "Neste · 11:15") over an
/// auto-sized value (optionally led by a number badge, e.g. a post code).
///
/// [isNow] paints the value in the live accent colour instead of a plain
/// one — the two cells share the same min/max font size (see
/// [PlayerStatusCard._valueMinFontSize]/[PlayerStatusCard._valueMaxFontSize])
/// so the pair always reads as matched regardless of which one is "now".
class PlayerStatusCell {
  const PlayerStatusCell({
    this.icon,
    required this.label,
    required this.value,
    this.time,
    this.badge,
    this.isNow = false,
  });

  /// Leading icon shown before [label]. `null` omits the icon (and its
  /// spacer) entirely — used by the coordinator's forward-looking cells,
  /// which carry no icon.
  final IconData? icon;
  final String label;

  /// Inline time shown on the label row for a "next"-style cell (e.g.
  /// "11:15"). Left `null` for a "now" cell, which carries no time.
  final String? time;

  /// Optional leading number badge (e.g. a post code like "2a") shown
  /// before [value].
  final String? badge;
  final String value;
  final bool isNow;
}

/// The shared running-exercise status card (DESIGN-010 follow-up:
/// player-status-card) — one widget, two states, used by every player/
/// overview surface (coordinator, Post, Lag, Spill) instead of each
/// surface's own thin "phase + countdown" row.
///
/// * **Pending** ([ExerciseEvent.isPending]): a simple, centered pre-start
///   block — the spelled-out countdown to start, "TIL START", and an
///   optional [preStartSubline].
/// * **Running**: a countdown line ("N min igjen av **FASE**"), a meta
///   cell (round counter + phase-end time), a phase-progress bar driven by
///   [ExerciseEvent.phaseProgress] (the same source `PhasesWidget`'s
///   active-round fill uses), and an optional now/next row built from
///   [leadingCell]/[trailingCell] — each surface computes its own cells
///   from the rotation helpers (`Exercise.teamIndex`/`stationIndex`) and
///   hands them in; this widget only lays them out.
///
/// A `null` [leadingCell]/[trailingCell] simply omits that cell's content
/// (e.g. "Neste" on the last round) while keeping the row's two-column
/// structure. When both are `null` the now/next row is omitted entirely.
class PlayerStatusCard extends StatelessWidget {
  const PlayerStatusCard({
    super.key,
    required this.event,
    this.preStartSubline,
    this.leadingCell,
    this.trailingCell,
  });

  final ExerciseEvent event;

  /// Subline under "TIL START" in the pre-start state — start time + round
  /// count for Coordinator/Post/Lag, or "active from … · at …" for Spill.
  final String? preStartSubline;

  final PlayerStatusCell? leadingCell;
  final PlayerStatusCell? trailingCell;

  static const double _valueMaxFontSize = 24;
  static const double _valueMinFontSize = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: event.isPending
          ? _buildPreStart(context, theme)
          : _buildRunning(context, theme),
    );
  }

  // ---------------------------------------------------------------------
  // Pending — pre-start block
  // ---------------------------------------------------------------------

  Widget _buildPreStart(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _spelledCountdown(l10n, event.remainingTime),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            l10n.statusUntilStart.toUpperCase(),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if ((preStartSubline ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              preStartSubline!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Spells out the countdown-to-start with units — "20 timer 45 min",
  /// "45 min", "2 timer" — dropping zero units, rather than an ambiguous
  /// `mm:ss`/`H:MM` clock: the time to start can be hours long once the
  /// exercise is started well ahead of its scheduled time.
  String _spelledCountdown(AppLocalizations l10n, int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return l10n.minute(m);
    if (m == 0) return l10n.hour(h);
    return '${l10n.hour(h)} ${l10n.minute(m)}';
  }

  // ---------------------------------------------------------------------
  // Running — countdown + meta + progress + now/next
  // ---------------------------------------------------------------------

  Widget _buildRunning(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final endTime = _endTimeLabel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 19, 16, 5),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${event.remainingTime}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.statusMinutesRemainingOf,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          event.getState(l10n),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildMetaLine(
                      theme,
                      text: l10n.statusRoundOfTotal(
                        event.currentRound + 1,
                        event.exercise.numberOfRounds,
                      ),
                      numbers: [
                        '${event.currentRound + 1}',
                        '${event.exercise.numberOfRounds}',
                      ],
                    ),
                    if (endTime != null) ...[
                      const SizedBox(height: 2),
                      _buildMetaLine(
                        theme,
                        text: l10n.phaseEndsAt(endTime),
                        numbers: [endTime],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 13),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: event.phaseProgress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation(Colors.blueAccent),
            ),
          ),
        ),
        if (leadingCell != null || trailingCell != null)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            // A `Stack`, not `IntrinsicHeight` + stretch: `_MeasuredFitText`
            // (inside `_buildCell`) uses a `LayoutBuilder` to measure the
            // available width, and `LayoutBuilder` cannot sit below an
            // `IntrinsicHeight` (it doesn't support computing intrinsic
            // dimensions). The Stack's own height comes from the (non-
            // positioned) cell row; the divider is a second, `Positioned.fill`
            // row stretched to that already-resolved height — a `Positioned`
            // child never contributes to the Stack's own sizing pass, so no
            // intrinsics are involved.
            child: Stack(
              children: [
                Row(
                  // `center`, not `start`: when one cell wraps to more
                  // lines than the other (e.g. a long station name vs a
                  // short team label) the two cell bodies must still line
                  // up around a shared vertical center, not pin to the top
                  // of the taller cell.
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _buildCell(context, theme, leadingCell)),
                    Expanded(child: _buildCell(context, theme, trailingCell)),
                  ],
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Expanded(child: SizedBox.shrink()),
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: theme.colorScheme.outlineVariant,
                        ),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// The current phase's wall-clock end time, from
  /// `Exercise.phaseEndTime` — `null` once the exercise has no more
  /// phases/rounds to report (last phase of the last round only falls
  /// back to `Exercise.endTime`, which `phaseEndTime` already returns).
  String? get _endTimeLabel {
    final phaseIndex = event.phase.index - 1;
    final end = event.exercise.phaseEndTime(event.currentRound, phaseIndex);
    return end?.toString();
  }

  /// One meta line ("Runde N av M" / "ferdig HH:MM"): the localized [text]
  /// with each of [numbers] (the raw substrings, e.g. round/total/time,
  /// found in the order they appear) rendered bold and a step larger while
  /// the surrounding words stay regular weight.
  Widget _buildMetaLine(
    ThemeData theme, {
    required String text,
    required List<String> numbers,
  }) {
    final baseStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 13,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final boldStyle = baseStyle?.copyWith(
      fontSize: 14.5,
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Text.rich(
      TextSpan(children: _boldedSpans(text, numbers, baseStyle, boldStyle)),
      textAlign: TextAlign.right,
    );
  }

  /// Splits [text] into spans, styling each occurrence of [highlights] (in
  /// the order given) with [boldStyle] and everything else with [baseStyle].
  List<TextSpan> _boldedSpans(
    String text,
    List<String> highlights,
    TextStyle? baseStyle,
    TextStyle? boldStyle,
  ) {
    final spans = <TextSpan>[];
    var pos = 0;
    for (final highlight in highlights) {
      if (highlight.isEmpty) continue;
      final index = text.indexOf(highlight, pos);
      if (index < 0) continue;
      if (index > pos) {
        spans.add(TextSpan(text: text.substring(pos, index), style: baseStyle));
      }
      spans.add(TextSpan(text: highlight, style: boldStyle));
      pos = index + highlight.length;
    }
    if (pos < text.length) {
      spans.add(TextSpan(text: text.substring(pos), style: baseStyle));
    }
    return spans;
  }

  Widget _buildCell(
    BuildContext context,
    ThemeData theme,
    PlayerStatusCell? cell,
  ) {
    if (cell == null) return const SizedBox.shrink();
    final valueStyle = TextStyle(
      fontWeight: FontWeight.w600,
      color: cell.isNow ? Colors.blueAccent : theme.colorScheme.onSurface,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cell.icon != null) ...[
                Icon(
                  cell.icon,
                  size: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  cell.time == null ? cell.label : '${cell.label} · ${cell.time}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cell.badge != null) ...[
                _CellBadge(label: cell.badge!),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: _MeasuredFitText(
                  cell.value,
                  minFontSize: _valueMinFontSize,
                  maxFontSize: _valueMaxFontSize,
                  style: valueStyle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small pill badge for a post/station code inside a now/next value (e.g.
/// "2a") — visually lighter than `StationNumberBadge` since it sits inline
/// with text rather than as a standalone list marker.
class _CellBadge extends StatelessWidget {
  const _CellBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: scheme.primary,
        ),
      ),
    );
  }
}

/// Auto-sizes [text] to the largest font in `[minFontSize, maxFontSize]`
/// that fits the available width within [maxLines] — a `TextPainter`-
/// measured fit, not a floor-less `FittedBox`/`BoxFit.scaleDown`. When
/// even [minFontSize] does not fit, renders at [minFontSize] and
/// ellipsizes rather than clipping mid-word or shrinking further.
class _MeasuredFitText extends StatelessWidget {
  const _MeasuredFitText(
    this.text, {
    required this.minFontSize,
    required this.maxFontSize,
    required this.style,
  });

  final String text;
  final double minFontSize;
  final double maxFontSize;
  final TextStyle style;

  static const int maxLines = 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        var fontSize = minFontSize;
        if (maxWidth.isFinite) {
          for (
            var candidate = maxFontSize;
            candidate >= minFontSize;
            candidate -= 1
          ) {
            final painter = TextPainter(
              text: TextSpan(
                text: text,
                style: style.copyWith(fontSize: candidate),
              ),
              maxLines: maxLines,
              textDirection: Directionality.of(context),
              textAlign: TextAlign.center,
            )..layout(maxWidth: maxWidth);
            if (!painter.didExceedMaxLines) {
              fontSize = candidate;
              break;
            }
          }
        } else {
          fontSize = maxFontSize;
        }
        return Text(
          text,
          textAlign: TextAlign.center,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(fontSize: fontSize),
        );
      },
    );
  }
}
