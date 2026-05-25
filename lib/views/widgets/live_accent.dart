import 'package:flutter/material.dart';

/// Shared design tokens for the "blue live" accent used on cards whose
/// underlying exercise is currently being executed.
///
/// The accent originated on the team detail screen (see
/// `_ExerciseSection` in `team_screen.dart`) and was duplicated across
/// the Exercises, Stations and RolePlays tabs. This class collects the
/// four tokens those call sites all reach for so the look stays
/// consistent when we tweak it later.
///
/// When `isLive` is `false`, every field is `null` and the accent is
/// effectively a no-op. Callers can pass any field straight to a
/// widget's `color`/`style`/etc. without conditional logic, because
/// `null` means "no override".
///
/// Hand the accent to [ExpandableTile.accent] to apply the treatment
/// to a full row, or read the individual fields when styling nested
/// widgets manually.
@immutable
class LiveAccent {
  const LiveAccent.inactive()
      : background = null,
        foreground = null,
        iconColor = null,
        shape = null;

  const LiveAccent._({
    required this.background,
    required this.foreground,
    required this.iconColor,
    required this.shape,
  });

  /// Card background colour. Matches `colorScheme.primaryContainer`.
  final Color? background;

  /// Recommended text colour for content sitting on [background].
  /// Matches `colorScheme.onPrimaryContainer`.
  final Color? foreground;

  /// Colour for the live indicator icon (and any other accent glyph).
  /// Matches `colorScheme.primary` so it pops against [background].
  final Color? iconColor;

  /// Card shape with the primary-coloured border. Use it on `Card.shape`
  /// (or [ExpandableTile.accent] applies it automatically).
  final ShapeBorder? shape;

  /// Returns `true` when the accent is meant to be visible. Convenient
  /// for `if (accent.isActive) ...` branches that decide whether to
  /// render extra adornments like a leading icon.
  bool get isActive => background != null;

  /// Optional [TextStyle] that paints text in [foreground]. Returns
  /// `null` when the accent is inactive so callers can pass it directly
  /// to `Text(style: ...)` without an `if`.
  TextStyle? get textStyle =>
      foreground == null ? null : TextStyle(color: foreground);

  /// Canonical "this is the live one" indicator. Returns `null` when
  /// the accent is inactive so callers can drop it straight into a
  /// `leading:` slot that accepts an optional [Widget].
  Widget? get indicator => iconColor == null
      ? null
      : Icon(Icons.play_circle_fill, color: iconColor);

  /// Builds the live accent for the given `BuildContext`. When
  /// `isLive` is `false`, returns [LiveAccent.inactive] so the same
  /// expression can be reused regardless of state.
  factory LiveAccent.of(BuildContext context, {required bool isLive}) {
    if (!isLive) return const LiveAccent.inactive();
    final scheme = Theme.of(context).colorScheme;
    return LiveAccent._(
      background: scheme.primaryContainer,
      foreground: scheme.onPrimaryContainer,
      iconColor: scheme.primary,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: scheme.primary, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
