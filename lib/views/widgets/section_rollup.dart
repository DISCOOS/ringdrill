import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
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
    this.roleplayFacets,
  });

  final String id;
  final String label;
  final TextEditingController controller;
  final Map<String, String> overrides;
  final Map<String, dynamic>? roleplayFacets;
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
            roleplayFacets: s.roleplayFacets,
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
            ),
          ),
        ),
      );
    }
    if (blocks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: blocks,
    );
  }
}

/// Composes an entity editor's default-section body with the DESIGN-010
/// rollup toggle and, when shown, the rollup itself — shared by the
/// Exercise/Station/RolePlay editors so the narrow/wide layout split lives
/// in one place. [fields] is the editor's existing default-section body
/// (its own `SafeArea`/scroll/`Column` of structural fields), passed
/// through unchanged.
///
/// Narrow ([WindowSizeClass.hasMasterDetail] false): an inline continuation
/// — [fields], the toggle, then (if shown) the rollup, all inside one outer
/// scroll (nesting `fields`' own scroll view inside it is safe: given
/// unbounded height it sizes to its content instead of scrolling
/// independently, so the whole thing reads as a single page).
///
/// Wide: a side-by-side pane — [fields] on the left (still scrolling on its
/// own within its bounded half), the rollup on the right in its own
/// scrollable pane, split like the master/detail layout (ADR-0030).
Widget withSectionRollup({
  required BuildContext context,
  required Widget fields,
  required List<RollupSection> rollupSections,
  required bool showRollup,
  required ValueChanged<bool> onShowRollupChanged,
}) {
  final l10n = AppLocalizations.of(context)!;
  final toggle = Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => onShowRollupChanged(!showRollup),
        icon: Icon(
          showRollup
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
        ),
        label: Text(showRollup ? l10n.rollupHideAction : l10n.rollupShowAction),
      ),
    ),
  );

  final rollup = SectionRollup(
    sections: rollupSections,
    onTapSection: (id) => SectionNavigator.maybeOf(context)?.selectSection(id),
  );

  if (!WindowSizeClass.of(context).hasMasterDetail) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          fields,
          toggle,
          if (showRollup)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: rollup,
            ),
        ],
      ),
    );
  }

  return Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Column(
          children: [
            Expanded(child: fields),
            toggle,
          ],
        ),
      ),
      if (showRollup) ...[
        const VerticalDivider(width: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: rollup,
          ),
        ),
      ],
    ],
  );
}
