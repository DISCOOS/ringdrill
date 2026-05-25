import 'package:flutter/material.dart';

/// Compact square showing a short station code (e.g. "A2", "1.3").
///
/// Used in the Stations list, station mini map, and anywhere the app
/// needs a small "this is station X of exercise Y" chip. When
/// [highlight] is true the badge switches to the primary colour
/// swatch so callers can flag the station that belongs to a running
/// exercise (matching the live-accent treatment elsewhere).
class StationCodeBadge extends StatelessWidget {
  const StationCodeBadge({
    super.key,
    required this.code,
    this.highlight = false,
  });

  final String code;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: highlight ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      // FittedBox scales the text down for longer codes like "10.25"
      // without resizing the badge, so all rows stay vertically
      // aligned.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          code,
          maxLines: 1,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: highlight ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
