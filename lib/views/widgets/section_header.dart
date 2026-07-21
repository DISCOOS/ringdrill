import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/gate_badge.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.text, {
    super.key,
    this.gated = false,
    this.trailing,
  });

  final String text;
  final Widget? trailing;

  /// Shows the [AppLocalizations.directorOnlyBadge] pill next to this
  /// section's heading. The caller decides *whether to include this
  /// section at all* based on the settings role (ADR-0048/DESIGN-004) —
  /// this flag only controls the pill, so a gated section already omitted
  /// by the caller never needs it set.
  final bool gated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Row(
      spacing: 6.0,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        ?trailing,
        if (gated) ...[
          const SizedBox(width: 6),
          GateBadge(label: l10n.directorOnlyBadge),
        ],
      ],
    );
  }
}
