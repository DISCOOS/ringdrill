import 'package:flutter/material.dart';
import 'package:ringdrill/views/widgets/live_accent.dart';

/// Card-style row with an optional expandable [body] section.
///
/// All expandables in the app (Exercises, Stations, Team, RolePlays)
/// share this widget so they pick up the same hover/focus/ripple
/// behaviour, the same live-accent treatment, and the same animation
/// when the body opens or closes.
///
/// Tap targets follow the standard "list row" pattern. The chevron is
/// always its own `IconButton`, so tapping it never fires [onOpen].
/// The rest of the row sits inside one big [InkWell] so the hover
/// tint covers the whole header (including the chevron strip) instead
/// of stopping at the chevron edge.
///
/// Two interaction modes:
///  * [onOpen] non-null — tapping the row fires [onOpen] (e.g. push
///    the detail screen) and tapping the chevron fires [onToggle].
///    Used by Stations, Exercises and RolePlays.
///  * [onOpen] null — tapping the row fires [onToggle] instead.
///    Used by Team's exercise sections where the row itself is the
///    expand affordance.
///
/// The chevron is rendered only when both [body] and [onToggle] are
/// provided. When [body] is null the tile is a plain header with no
/// expand affordance.
class ExpandableTile extends StatelessWidget {
  const ExpandableTile({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.body,
    this.expanded = false,
    this.selected = false,
    this.onOpen,
    this.onToggle,
    this.accent = const LiveAccent.inactive(),
    this.margin = const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
    this.elevation = 2,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  static const Duration animationDuration = Duration(milliseconds: 200);

  /// Required header title. Wrapped in a `DefaultTextStyle` that gives
  /// it a `fontSize: 16, fontWeight: w600` baseline. Callers can pass
  /// a `Text` with their own style to override.
  final Widget title;

  /// Optional leading widget. Typically a code badge or status icon.
  /// The 12-pixel gap to the title is added only when leading is set.
  final Widget? leading;

  /// Optional subtitle below [title]. Wrapped in a `DefaultTextStyle`
  /// that paints it in `onSurfaceVariant` at 13 px.
  final Widget? subtitle;

  /// Optional widget that sits between the title block and the chevron.
  /// Used for inline affordances like a Switch in the export picker or
  /// a cast chip in the roleplay tile.
  final Widget? trailing;

  /// Optional content shown below the header when [expanded] is true.
  /// When null, the tile has no expand affordance.
  final Widget? body;

  /// Whether [body] is currently visible. Owned by the parent so it
  /// can enforce a mutex across rows.
  final bool expanded;

  /// Whether this tile is the currently selected item in a master-detail
  /// layout. When `true` and [accent] is inactive, applies a subtle
  /// `surfaceContainerHighest` background with an `outlineVariant` border.
  /// Ignored when [accent] is active (live styling takes priority).
  final bool selected;

  /// Fires when the row body is tapped. When null, row taps fall
  /// through to [onToggle] (or do nothing if both are null).
  final VoidCallback? onOpen;

  /// Fires when the chevron is tapped, or when the whole row is tapped
  /// while [onOpen] is null.
  final VoidCallback? onToggle;

  /// Live-accent treatment. Defaults to [LiveAccent.inactive] which is
  /// a no-op. Use [LiveAccent.of] to derive the active treatment from
  /// an `isLive` flag at the call site.
  final LiveAccent accent;

  final EdgeInsetsGeometry? margin;
  final double? elevation;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final hasBody = body != null;
    final canToggle = hasBody && onToggle != null;
    // Row-tap fires onOpen when supplied, otherwise toggles, otherwise
    // does nothing. The InkWell still renders hover feedback whenever
    // a row-tap action is wired up.
    final rowTap = onOpen ?? (canToggle ? onToggle : null);

    final scheme = Theme.of(context).colorScheme;
    final useSelected = selected && !accent.isActive;
    return Card(
      elevation: elevation,
      margin: margin,
      color: useSelected ? scheme.surfaceContainerHighest : accent.background,
      shape: useSelected
          ? RoundedRectangleBorder(
              side: BorderSide(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            )
          : accent.shape,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: rowTap,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Padding(
                    padding: padding,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (leading != null) ...[
                          leading!,
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DefaultTextStyle.merge(
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                child: title,
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 2),
                                DefaultTextStyle.merge(
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  child: subtitle!,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: trailing!,
                  ),
                if (canToggle) ...[
                  IconButton(
                    onPressed: onToggle,
                    icon: AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: animationDuration,
                      child: const Icon(Icons.expand_more),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
          ),
          if (hasBody)
            AnimatedSize(
              duration: animationDuration,
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SizedBox(width: double.infinity, child: body!),
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
        ],
      ),
    );
  }
}
