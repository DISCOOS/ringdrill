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

  /// Below this, the full column does not fit and the compact caption is used
  /// instead. Roughly the disc, two lines of title and body, and a button.
  static const double _fullColumnMinHeight = 160;

  @override
  Widget build(BuildContext context) {
    return MapPlaceholder(
      height: height,
      icon: icon,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // maxHeight is unbounded in a scrolling slot that passed no height; the
          // full column is right there — it is the short *bounded* slot that
          // cannot take it.
          final tooShort =
              constraints.hasBoundedHeight &&
              constraints.maxHeight < _fullColumnMinHeight;
          return tooShort ? _compact(context) : _full(context);
        },
      ),
    );
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

  Widget _full(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.secondaryContainer,
              ),
              child: Icon(icon, size: 26, color: scheme.onSecondaryContainer),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              // The mockup's 32ch measure: a body that runs the full width of an
              // expanded pane is harder to read than one that wraps early.
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.55,
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
      padding: const EdgeInsets.only(top: 14),
      child: (onAction == null && disabledTooltip != null)
          ? Tooltip(message: disabledTooltip!, child: button)
          : button,
    );
  }
}
