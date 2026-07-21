import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/brief_markdown.dart';
import 'package:ringdrill/views/widgets/collapsible_section_card.dart';
import 'package:ringdrill/views/widgets/ringdrill_text.dart';
import 'package:ringdrill/views/widgets/section_header.dart';
import 'package:ringdrill/views/widgets/section_navigated_form.dart';

/// One section's contribution to a [RollupSection]: a label (rendered
/// as a heading above the resolved content) plus the raw text resolved against
/// the scope cascade every time the rollup rebuilds.
class RollupSection {
  const RollupSection({
    required this.id,
    required this.text,
    this.label,
    this.gated = false,
    this.overrides = const {},
  });

  final String id;
  final String? label;
  final String? text;
  final Map<String, String> overrides;

  /// Shows the [AppLocalizations.directorOnlyBadge] pill next to this
  /// section's heading. The caller decides *whether to include this
  /// section at all* based on the settings role (ADR-0048/DESIGN-004) —
  /// this flag only controls the pill, so a gated section already omitted
  /// by the caller never needs it set.
  final bool gated;
}

/// The read-only rollup under an entity editor's default section
/// (DESIGN-010): each active section resolved via `resolveScopedField` and
/// stacked in order under its own heading, so the author sees the whole
/// station/exercise/script.
///
/// Each section renders via [BriefMarkdownBlock] — the no-own-scroll
/// sibling of [BriefMarkdown] — rather than one combined [BriefMarkdown],
/// so each block can carry its own tap-to-edit [GestureDetector] and so the
/// whole rollup participates in whatever ancestor scroll the caller gives
/// it (an outer page scroll on narrow, or its own `SingleChildScrollView`
/// wrapper the caller adds for the wide side-by-side pane) instead of
/// nesting an independently-scrolling island inside another one.
///
class Rollup extends StatelessWidget {
  const Rollup({
    super.key,
    required this.sections,
    this.hint,
    this.onTapSection,
    this.emptyPlaceholder,
  });

  /// Shows a hint under the last block
  final Widget? hint;

  /// Shows a placeholder text when no blocks are shown
  final String? emptyPlaceholder;

  final List<RollupSection> sections;

  /// Called with a section's id when the author taps its rendered block —
  /// wire to `SectionNavigator.of(context)!.selectSection`.
  final ValueChanged<String>? onTapSection;

  @override
  Widget build(BuildContext context) {
    List<Widget> blocks = _buildSectionBlocks(sections, onTapSection);

    if (emptyPlaceholder?.isNotEmpty == true && blocks.isEmpty) {
      // The base section's preview is a whole-section swap now (DESIGN-010,
      // revised 2026-07-10), so an empty rollup shows a muted placeholder
      // rather than a blank pane.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: _buildPlaceholder(context, emptyPlaceholder!),
      );
    }

    return Column(
      spacing: 8.0,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [...blocks, ?_buildHint(context, hint)],
    );
  }
}

/// DESIGN-010 stage 3b's concrete rollup: a `Card` with an icon+title
/// header (optionally a lead paragraph with no heading), then each
/// [RollupSection] resolved via `resolveScopedField` (ADR-0048) and
/// rendered as markdown via `BriefMarkdownBlock` — "the rollup made
/// concrete" for the Post viewer's Postbeskrivelse card and the Spill
/// viewer's Markørordre card. An empty (all-blank) lead/section is skipped
/// entirely, same as the editor's own `SectionRollup`; a card with nothing
/// resolved at all renders nothing (the caller should omit it).
///
/// Deliberately not built on `SectionRollup` itself: that widget renders a
/// section's label *inside* the markdown string (a single `## label\n\nbody`
/// block) with no slot for [RollupSection.gated]'s pill, and is scoped to
/// the entity editor's own live-controller preview. This card resolves a
/// saved value once per build and needs the pill, so it renders each
/// section's heading as its own `Text` (with the pill alongside) and only
/// the resolved body through `BriefMarkdownBlock` — the same two primitives
/// (`resolveScopedField`, `BriefMarkdownBlock`), composed differently.
class RollupCard extends StatelessWidget {
  const RollupCard({
    super.key,
    required this.sectionId,
    required this.icon,
    required this.title,
    this.sections = const [],
    this.hint,
    this.onTapSection,
    this.emptyPlaceholder,
  });

