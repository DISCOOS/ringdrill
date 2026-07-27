import 'package:flutter/material.dart';
import 'package:ringdrill/views/widgets/station_number_badge.dart';

/// Compact square showing a team's 1-based number.
///
/// The fourth member of the badge family ([StationNumberBadge],
/// `ExerciseNumberBadge`, `RoleNumberBadge`) — same corner radius, typography
/// and padding, so the four read as one set.
///
/// Unlike its siblings it uses the secondary swatch as its *base*, not only when
/// highlighted. The other three share a neutral base and are told apart by their
/// label format (`#1` / `1.2` / `1.2-1`); a team's label is a bare number, which
/// is too close to `#1` to carry the distinction on its own. The DrillPlayer's
/// mini bar depends on the badge alone to say which mode it is in (ADR-0056), so
/// teams get a colour of their own — echoing DESIGN-001, which already assigns
/// teams a distinct identity colour in the player model.
class TeamNumberBadge extends StatelessWidget {
  const TeamNumberBadge({
    super.key,
    required this.label,
    this.highlight = false,
    this.size = 40,
  });

  final String label;
  final bool highlight;

  /// Width and height in logical pixels. See [StationNumberBadge.size].
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: highlight ? scheme.primary : scheme.secondaryContainer,
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
            color: highlight
                ? scheme.onPrimary
                : scheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
