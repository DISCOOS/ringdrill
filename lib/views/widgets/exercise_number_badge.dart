import 'package:flutter/material.dart';

/// Compact badge showing a formatted exercise label (e.g. `#1`).
///
/// Sibling of `StationNumberBadge` and `RoleNumberBadge`. The three badges
/// form a visual family — same corner radius, same typography, same padding —
/// so users can quickly distinguish exercise / station / role tokens at a
/// glance.
///
/// [label] is the already-formatted string from `Numbering.exercise(...)`.
///
/// [highlight] paints the pill with `colorScheme.primary` / `onPrimary` to
/// match `StationNumberBadge.highlight`. The mini-bar always passes
/// `highlight: false` because the surrounding `LiveAccent` background already
/// carries the "live" signal.
///
/// [size] controls the width and height of the badge. The default 40 matches
/// the badge family used in list contexts (StationNumberBadge, RoleNumberBadge).
/// Smaller values exist for embedded contexts — specifically the DrillPlayer
/// mini-bar passes 36 to match the 36×36 play square on the right.
/// FittedBox handles the scale-down so the font does not need to be threaded
/// through size.
class ExerciseNumberBadge extends StatelessWidget {
  const ExerciseNumberBadge({
    super.key,
    required this.label,
    this.highlight = false,
    this.size = 40,
  });

  final String label;
  final bool highlight;

  /// Width and height of the badge in logical pixels. Default 40 matches the
  /// badge family. Pass 36 for the DrillPlayer mini-bar context.
  final double size;

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
      width: size,
      height: size,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
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
