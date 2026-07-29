import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/brief_markdown.dart';
import 'package:ringdrill/views/widgets/collapsible_section_card.dart';
import 'package:ringdrill/views/widgets/ringdrill_text.dart';
import 'package:ringdrill/views/widgets/section_header.dart';
import 'package:ringdrill/views/widgets/section_navigated_form.dart';
import 'package:ringdrill/views/widgets/teaching_empty_state.dart';

/// One section's contribution to a [RollupSection]: a label (rendered
/// as a heading above the resolved content) plus the raw text resolved against
/// the scope cascade every time the rollup rebuilds.
class RollupSection {
  const RollupSection({
    required this.id,
    required this.text,
    this.label,
    this.gated = false,
    this.mandatoryLabel,
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

  /// Non-null marks this as a section the *surface* expects to be filled: a
  /// blank one is called out by name in a teaching nudge under the rollup
  /// instead of being silently omitted the way an ordinary optional section
  /// is.
  ///
  /// Nothing in the model enforces this, and nothing should: every one of
  /// these fields is an `OptionalFieldSection` in its editor, and an exercise
  /// with no method or a post with no description still saves, publishes and
  /// prints. This is only a claim about which section a *reader* needs in
  /// order to make sense of the entity — so the author is told, not stopped.
  ///
  /// The value is the localized name shown in the nudge. It cannot simply be
  /// [label]: a lead section (a station's or roleplay's own `description`)
  /// renders no heading of its own and so has no label to borrow.
  final String? mandatoryLabel;

  bool get isMandatory => mandatoryLabel != null;

  /// Whether this section resolved to anything worth rendering — the single
  /// definition of "has content" shared by the block builder (which omits an
  /// empty section) and the mandatory-section nudge (which reports one).
  bool get hasText => text?.isNotEmpty == true;
}

/// The per-entity teaching copy a rollup shows in place of its body when
/// nothing at all has been written yet — an exercise's "no method, no comms,
/// no learning goals" card, a fresh post, an uncast roleplay.
///
/// Supplied by the caller rather than derived here because only the caller
/// knows *what kind of thing* is missing: "describe the situation, mission
/// and equipment at the post" is useful, "this section is empty" is not.
class RollupTeaching {
  const RollupTeaching({
    required this.title,
    required this.body,
    required this.actionLabel,
    this.icon = Icons.description_outlined,
  });

  final String title;
  final String body;

  /// Label for the button that opens the editor. Rendered only when the
  /// rollup has an `onTapSection` to route it through — a read-only surface
  /// shows the explanation without an affordance it cannot honour.
  final String actionLabel;

  final IconData icon;
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
    this.teaching,
  });

  /// Shows a hint under the last block
  final Widget? hint;

  /// Replaces the whole body with a teaching empty state when no section has
  /// content. Null keeps the bare behaviour — an empty rollup takes no space
  /// at all.
  final RollupTeaching? teaching;

  final List<RollupSection> sections;

  /// Called with a section's id when the author taps its rendered block —
  /// wire to `SectionNavigator.of(context)!.selectSection`.
  final ValueChanged<String>? onTapSection;

