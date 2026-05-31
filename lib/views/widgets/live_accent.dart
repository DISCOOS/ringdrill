import 'package:flutter/material.dart';
import 'package:ringdrill/theme.dart';

/// Shared design tokens for the "orange live" accent used on cards whose
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

  /// Card background colour. Warm peach in light, deep warm brown in
  /// dark. Pairs with a [brandAccent] border so the running state reads
  /// as a distinct warm accent against the cool teal surroundings.
  final Color? background;

  /// Recommended text colour for content sitting on [background].
  /// Dark teal in light mode, white in dark mode.
  final Color? foreground;

  /// Colour for the live indicator icon (and any other accent glyph).
  /// Always [RingDrillColors.brandAccent] (orange) so it pops on the
  /// warm background regardless of theme.
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
  ///
  /// The accent is colour-coded on [RingDrillColors.brandAccent]
  /// (orange) — the brand's canonical "live / active marker" tone — so
  /// running cards read as a distinct warm accent against the cool teal
  /// surrounding cards (regular and selected).
  factory LiveAccent.of(BuildContext context, {required bool isLive}) {
    if (!isLive) return const LiveAccent.inactive();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LiveAccent._(
      background: isDark
          ? RingDrillColors.liveBackgroundDark
          : RingDrillColors.liveBackgroundLight,
      // White on the dark warm background; the brand's `onTertiary` dark
      // brown on the light warm background. Both keep AA contrast.
      foreground: isDark ? Colors.white : const Color(0xFF1A0F00),
      iconColor: RingDrillColors.brandAccent,
      shape: RoundedRectangleBorder(
        side: const BorderSide(
          color: RingDrillColors.brandAccent,
          width: 2.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
