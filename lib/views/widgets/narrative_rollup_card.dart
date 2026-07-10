import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/brief_markdown.dart';
import 'package:ringdrill/views/widgets/brief_theme.dart';
import 'package:ringdrill/views/widgets/card_section_header.dart';
import 'package:ringdrill/views/widgets/resolve_scoped_field.dart';

/// One section of a [NarrativeRollupCard]: a label, the raw (unresolved)
/// text, and this field's own resolve context — the same per-field shape
/// `RollupSection` (`section_rollup.dart`) carries for the entity editor's
/// own rollup, minus the live `TextEditingController` (this card renders a
/// saved, no-longer-editable value, not a live-typing preview).
class NarrativeSection {
  const NarrativeSection({
    required this.id,
    required this.label,
    required this.text,
    this.overrides = const {},
    this.roleplayFacets,
    this.gated = false,
  });

  final String id;
  final String label;
  final String? text;
  final Map<String, String> overrides;
  final Map<String, dynamic>? roleplayFacets;

  /// Shows the [AppLocalizations.directorOnlyBadge] pill next to this
  /// section's heading. The caller decides *whether to include this
  /// section at all* based on the settings role (ADR-0048/DESIGN-004) —
  /// this flag only controls the pill, so a gated section already omitted
  /// by the caller never needs it set.
  final bool gated;
}

/// DESIGN-010 stage 3b's concrete rollup: a `Card` with an icon+title
/// header (optionally a lead paragraph with no heading), then each
/// [NarrativeSection] resolved via `resolveScopedField` (ADR-0048) and
/// rendered as markdown via `BriefMarkdownBlock` — "the rollup made
/// concrete" for the Post viewer's Postbeskrivelse card and the Spill
/// viewer's Markørordre card. An empty (all-blank) lead/section is skipped
/// entirely, same as the editor's own `SectionRollup`; a card with nothing
/// resolved at all renders nothing (the caller should omit it).
///
/// Deliberately not built on `SectionRollup` itself: that widget renders a
/// section's label *inside* the markdown string (a single `## label\n\nbody`
/// block) with no slot for [NarrativeSection.gated]'s pill, and is scoped to
/// the entity editor's own live-controller preview. This card resolves a
/// saved value once per build and needs the pill, so it renders each
/// section's heading as its own `Text` (with the pill alongside) and only
/// the resolved body through `BriefMarkdownBlock` — the same two primitives
/// (`resolveScopedField`, `BriefMarkdownBlock`), composed differently.
class NarrativeRollupCard extends StatelessWidget {
  const NarrativeRollupCard({
    super.key,
    required this.icon,
    required this.title,
    this.leadText,
    this.leadOverrides = const {},
    this.leadRoleplayFacets,
    this.leadId,
    this.sections = const [],
    this.onTapSection,
    this.showHint = false,
  });

  final IconData icon;
  final String title;

  /// The entity's own lead text (`Station.description`), rendered with no
  /// heading — the mockup's `.lead` block. Null/empty omits it.
  final String? leadText;
  final Map<String, String> leadOverrides;
  final Map<String, dynamic>? leadRoleplayFacets;

  /// Section id passed to [onTapSection] when the lead block is tapped.
  /// Null (no lead, or the caller doesn't support tap-to-edit) disables the
  /// tap on the lead block.
  final String? leadId;

  final List<NarrativeSection> sections;

  /// Called with a section's (or the lead's) id when its block is tapped.
  /// Null disables tap-to-edit entirely (every block renders without an
  /// `InkWell`).
  final ValueChanged<String>? onTapSection;

  /// Shows [AppLocalizations.tapSectionToEditHint] under the last block —
  /// only meaningful when [onTapSection] is non-null.
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = BriefTheme.of(context);
    final blocks = <Widget>[];

    if (leadText != null && leadText!.isNotEmpty) {
      final resolved =
          resolveScopedField(
            context,
            leadText,
            overrides: leadOverrides,
            roleplayFacets: leadRoleplayFacets,
          ) ??
          '';
      if (resolved.trim().isNotEmpty) {
        blocks.add(
          _tappable(
            id: leadId,
            child: BriefMarkdownBlock(data: resolved, theme: theme, gutter: 0),
          ),
        );
      }
    }

    for (final section in sections) {
      final text = section.text;
      if (text == null || text.isEmpty) continue;
      final resolved =
          resolveScopedField(
            context,
            text,
            overrides: section.overrides,
            roleplayFacets: section.roleplayFacets,
          ) ??
          '';
      if (resolved.trim().isEmpty) continue;
      blocks.add(
        _tappable(
          id: section.id,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      section.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (section.gated) ...[
                    const SizedBox(width: 6),
                    _GateBadge(label: l10n.directorOnlyBadge),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              BriefMarkdownBlock(data: resolved, theme: theme, gutter: 0),
            ],
          ),
        ),
      );
    }

    if (blocks.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardSectionHeader(icon: icon, title: title),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final block in blocks) ...[
                  block,
                  const SizedBox(height: 12),
                ],
                if (showHint && onTapSection != null)
                  Row(
                    children: [
                      Icon(
                        Icons.edit,
                        size: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        l10n.tapSectionToEditHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tappable({required String? id, required Widget child}) {
    if (id == null || onTapSection == null) return child;
    return InkWell(onTap: () => onTapSection!(id), child: child);
  }
}

class _GateBadge extends StatelessWidget {
  const _GateBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.visibility_off_outlined,
            size: 11,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
