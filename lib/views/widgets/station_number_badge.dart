import 'package:flutter/material.dart';

/// Compact square showing a formatted station label (e.g. "1.3" or "1c").
///
/// Used in the Stations list, station mini map, and anywhere the app
/// needs a small "this is station X of exercise Y" chip.
///
/// Two visual states stack on top of the neutral base:
///
/// * [highlight] (primary swatch) flags the station that belongs to a
///   currently running exercise — matches the live-accent treatment
///   used elsewhere.
/// * [hasRoles] (tertiary swatch) flags that at least one [RolePlay]
///   ("markør") is attached to this station. Mirrors how
///   [RoleNumberBadge.highlight] paints a cast role in the Roleplays tab,
///   so the same "yellow pill" signal works at the station level for
///   directors and instructors.
///
/// When [highlight] wins on the background (live state), [hasRoles]
/// surfaces as a small tertiary dot in the top-right corner so the
/// markør signal is never lost behind the live colour.
class StationNumberBadge extends StatelessWidget {
  const StationNumberBadge({
    super.key,
    required this.label,
    this.highlight = false,
    this.hasRoles = false,
  });

  final String label;
  final bool highlight;
  final bool hasRoles;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color background;
    final Color foreground;
    if (highlight) {
      background = scheme.primary;
      foreground = scheme.onPrimary;
    } else if (hasRoles) {
      background = scheme.tertiary;
      foreground = scheme.onTertiary;
    } else {
      background = scheme.surfaceContainerHighest;
      foreground = scheme.onSurface;
    }
    // Show the dot only when the background can't already carry the
    // hasRoles signal — i.e., when [highlight] is on and the pill is
    // painted with the primary swatch. On a tertiary background the dot
    // would be the same colour as the pill and would just read as a
    // ring, which is noisy without adding information.
    final showDot = hasRoles && highlight;

    final pill = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      // FittedBox scales the text down for longer codes like "10.25"
      // without resizing the badge, so all rows stay vertically
      // aligned.
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

    if (!showDot) return pill;

    // Stack the dot in the top-right corner. The thin surface-coloured
    // border keeps it readable against any background colour the pill
    // might take in the future (e.g. dark theme primary).
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        children: [
          pill,
          Positioned(
            top: 3,
            right: 3,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.tertiary,
                border: Border.all(color: scheme.surface, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
