import 'package:flutter/material.dart';

/// A face glyph with a small bold badge in the upper-left corner — the actor
/// (markør) counterpart to Material's `person_add` / `person_remove`, which
/// have no "face" variants. The face (`Icons.face`) is the one-concrete-actor
/// convention; the badge (a plus for add, a minus for remove) rides the
/// corner the way Material's own `group_add` composes its plus. Reserve
/// `person_add`/`person_remove` for a *person* (the character); an actor is
/// not a person, it is who enacts one.
class _FaceBadgeIcon extends StatelessWidget {
  const _FaceBadgeIcon({
    required this.size,
    required this.color,
    required this.plus,
  });

  final double size;
  final Color? color;

  /// `true` composes a plus (add), `false` a single horizontal bar (minus,
  /// remove).
  final bool plus;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    // Keep the face large (nudged to the lower-right); the bold badge rides the
    // upper-left corner, where the circular face leaves empty space.
    final faceSize = size * 0.82;
    final badgeBox = size * 0.42;
    final bar = size * 0.13; // bold stroke thickness
    final radius = BorderRadius.circular(bar / 2);
    Widget stroke({required double w, required double h}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: fg, borderRadius: radius),
    );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.bottomRight,
            child: Icon(Icons.face, size: faceSize, color: fg),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: badgeBox,
              height: badgeBox,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  stroke(w: badgeBox, h: bar),
                  if (plus) stroke(w: bar, h: badgeBox),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Add an actor" glyph (face + plus) — for the "assign a marker" affordance
/// in bare-icon slots (the Spill tab's collapsed tile cast chip, the Spill
/// viewer's cast quick action, the cast picker's "Ny markør").
class AddFaceIcon extends StatelessWidget {
  const AddFaceIcon({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      _FaceBadgeIcon(size: size, color: color, plus: true);
}

/// "Remove the actor" glyph (face + minus) — for the cast picker's
/// "Fjern markør" (clear cast).
class RemoveFaceIcon extends StatelessWidget {
  const RemoveFaceIcon({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      _FaceBadgeIcon(size: size, color: color, plus: false);
}
