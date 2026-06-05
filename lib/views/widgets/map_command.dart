import 'package:flutter/material.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';

/// Visual size of a [MapCommand]. [compact] renders a 40 dp container
/// (Material 3 "small" FAB) while [regular] renders the standard 56 dp FAB.
///
/// Both sizes keep a 48 dp minimum touch target via
/// [MaterialTapTargetSize.padded] so shrinking the visual does not regress
/// accessibility on touch devices.
enum MapCommandSize {
  compact,
  regular;

  /// Resolve the size from the ambient window-size class: phones and other
  /// [WindowSizeClass.compact] layouts get the smaller control so the
  /// overlay stops crowding the map, while medium/expanded keep the larger
  /// target that pairs better with a pointer.
  static MapCommandSize of(BuildContext context) =>
      WindowSizeClass.of(context) == WindowSizeClass.compact
      ? MapCommandSize.compact
      : MapCommandSize.regular;

  double get diameter => switch (this) {
    MapCommandSize.compact => 40,
    MapCommandSize.regular => 56,
  };

  double get iconSize => switch (this) {
    MapCommandSize.compact => 22,
    MapCommandSize.regular => 24,
  };

  /// Side of the square box reserved for the indeterminate spinner that
  /// replaces the icon while a command is busy.
  double get spinnerSize => switch (this) {
    MapCommandSize.compact => 18,
    MapCommandSize.regular => 24,
  };

  /// Side of the (possibly invisible) tap target. A small FAB keeps the
  /// Material 48 dp minimum even though its visible circle is only 40 dp.
  double get tapTarget => diameter < 48 ? 48 : diameter;

  /// Gap between the widget's layout box and its visible circle, caused by
  /// the padded tap target. Other overlays use this to line up with the
  /// *visible* control rather than its larger hit box.
  double get tapInset => (tapTarget - diameter) / 2;
}

/// Emphasis level of a [MapCommand].
///
/// [tonal] is the default for controls layered over a map: a
/// surface-container fill with a low elevation reads as a "tool" and keeps
/// the map itself the loudest thing on screen. [primary] keeps the classic
/// brand-coloured FAB for the rare case a map control really is the primary
/// action.
enum MapCommandEmphasis {
  tonal,
  primary;

  /// Container fill for this emphasis. Exposed so other map overlays (e.g.
  /// the search field) can match a command's background exactly instead of
  /// hardcoding the same token in two places.
  ///
  /// In dark mode the tonal fill steps up to the lightest neutral container
  /// so the controls sit clearly above the dark map, the way Google Maps
  /// lifts its dark-mode controls off the basemap. Light mode is unchanged.
  Color background(ColorScheme scheme) => switch (this) {
    MapCommandEmphasis.tonal => scheme.brightness == Brightness.dark
        ? scheme.surfaceContainerHighest
        : scheme.surfaceContainerHigh,
    MapCommandEmphasis.primary => scheme.primaryContainer,
  };

  /// Foreground (icon/text) colour paired with [background].
  Color foreground(ColorScheme scheme) => switch (this) {
    MapCommandEmphasis.tonal => scheme.onSurface,
    MapCommandEmphasis.primary => scheme.onPrimaryContainer,
  };

  double get elevation => switch (this) {
    MapCommandEmphasis.tonal => 1.0,
    MapCommandEmphasis.primary => 3.0,
  };
}

/// A domain-agnostic, [FloatingActionButton]-styled control meant to float
/// over a [MapView]. Centralises sizing, touch-target, emphasis and badge
/// handling so both the built-in map controls and feature-supplied commands
/// (e.g. a filter button passed through `topRightCommands`) stay visually
/// consistent and shrink together on compact layouts.
///
/// Each command must carry a unique [heroTag] because several may be stacked
/// in the same overlay column.
class MapCommand extends StatelessWidget {
  const MapCommand({
    super.key,
    required this.heroTag,
    required this.onPressed,
    this.icon,
    this.child,
    this.tooltip,
    this.size,
    this.emphasis = MapCommandEmphasis.tonal,
    this.badgeCount = 0,
  }) : assert(
         icon != null || child != null,
         'Provide either an icon or a child',
       );

  /// Unique hero tag. Stacked commands would otherwise share the default FAB
  /// tag and throw at runtime.
  final Object heroTag;

  /// Tapped callback. When null the command renders disabled.
  final VoidCallback? onPressed;

  /// Icon rendered when [child] is not supplied.
  final IconData? icon;

  /// Custom content rendered instead of [icon] (e.g. a progress spinner).
  /// When set, the caller owns sizing of its own child.
  final Widget? child;

  final String? tooltip;

  /// Overrides the size that would otherwise be derived from the window-size
  /// class. Leave null to follow [MapCommandSize.of].
  final MapCommandSize? size;

  final MapCommandEmphasis emphasis;

  /// When greater than zero, a count badge is layered on the command.
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolved = size ?? MapCommandSize.of(context);

    final background = emphasis.background(scheme);
    final foreground = emphasis.foreground(scheme);
    final elevation = emphasis.elevation;

    final content =
        child ?? Icon(icon, size: resolved.iconSize, color: foreground);

    final Widget fab = switch (resolved) {
      MapCommandSize.compact => FloatingActionButton.small(
        heroTag: heroTag,
        tooltip: tooltip,
        onPressed: onPressed,
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: elevation,
        // Keep the tap area at the Material 48 dp minimum even though the
        // visible container is only 40 dp.
        materialTapTargetSize: MaterialTapTargetSize.padded,
        child: content,
      ),
      MapCommandSize.regular => FloatingActionButton(
        heroTag: heroTag,
        tooltip: tooltip,
        onPressed: onPressed,
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: elevation,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        child: content,
      ),
    };

    if (badgeCount <= 0) return fab;
    return Badge.count(count: badgeCount, child: fab);
  }
}
