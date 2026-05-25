import 'package:flutter/material.dart';

/// Rounded-square icon for a role-play position marker.
///
/// Visually distinct from the station's green [Icons.place] pin: uses a
/// rounded rectangle with a [Icons.theater_comedy] glyph in the theme's
/// tertiary container colour. A heavier border weight signals that this is
/// a statically-placed roleplayer position.
///
/// Does **not** render a label. Label rendering is owned by [MapView] via
/// its zoom-gated label slot, so this widget is purely the icon part.
class RoleMarker extends StatelessWidget {
  const RoleMarker({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: 0.85,
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: scheme.tertiary, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 2,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.theater_comedy,
            color: scheme.onTertiaryContainer,
            size: size / 2,
          ),
        ),
      ),
    );
  }
}
