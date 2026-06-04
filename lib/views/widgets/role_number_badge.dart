import 'package:flutter/material.dart';

/// Compact square showing a formatted role label (e.g. "1.2" or "1b").
/// Mirrors [StationNumberBadge] so the two badges look like a family, but uses
/// the tertiary colour swatch so role and station rows stay visually
/// distinguishable when they sit next to each other.
class RoleNumberBadge extends StatelessWidget {
  const RoleNumberBadge({super.key, required this.label, this.highlight = false});

  final String label;
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
        color: highlight ? scheme.tertiary : scheme.surfaceContainerHighest,
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
            color: highlight ? scheme.onTertiary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
