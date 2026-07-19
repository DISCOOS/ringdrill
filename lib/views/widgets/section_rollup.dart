import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/brief_markdown.dart';
import 'package:ringdrill/views/widgets/brief_theme.dart';
import 'package:ringdrill/views/widgets/resolve_scoped_field.dart';
import 'package:ringdrill/views/widgets/section_navigated_form.dart';

/// One section's contribution to a [SectionRollup]: a label (rendered as a
/// heading above the resolved content) plus the live [controller] whose
/// text resolves against the scope cascade every time the rollup rebuilds.
class RollupSection {
  const RollupSection({
    required this.id,
    required this.label,
    required this.controller,
    this.overrides = const {},
  });

  final String id;
  final String label;
  final TextEditingController controller;
  final Map<String, String> overrides;
}

/// The read-only rollup under an entity editor's default section
/// (DESIGN-010): each active section resolved via `resolveScopedField` and
/// stacked in order under its own heading, so the author sees the whole
/// post/exercise/marker as it will read without leaving the editor. Built
/// per section from the field resolver, not from `BriefRenderer.render()`
/// (which is program/exercise-scoped and cannot target a single station,
/// exercise or roleplay).
///
/// Each section renders via [BriefMarkdownBlock] — the no-own-scroll
/// sibling of [BriefMarkdown] — rather than one combined [BriefMarkdown],
/// so each block can carry its own tap-to-edit [GestureDetector] and so the
/// whole rollup participates in whatever ancestor scroll the caller gives
/// it (an outer page scroll on narrow, or its own `SingleChildScrollView`
/// wrapper the caller adds for the wide side-by-side pane) instead of
/// nesting an independently-scrolling island inside another one.
///
/// Live with a debounce: listens to every section's own controller and
/// re-resolves shortly after the author stops typing in any of them —
/// resolution is cheap string work, but re-resolving on every keystroke
/// across every active section is still wasted work mid-edit.
class SectionRollup extends StatefulWidget {
  const SectionRollup({
    super.key,
    required this.sections,
    required this.onTapSection,
  });

  final List<RollupSection> sections;

  /// Called with a section's id when the author taps its rendered block —
  /// wire to `SectionNavigator.of(context)!.selectSection`.
  final ValueChanged<String> onTapSection;

  @override
  State<SectionRollup> createState() => _SectionRollupState();
}

class _SectionRollupState extends State<SectionRollup> {
  static const _debounceDelay = Duration(milliseconds: 200);
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    for (final s in widget.sections) {
      s.controller.addListener(_scheduleRebuild);
    }
  }

  @override
  void didUpdateWidget(SectionRollup oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldControllers = {for (final s in oldWidget.sections) s.controller};
    final newControllers = {for (final s in widget.sections) s.controller};
    for (final c in oldControllers.difference(newControllers)) {
      c.removeListener(_scheduleRebuild);
    }
    for (final c in newControllers.difference(oldControllers)) {
      c.addListener(_scheduleRebuild);
    }
  }

  void _scheduleRebuild() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final s in widget.sections) {
      s.controller.removeListener(_scheduleRebuild);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BriefTheme.of(context);
    final blocks = <Widget>[];
    for (final s in widget.sections) {
      final resolved =
          resolveScopedField(
            context,
            s.controller.text,
            overrides: s.overrides,
          ) ??
          '';
      if (resolved.trim().isEmpty) continue;
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: InkWell(
            onTap: () => widget.onTapSection(s.id),
            child: BriefMarkdownBlock(
              data: '## ${s.label}\n\n$resolved',
              theme: theme,
              // No extra gutter: withSectionRollup's own container already
              // insets this to line up with the structural fields and the
              // rollup toggle above it — BriefMarkdownBlock's default
              // (brief-page) gutter would otherwise shift it further right.
              gutter: 0,
            ),
          ),
        ),
      );
    }
    if (blocks.isEmpty) {
      // The base section's preview is a whole-section swap now (DESIGN-010,
      // revised 2026-07-10), so an empty rollup shows a muted placeholder
      // rather than a blank pane.
      final l10n = AppLocalizations.of(context)!;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          l10n.rollupEmptyPreview,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: blocks,
    );
  }
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
Widget withSectionRollup({
  required BuildContext context,
  required Widget fields,
  required List<RollupSection> rollupSections,
  required bool showRollup,
}) {
  if (!showRollup) return fields;
  return SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SectionRollup(
        sections: rollupSections,
        onTapSection: (id) =>
            SectionNavigator.maybeOf(context)?.selectSection(id),
      ),
    ),
  );
}
