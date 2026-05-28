import 'package:flutter/material.dart';

/// Compact badge showing an exercise number as `#N`.
///
/// Sibling of `StationCodeBadge` and `RoleCodeBadge`. The three badges form
/// a visual family — same dimensions, same typography, same corner radius —
/// so users can quickly distinguish exercise / station / role tokens at a
/// glance.
///
/// [highlight] paints the pill with `colorScheme.primary` / `onPrimary` to
/// match `StationCodeBadge.highlight`. The mini-bar always passes
/// `highlight: false` because the surrounding `LiveAccent` background already
/// carries the "live" signal.
class ExerciseNumberBadge extends StatelessWidget {
  const ExerciseNumberBadge({
    super.key,
    required this.number,
    this.highlight = false,
  });

  final int number;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color background;
    final Color foreground;
    if (highlight) {
      background = scheme.primary;
      foreground = scheme.onPrimary;
    } else {
      background = scheme.surfaceContainerHighest;
      foreground = scheme.onSurface;
    }

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '#$number',
          maxLines: 1,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
        ),
      ),
    );
  }
}
