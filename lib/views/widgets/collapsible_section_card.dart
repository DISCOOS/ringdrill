import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/views/widgets/card_section_header.dart';
import 'package:ringdrill/views/widgets/collapse_chevron.dart';
import 'package:ringdrill/views/widgets/collapsible_section_store.dart';

/// Shared collapsible wrapper for every titled section card built on
/// [CardSectionHeader] (Postbeskrivelse, Personer, Lokasjoner, Tidsplan/
/// Når aktiv, Markørordre, ...): a [Card] with a tappable header — tapping
/// anywhere in the header (or its own [CollapseChevron]) folds [body] away
/// with an [AnimatedSize], leaving just the header (icon, title, any
/// [trailing] action) visible. State is remembered per [sectionId] via
/// [CollapsibleSectionStore] — never the localized [title], which is not a
/// stable key. `PlayerStatusCard` does not use this wrapper; it is never
/// collapsible.
class CollapsibleSectionCard extends StatefulWidget {
  const CollapsibleSectionCard({
    super.key,
    required this.sectionId,
    this.icon,
    this.title,
    this.headerBuilder,
    this.trailing,
    required this.body,
    this.margin = const EdgeInsets.only(bottom: 8),
    this.dividedBody = false,
  }) : assert(
         headerBuilder != null || (icon != null && title != null),
         'Provide either a headerBuilder or an icon + title for the default '
         'header.',
       );

  /// Stable identifier for the persisted collapsed preference — chosen by
  /// the caller, distinct per kind of card (e.g. `schedule`,
  /// `activeSchedule`), not the localized [title].
  final String sectionId;

  /// Icon + title for the default [CardSectionHeader]. Ignored (and may be
  /// null) when [headerBuilder] supplies a custom header instead.
  final IconData? icon;
  final String? title;

  /// Optional custom header content, built with the current collapsed state
  /// so callers can vary what the collapsed header shows (e.g. the Spill
  /// identity card's "(Fornavn)" parenthesis). It occupies the header's main
  /// slot; the wrapper still supplies the shared padding, bottom divider,
  /// [trailing] slot and the collapse chevron, so custom headers read as the
  /// same family as the icon+title ones. When null, the default
  /// [CardSectionHeader] built from [icon] + [title] is used.
  final Widget Function(bool collapsed)? headerBuilder;

  /// Extra header content shown before the collapse chevron (e.g. the
  /// Personer/Lokasjoner cards' "+ Legg til" action) — already its own tap
  /// target, so tapping it does not also toggle the collapse state.
  final Widget? trailing;

  final Widget body;
  final EdgeInsetsGeometry margin;

  /// Set when [body] is a list whose own first row already draws a
  /// leading (top) divider — e.g. the Post viewer's Personer/Lokasjoner
  /// cards. The header's own bottom border would otherwise double up with
  /// that row's, producing a visibly thicker/doubled line right under the
  /// header. Ignored while collapsed, where the header never draws a
  /// border regardless (there is nothing below it to divide from).
  final bool dividedBody;

  @override
  State<CollapsibleSectionCard> createState() =>
      _CollapsibleSectionCardState();
}

class _CollapsibleSectionCardState extends State<CollapsibleSectionCard> {
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCollapsed());
  }

  Future<void> _loadCollapsed() async {
    final stored = await CollapsibleSectionStore.isCollapsed(
      widget.sectionId,
    );
    if (!mounted || stored == _collapsed) return;
    setState(() => _collapsed = stored);
  }

  void _toggle() {
    final next = !_collapsed;
    setState(() => _collapsed = next);
    unawaited(CollapsibleSectionStore.setCollapsed(widget.sectionId, next));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showBorder = !_collapsed && !widget.dividedBody;
    final trailingRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?widget.trailing,
        if (widget.trailing != null) const SizedBox(width: 4),
        CollapseChevron(collapsed: _collapsed, onTap: _toggle),
      ],
    );

    // A custom header reuses the shared chrome (same padding, bottom
    // divider, trailing slot + chevron) so it reads as one family with the
    // icon+title headers; otherwise the default CardSectionHeader is used.
    final Widget header = widget.headerBuilder != null
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: showBorder
                  ? Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Expanded(child: widget.headerBuilder!(_collapsed)),
                trailingRow,
              ],
            ),
          )
        : CardSectionHeader(
            icon: widget.icon!,
            title: widget.title!,
            showBottomBorder: showBorder,
            trailing: trailingRow,
          );

    return Card(
      elevation: 1,
      margin: widget.margin,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(onTap: _toggle, child: header),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _collapsed ? const SizedBox.shrink() : widget.body,
          ),
        ],
      ),
    );
  }
}
