import 'package:flutter/material.dart';

/// The shared collapse/expand affordance for `CollapsibleSectionCard`'s
/// header and the position card's coordinate bar (`PositionCardShell`,
/// docs/design/mockups/collapsible-position-card.html): an
/// `Icons.expand_more` chevron that rotates to point up when expanded
/// ("tap to fold") and down when collapsed ("tap to show") — one visual
/// convention for every collapsible card in the app. Its own tap target,
/// so it can sit inside another tappable region (a header row, a
/// coordinate bar) without also triggering that region's own tap.
class CollapseChevron extends StatelessWidget {
  const CollapseChevron({
    super.key,
    required this.collapsed,
    required this.onTap,
    this.inverseColorOnCollapsed = false,
    this.padding = const EdgeInsets.all(4),
  });

  final bool collapsed;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;
  final bool inverseColorOnCollapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Padding(
        padding: padding,
        child: AnimatedRotation(
          turns: collapsed ? 0 : 0.5,
          duration: const Duration(milliseconds: 200),
          child: Icon(
            Icons.expand_more,
            size: 20,
            color: inverseColorOnCollapsed && !collapsed
                ? theme.colorScheme.onInverseSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
