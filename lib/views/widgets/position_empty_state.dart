import 'package:flutter/material.dart';
import 'package:ringdrill/views/widgets/map_placeholder.dart';

/// The teaching empty state for a map slot with no position to plot.
///
/// Three surfaces used to answer "no position" three different ways — a bare
/// `Posisjon … Ingen posisjon` row, stretched to half a screen in the expanded
/// detail pane, or a one-line `MapPlaceholder` caption. None of them said why it
/// matters or offered a way forward, so this one does both: what is lost (the
/// station is missing from the map, and the brief chapter gets no coordinate) and
/// the action that fixes it.
///
/// Built on [MapPlaceholder] so the chrome is shared with a set position — same
/// radius, same tonal map tone — because the point is that switching between set
/// and unset does not read as two different components.
///
/// The icon-disc/title/body/tonal-button shape is lifted from
/// `TeachingEmptyState` rather than reused from it: this needs a *disabled* button
/// with a tooltip (an action that exists but is unavailable right now reads
/// differently from no action at all), and a compact fallback when the slot is too
/// short for the full column. Both would have changed `TeachingEmptyState` for its
/// existing callers.
class PositionEmptyState extends StatelessWidget {
  const PositionEmptyState({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.add_location_alt_outlined,
    this.height,
    this.actionLabel,
    this.onAction,
    this.disabledTooltip,
  });

  final String title;
  final String body;
  final IconData icon;

  /// Forwarded to [MapPlaceholder]: an explicit height for a fixed slot, or null
  /// to fill a height-bounded parent.
  final double? height;

  /// Null renders no button at all — a viewer gets the explanation without a dead
  /// affordance.
  final String? actionLabel;

  /// Null with an [actionLabel] set renders the button *disabled*, which is how a
  /// running exercise is shown: the action exists, just not now.
  final VoidCallback? onAction;

  /// Why the action is unavailable, on the disabled button.
  final String? disabledTooltip;

  // Fixed parts of the full column, for the fit calculation below.
  static const double _vPad = 12;
  static const double _hPad = 20;
  static const double _discSize = 48;
  static const double _discGap = 8;
  static const double _titleGap = 4;
  static const double _actionGap = 10;
  static const double _actionHeight = 40;
  static const double _bodyMaxWidth = 300;

  @override
  Widget build(BuildContext context) {
    return MapPlaceholder(
      height: height,
      icon: icon,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The tier is chosen by *measuring* the copy, not by a height threshold.
          // Thresholds were tuned to the station's two-line body and then clipped
          // the markør's three-line one; the slot has a fixed height and does not
          // grow the way the mockup's `min-height` does, so the layout has to know
          // what it actually needs. Dropping the disc buys 56 px, which is the
          // difference between the two.
          //
          // An unbounded slot (a scrolling column that passed no height) always gets
          // the full column: it is the *bounded* short slot that cannot take it.
          if (!constraints.hasBoundedHeight) {
            return _full(context, withDisc: true);
          }
          final available = constraints.maxHeight;
          final textWidth = (constraints.maxWidth - _hPad * 2).clamp(
            0.0,
            _bodyMaxWidth,
          );
          final needed = _neededHeight(context, textWidth);
          if (available >= needed) return _full(context, withDisc: true);
          if (available >= needed - _discSize - _discGap) {
            return _full(context, withDisc: false);
          }
          return _compact(context);
        },
      ),
    );
  }

  /// What the full column needs at [textWidth], disc included.
  double _neededHeight(BuildContext context, double textWidth) {
    final theme = Theme.of(context);
    double measure(String text, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textAlign: TextAlign.center,
      )..layout(maxWidth: textWidth);
      return painter.height;
    }

    return _vPad * 2 +
        _discSize +
        _discGap +
        measure(title, theme.textTheme.titleSmall) +
        _titleGap +
        measure(body, theme.textTheme.bodySmall?.copyWith(height: 1.4)) +
        (actionLabel == null ? 0 : _actionGap + _actionHeight);
  }

  Widget _compact(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _full(BuildContext context, {required bool withDisc}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Sized to fit a 190 px thumbnail slot — the panels' default `mapHeight` is 200,
    // and the slot does not grow the way the mockup's `min-height` does, so a
    // generous column clipped its own button. Measured: 24 padding + 48 disc + 8 +
    // title + 4 + two body lines + 10 + button ≈ 184.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: _hPad, vertical: _vPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (withDisc) ...[
              Container(
                width: _discSize,
                height: _discSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.secondaryContainer,
                ),
                child: Icon(icon, size: 24, color: scheme.onSecondaryContainer),
              ),
              const SizedBox(height: _discGap),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: _titleGap),
            ConstrainedBox(
              // The mockup's 32ch measure: a body that runs the full width of an
              // expanded pane is harder to read than one that wraps early.
              constraints: const BoxConstraints(maxWidth: _bodyMaxWidth),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            ?_action(),
          ],
        ),
      ),
    );
  }

  Widget? _action() {
    final label = actionLabel;
    if (label == null) return null;
    final button = FilledButton.tonal(onPressed: onAction, child: Text(label));
    return Padding(
      padding: const EdgeInsets.only(top: _actionGap),
      child: (onAction == null && disabledTooltip != null)
          ? Tooltip(message: disabledTooltip!, child: button)
          : button,
    );
  }
}
