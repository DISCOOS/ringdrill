import 'package:flutter/material.dart';

/// The three states a [CastPill] can carry (DESIGN-012).
enum CastPillVariant {
  /// No [RolePlay] exists for this person yet — the pill creates one.
  add,

  /// A [RolePlay] exists but has no cast [Actor] — the pill opens the cast
  /// picker.
  uncast,

  /// A [RolePlay] exists and is cast — the pill opens the cast picker to
  /// change/clear the cast.
  cast,
}

/// The single trailing "cast pill" shared by the Post detail viewer's Persons
/// card and the Post list's actor rows (`StationRoleSummary`), per
/// `docs/design/012-unified-cast-pill.md`.
///
/// It carries the actor state as an icon + text: a `face` glyph
/// (`Icons.face`, the one-concrete-actor convention) on the two cast states,
/// and a plain `+` on the add state — a face there would be too close to the
/// cast states, and expressing "add" in words avoids ever needing an
/// "add face" glyph. Two-masks stays on the section header, naming the list.
///
/// [onTap] null renders a non-interactive indicator (the read-only
/// `StationRoleSummary` call sites — plan/coordinator detail).
class CastPill extends StatelessWidget {
  const CastPill({
    super.key,
    required this.variant,
    required this.label,
    this.onTap,
  });

  final CastPillVariant variant;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final Color foreground;
    final Color? background;
    final IconData icon;
    switch (variant) {
      case CastPillVariant.add:
        foreground = scheme.primary;
        background = null;
        icon = Icons.add;
      case CastPillVariant.uncast:
        foreground = scheme.onSurfaceVariant;
        background = scheme.surfaceContainerHighest;
        icon = Icons.face;
      case CastPillVariant.cast:
        foreground = scheme.primary;
        background = scheme.primaryContainer.withValues(alpha: 0.4);
        icon = Icons.face;
    }
    final isAdd = variant == CastPillVariant.add;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: isAdd ? 15 : 14, color: foreground),
        SizedBox(width: isAdd ? 4 : 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: foreground),
          ),
        ),
      ],
    );

    // The add state is a bare inline link (no chip background); the two cast
    // states are filled/muted chips, matching the mockup.
    final body = background == null
        ? content
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: content,
          );

    if (onTap == null) return body;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: body,
    );
  }
}
