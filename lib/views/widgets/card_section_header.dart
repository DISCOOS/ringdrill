import 'package:flutter/material.dart';

/// A `Card`'s own header row (DESIGN-010's Post/Spill viewers, mockup
/// `docs/design/mockups/station-and-roleplay-viewers.html`'s `.card-h`): an
/// icon, an uppercase title, and an optional trailing widget (a count or a
/// "+ Action" affordance) — shared by every card in the rebuilt viewers
/// (Postbeskrivelse, Personer, Lokasjoner, Tidsplan, Markørordre, Når
/// aktiv) so they read as one family instead of each hand-rolling its own
/// header row.
class CardSectionHeader extends StatelessWidget {
  const CardSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
