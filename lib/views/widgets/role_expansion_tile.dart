import 'package:flutter/material.dart';

/// Reusable expandable tile for role (RolePlay) rows.
///
/// Mirrors [StationExpansionTile] in structure and tap-target split:
/// tapping the body area fires [onOpen] (open the role detail screen),
/// tapping the trailing chevron fires [onToggle] (expand/collapse).
/// The optional [trailing] slot sits between the body tap target and
/// the chevron, allowing callers to inject a cast-chip, action button,
/// or other inline affordance.
///
/// The [expanded] flag is owned by the parent so it can enforce a
/// mutex across rows. The widget owns the expand/collapse animation.
class RoleExpansionTile extends StatelessWidget {
  const RoleExpansionTile({
    super.key,
    required this.leading,
    required this.title,
    required this.body,
    required this.expanded,
    required this.onOpen,
    required this.onToggle,
    this.subtitle,
    this.trailing,
    this.background,
    this.border,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  static const Duration animationDuration = Duration(milliseconds: 200);

  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final Widget body;
  final bool expanded;
  final VoidCallback onOpen;
  final VoidCallback onToggle;
  final Color? background;
  final ShapeBorder? border;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      color: background,
      shape: border,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onOpen,
                  child: Padding(
                    padding: padding,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        leading,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DefaultTextStyle.merge(
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
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
              ),
              if (trailing != null) trailing!,
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
          ),
          AnimatedSize(
            duration: animationDuration,
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SizedBox(width: double.infinity, child: body),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }
}

/// Compact square showing a short role code (e.g. "1.2"). Same swatch
/// shape as [StationCodeBadge] so the two badges look like a family.
class RoleCodeBadge extends StatelessWidget {
  const RoleCodeBadge({
    super.key,
    required this.code,
    this.highlight = false,
  });

  final String code;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: highlight
            ? scheme.tertiary
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          code,
          maxLines: 1,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: highlight ? scheme.onTertiary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