  final String title;
  final IconData icon;

  /// Shows a hint under the last block
  final Widget? hint;

  /// Shows a placeholder text when no blocks are shown
  final String? emptyPlaceholder;

  /// Stable identifier for the persisted collapsed preference (DESIGN-010
  /// follow-up: collapsible-section-cards) — distinct per kind of rollup
  /// card (e.g. the Post viewer's "description" vs. the Scripts viewer's
  /// "roleplay"), never [title], which is localized.
  final String sectionId;

  final List<RollupSection> sections;

  /// Called with a section's (or the lead's) id when its block is tapped.
  /// Null disables tap-to-edit entirely (every block renders without an
  /// `InkWell`).
  final ValueChanged<String>? onTapSection;

  @override
  Widget build(BuildContext context) {
    List<Widget> blocks = _buildSectionBlocks(sections, onTapSection);

    if (blocks.isEmpty && emptyPlaceholder?.isNotEmpty == true) {
      // The base section's preview is a whole-section swap now (DESIGN-010,
      // revised 2026-07-10), so an empty rollup shows a muted placeholder
      // rather than a blank pane.
      return _buildCard(_buildPlaceholder(context, emptyPlaceholder!));
    }

    return _buildCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final block in blocks) ...[block, const SizedBox(height: 12)],
          ?_buildHint(context, hint),
        ],
      ),
    );
  }

  Widget _buildCard(Widget child) {
    return CollapsibleSectionCard(
      sectionId: sectionId,
      icon: icon,
      title: title,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: child,
      ),
    );
  }

  /// Renders an entity editor's default-section body as EITHER its editable
  /// [fields] or, when [showRollup] is on, the read-only rollup preview —
  /// shared by the Exercise/Station/RolePlay editors (DESIGN-010, revised
  /// 2026-07-10). [fields] is the editor's existing default-section body (its
  /// own `SafeArea`/scroll/`Column` of structural fields), passed through
  /// unchanged.
  ///
  /// The whole section swaps between edit and preview, driven by the section's
  /// own preview toggle in the `SectionNavigatedForm` app bar (the same eye/
  /// pencil the markdown sections use) — not a separate bottom button or a
  /// side-by-side pane. The old side-by-side pane squeezed the fields on the
  /// narrower (medium) wide layouts, and the old bottom toggle was only
  /// reachable after scrolling the whole form on narrow; a full-section swap
  /// fixes both, and the rollup already includes the description/sections so
  /// it reads as a complete preview.
  static Widget withScrollable({
    required BuildContext context,
    required List<RollupSection> sections,
  }) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Rollup(
          sections: sections,
          onTapSection: (id) =>
              SectionNavigator.maybeOf(context)?.selectSection(id),
        ),
      ),
    );
  }
}

List<Widget> _buildSectionBlocks(
  List<RollupSection> sections,
  ValueChanged<String>? onTapSection,
) {
  final blocks = <Widget>[];
  for (final section in sections) {
    final text = section.text;
    if (text == null || text.isEmpty) continue;
    blocks.add(
      _buildTappable(
        id: section.id,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (section.label != null)
              SectionHeader(section.label!, gated: section.gated),
            const SizedBox(height: 2),
            RingDrillText.rich(text, overrides: section.overrides),
          ],
        ),
        onTapSection: onTapSection,
      ),
    );
  }
  return blocks;
}

Widget _buildTappable({
  required String? id,
  required Widget child,
  required ValueChanged<String>? onTapSection,
}) {
  if (id == null || onTapSection == null) return child;
  return InkWell(onTap: () => onTapSection(id), child: child);
}

Widget _buildPlaceholder(BuildContext context, String placeholder) {
  return Text(
    placeholder,
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

Widget? _buildHint(BuildContext context, Widget? child) {
  if (child == null) return null;
  return Column(children: [Divider(height: 16), child]);
}
