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
    required this.icon,
    required this.title,
    this.trailing,
    required this.body,
    this.margin = const EdgeInsets.only(bottom: 8),
  });

  /// Stable identifier for the persisted collapsed preference — chosen by
  /// the caller, distinct per kind of card (e.g. `schedule`,
  /// `activeSchedule`), not the localized [title].
  final String sectionId;

  final IconData icon;
  final String title;

  /// Extra header content shown before the collapse chevron (e.g. the
  /// Personer/Lokasjoner cards' "+ Legg til" action) — already its own tap
  /// target, so tapping it does not also toggle the collapse state.
  final Widget? trailing;

  final Widget body;
  final EdgeInsetsGeometry margin;

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
    return Card(
      elevation: 1,
      margin: widget.margin,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _toggle,
            child: CardSectionHeader(
              icon: widget.icon,
              title: widget.title,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ?widget.trailing,
                  if (widget.trailing != null) const SizedBox(width: 4),
                  CollapseChevron(collapsed: _collapsed, onTap: _toggle),
                ],
              ),
            ),
          ),
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
