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
    this.showBottomBorder = true,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  /// Whether to draw the divider under the title row. Callers set this to
  /// `false` when there is nothing below to divide from — a collapsed
  /// [CollapsibleSectionCard] (mockup `.headclosed{border-bottom:none}`) or
  /// a body that already draws its own leading divider (a list of
  /// top-bordered rows), where the header's own border would otherwise
  /// double up with the body's first one.
  final bool showBottomBorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: showBottomBorder
            ? Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              )
            : null,
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

/// The icon + title row shared by [CardSectionHeader] and the collapse-aware
/// `headerBuilder` headers (the Spill/Post/Når aktiv cards, which append a
/// collapsed-state summary to the kicker). Just the leading content that
/// fills the header's main slot — the `CollapsibleSectionCard` wrapper
/// supplies the padding, bottom divider, trailing slot and collapse chevron —
/// so a custom header reads exactly like the default one.
///
/// [title] is rendered as-is (no uppercasing): the caller upper-cases the
/// kicker word itself and leaves any appended summary (a post name, a time
/// span) in its natural case.
Widget kickerHeaderContent(
  BuildContext context, {
  required IconData icon,
  required String title,
}) {
  final theme = Theme.of(context);
  return Row(
    children: [
      Icon(icon, size: 18, color: theme.colorScheme.primary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
      ),
    ],
  );
}