  @override
  Widget build(BuildContext context) {
    List<Widget> blocks = _buildSectionBlocks(sections, onTapSection);

    if (blocks.isEmpty) {
      // Nothing resolved at all: the body becomes the teaching state, so an
      // author landing on a fresh entity reads what belongs here instead of a
      // blank pane. The base section's preview is a whole-section swap
      // (DESIGN-010, revised 2026-07-10), which is the same need.
      final teaching = this.teaching;
      if (teaching == null) return const SizedBox.shrink();
      return _buildTeaching(context, teaching, sections, onTapSection);
    }

    return Column(
      spacing: 8.0,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...blocks,
        ?_buildMissingNudge(context, sections, onTapSection),
        ?_buildHint(context, hint),
      ],
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
    this.teaching,
    this.trailing,
  });

  final String title;
  final IconData icon;

  /// Shows a hint under the last block
  final Widget? hint;

  /// Replaces the card body with a teaching empty state when no section has
  /// content. Null keeps the bare behaviour — a card with an empty body, which
  /// is what the description cards used to render on a fresh entity.
  final RollupTeaching? teaching;

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

  /// Header action shown before the collapse chevron, e.g. the exercise
  /// viewer's copy-to-clipboard. Passed through to
  /// [CollapsibleSectionCard.trailing], which already reserves that slot, so a
  /// card action does not need to be floated over the body.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    List<Widget> blocks = _buildSectionBlocks(sections, onTapSection);

    if (blocks.isEmpty) {
      final teaching = this.teaching;
      if (teaching == null) return _buildCard(const SizedBox.shrink());
      // `padded: false` — TeachingEmptyState brings its own (larger, centered)
      // padding, and stacking the body's 12 on top of its 32 pinches the copy
      // into a narrow column on a compact card.
      return _buildCard(
        _buildTeaching(context, teaching, sections, onTapSection),
        padded: false,
      );
    }

    return _buildCard(
      Column(
        // Stretch, not start: a block's own column shrink-wraps to its widest
        // line otherwise, which both narrows its tap-to-edit InkWell to the
        // text and leaves a short block sitting in a box narrower than the
        // card.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          ...blocks,
          ?_buildMissingNudge(context, sections, onTapSection),
          ?_buildHint(context, hint),
        ],
      ),
    );
  }

  Widget _buildCard(Widget child, {bool padded = true}) {
    return CollapsibleSectionCard(
      sectionId: sectionId,
      icon: icon,
      title: title,
      trailing: trailing,
      body: padded
          ? Padding(
              // 12 on all four sides: the horizontal matches
              // [CardSectionHeader]'s own inset, so a section's label lines up
              // with the card title above it, and the vertical is the same gap
              // the `spacing` puts between blocks — the body previously had
              // none at the top and only an accidental trailing `SizedBox` at
              // the bottom.
              padding: const EdgeInsets.all(12),
              child: child,
            )
          : child,
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
    if (!section.hasText) continue;
    final text = section.text!;
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

/// The whole-body empty state: [TeachingEmptyState] carrying the caller's
/// per-entity copy, with its action wired to the editor when the surface is
/// editable at all.
Widget _buildTeaching(
  BuildContext context,
  RollupTeaching teaching,
  List<RollupSection> sections,
  ValueChanged<String>? onTapSection,
) {
  final target = _teachingTarget(sections);
  // No `onTapSection` means this surface cannot edit (a published plan read by
  // a participant): keep the explanation, drop the button — an invitation to
  // "add a description" that goes nowhere is worse than none.
  final onAction = onTapSection == null || target == null
      ? null
      : () => onTapSection(target);
  return TeachingEmptyState(
    icon: teaching.icon,
    title: teaching.title,
    body: teaching.body,
    actionLabel: onAction == null ? null : teaching.actionLabel,
    onAction: onAction,
  );
}

/// Which section the empty state's own action opens: the first the surface
/// marked mandatory, else simply the first. An author with nothing written
/// should land on the section that matters most, not on whatever the editor
/// happens to list first.
String? _teachingTarget(List<RollupSection> sections) {
  for (final section in sections) {
    if (section.isMandatory) return section.id;
  }
  return sections.isEmpty ? null : sections.first.id;
}

/// The partial-content counterpart to [_buildTeaching]: some sections resolved,
/// but a [RollupSection.mandatoryLabel] one is still blank. Null when nothing
/// mandatory is missing — the common case, which must cost nothing.
///
/// Deliberately additive rather than a body swap: the author *has* written
/// something here, and replacing it with an empty state would hide their own
/// content to nag them about the rest.
Widget? _buildMissingNudge(
  BuildContext context,
  List<RollupSection> sections,
  ValueChanged<String>? onTapSection,
) {
  final missing = [
    for (final section in sections)
      if (section.isMandatory && !section.hasText) section,
  ];
  if (missing.isEmpty) return null;
  // Absent in a bare test harness; the nudge is entirely localized copy, so
  // there is nothing to render without it.
  final l10n = AppLocalizations.of(context);
  if (l10n == null) return null;
  return _MissingSectionsNudge(
    text: l10n.descriptionMissingSections(
      missing.map((section) => section.mandatoryLabel!).join(', '),
    ),
    actionLabel: l10n.descriptionMissingSectionsAction,
    onTap: onTapSection == null ? null : () => onTapSection(missing.first.id),
  );
}

/// One muted, tinted row naming the mandatory sections a rollup is still
/// missing, with an inline action into the editor's first such section.
///
/// Sized and coloured as an aside, not an error: a blank Metode is a planning
/// to-do, not a validation failure, and the card it sits under is a reading
/// surface the author may be visiting for entirely different reasons.
class _MissingSectionsNudge extends StatelessWidget {
  const _MissingSectionsNudge({
    required this.text,
    required this.actionLabel,
    this.onTap,
  });

  final String text;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (onTap != null)
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }
}

Widget? _buildHint(BuildContext context, Widget? child) {
  if (child == null) return null;
  return Column(children: [Divider(height: 16), child]);
}
