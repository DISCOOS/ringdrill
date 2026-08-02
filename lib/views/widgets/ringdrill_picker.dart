import 'package:flutter/material.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';

/// ADR-0049's single "pick one from a list" primitive: a bottom sheet on
/// compact windows, a dialog reusing the form-dialog's rounded chrome on
/// medium/expanded — the same [WindowSizeClass.hasMasterDetail] split
/// [showRingdrillFormDialog]'s callers already use for editors.
///
/// [itemBuilder] renders one row per item; call the row's `onTap` to resolve
/// this call with that item (the primitive pops the surface for you).
/// Dismissing without choosing resolves `null`.
///
/// [searchText] maps an item to the text a live, case-insensitive `contains`
/// filter runs against; leaving it `null` disables search entirely. When
/// set, the search field only renders once [items] reaches [searchThreshold]
/// — short lists don't need one.
///
/// [sectionLabel] groups the list: whenever consecutive items yield a different
/// label, a header for the new group is rendered above the row. Grouping is
/// applied to the *filtered* items, so a search never leaves a header stranded
/// above a group whose rows were all filtered out, nor hides the header of a
/// group that still has matches — which is why this belongs here and not in a
/// caller's `itemBuilder`. Items must already be ordered by group. Null (the
/// default) renders a flat list.
///
/// [filters] narrow the list by *what kind* of item it is, where [searchText]
/// narrows by what an item is called (ADR-0067). An implicit "all" option comes
/// first and is selected initially, so a picker that passes filters still opens
/// showing everything. A filter matching nothing is dimmed rather than removed —
/// removing it would make the row jump around while the author types — and stays
/// selectable, since "show me that category, even though it is empty here" is a
/// reasonable thing to ask; the caller's own entries then say why it is empty.
///
/// Two presentations of the one parameter, chosen the same way the surface itself
/// is: a wrapping chip row under the search field on compact, and a master rail
/// beside the list on medium/expanded (ADR-0030's wide-screen idiom, the one the
/// plan tab and the station list already read as). Chips wrap rather than scroll,
/// because eight categories take two lines on a phone and all of them stay
/// visible, where a sideways row hides the last few without saying they exist.
/// Not a `SegmentedButton`: `StaffRoleFilter`'s doc comment is this app's record
/// of what long Norwegian labels do to one, and a segmented button is view
/// selection here, not list filtering.
///
/// With a single filter active on the wide layout the section headers drop, since
/// the selected rail entry *is* the header at that point. On compact they stay: a
/// chip row is not a header.
///
/// [footerActions] are appended below the list (e.g. a "+ New person" row).
/// They are ordinary widgets built by the caller with the caller's own
/// `context`, so a footer action that needs to dismiss the picker pops via
/// that same `context` — safe here since the app has a single Navigator
/// (ADR-0027/0030), so `Navigator.of(callerContext)` always resolves to
/// whichever Navigator this picker was just pushed onto, sheet or dialog.
Future<T?> showRingdrillPicker<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required Widget Function(BuildContext context, T item, VoidCallback onTap)
  itemBuilder,
  String Function(T item)? searchText,
  String? searchHint,
  int searchThreshold = 8,
  String? Function(T item)? sectionLabel,
  List<PickerFilter<T>> filters = const [],
  String? allFilterLabel,
  String? subtitle,
  List<Widget> footerActions = const [],
}) {
  // Drop focus before pushing. When the picker's route pops, Flutter restores focus
  // to whatever had it — and if that was a text field further up a scrollable form,
  // restoring it calls `Scrollable.ensureVisible` and the form jumps back to that
  // field. In the parallel-group editor that meant every team added below the fold
  // cost the author a scroll back down.
  //
  // Here rather than at the five call sites: none of them wants focus preserved
  // across a modal, and the app already drops it on tap-outside (`DismissKeyboard`),
  // so this is the same rule applied to the same kind of gesture.
  //
  // `primaryFocus`, not `FocusScope.of(context).unfocus()` — which is what
  // `DismissKeyboard` uses and which does *not* work here. That call only detaches
  // focus when the scope it resolves to is the one currently holding it, and the
  // scope enclosing a row deep in a form is not. Dropping the primary focus is
  // unconditional, and unconditional is what this needs.
  FocusManager.instance.primaryFocus?.unfocus();

  final wide = WindowSizeClass.of(context).hasMasterDetail;
  Widget builder(BuildContext context) => _RingdrillPickerBody<T>(
    title: title,
    subtitle: subtitle,
    items: items,
    itemBuilder: itemBuilder,
    searchText: searchText,
    searchHint: searchHint,
    searchThreshold: searchThreshold,
    sectionLabel: sectionLabel,
    filters: filters,
    allFilterLabel: allFilterLabel,
    footerActions: footerActions,
    showCloseButton: wide,
    wide: wide,
  );

  if (wide) {
    return showRingdrillDialogShell<T>(
      context: context,
      builder: builder,
      // The rail needs room beside the list, and a filtered picker is a longer
      // read than a list of station names.
      maxWidth: filters.isEmpty ? 480 : 680,
      maxHeightFraction: filters.isEmpty ? 0.7 : 0.8,
    );
  }
  return showRingdrillActionSheet<T>(context: context, builder: builder);
}

/// One category an item may belong to, for [showRingdrillPicker]'s `filters`.
///
/// A predicate rather than a key, so a caller whose categories do not partition
/// its items (an item in two of them) needs no special case.
class PickerFilter<T> {
  const PickerFilter({required this.label, required this.matches});

  /// Names the category. Singular: a filter names a kind, it does not count one.
  final String label;

  final bool Function(T item) matches;
}

class _RingdrillPickerBody<T> extends StatefulWidget {
  const _RingdrillPickerBody({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.itemBuilder,
    required this.searchText,
    required this.searchHint,
    required this.searchThreshold,
    required this.sectionLabel,
    required this.filters,
    required this.allFilterLabel,
    required this.footerActions,
    required this.showCloseButton,
    required this.wide,
  });

  final String title;
  final String? subtitle;
  final List<T> items;
  final Widget Function(BuildContext context, T item, VoidCallback onTap)
  itemBuilder;
  final String Function(T item)? searchText;
  final String? searchHint;
  final int searchThreshold;
  final String? Function(T item)? sectionLabel;
  final List<PickerFilter<T>> filters;
  final String? allFilterLabel;
  final List<Widget> footerActions;
  final bool showCloseButton;
  final bool wide;

  @override
  State<_RingdrillPickerBody<T>> createState() =>
      _RingdrillPickerBodyState<T>();
}

class _RingdrillPickerBodyState<T> extends State<_RingdrillPickerBody<T>> {
  final _searchController = TextEditingController();
  String _query = '';

  /// Index into `widget.filters`, or null for the implicit "all".
  int? _filter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Items matching the search text, before the category filter.
  ///
  /// Kept separate because the filter chips report emptiness against *this* list:
  /// a category is dimmed when the current search has no hits in it, which is a
  /// statement about the search and not about the whole picker.
  List<T> get _searched {
    final searchText = widget.searchText;
    if (searchText == null || _query.isEmpty) return widget.items;
    final q = _query.toLowerCase();
    return widget.items
        .where((item) => searchText(item).toLowerCase().contains(q))
        .toList();
  }

  List<T> get _filtered {
    final index = _filter;
    if (index == null || index >= widget.filters.length) return _searched;
    final matches = widget.filters[index].matches;
    return _searched.where(matches).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showSearch =
        widget.searchText != null &&
        widget.items.length >= widget.searchThreshold;
    final filtered = _filtered;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(widget.title, style: theme.textTheme.titleMedium),
              ),
              if (widget.subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    widget.subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (widget.showCloseButton)
                IconButton(
                  key: const Key('ringdrill-picker-close'),
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ),
        // Separate the title header from the list/search so it reads as a
        // header and not as another list item.
        const Divider(height: 1),
        if (showSearch)
          Padding(
            // Symmetric 8: with top 0 the field sat flush against the divider
            // under the title. `CastPickerSheet`, which mirrors this layout by
            // hand, has always used 8 — this was the odd one out.
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const Key('ringdrill-picker-search'),
              controller: _searchController,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        if (widget.filters.isNotEmpty && !widget.wide) _chips(theme),
        if (widget.filters.isNotEmpty && widget.wide) ...[
          const Divider(height: 1),
          Flexible(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _rail(theme),
                const VerticalDivider(width: 1),
                Expanded(child: _list(theme, filtered)),
              ],
            ),
          ),
        ] else
          Flexible(child: _list(theme, filtered)),
        if (widget.footerActions.isNotEmpty) ...[
          const Divider(height: 1),
          ...widget.footerActions,
        ],
      ],
    );
  }

  /// Whether a section header should be drawn at all.
  ///
  /// On the wide layout with one category selected, the rail entry is already the
  /// header, and repeating it above the rows says the same word twice. With "all"
  /// selected the headers are what tells the categories apart, so they stay.
  bool get _showSectionHeaders =>
      widget.sectionLabel != null && !(widget.wide && _filter != null);

  Widget _list(ThemeData theme, List<T> filtered) => ListView.builder(
    shrinkWrap: true,
    itemCount: filtered.length,
    itemBuilder: (context, index) {
      final item = filtered[index];
      final row = widget.itemBuilder(
        context,
        item,
        () => Navigator.of(context).pop(item),
      );
      if (!_showSectionHeaders) return row;
      final label = widget.sectionLabel?.call(item);
      // Header on the first row of each group — computed against the filtered
      // list, so search regroups rather than stranding headers.
      final isGroupStart =
          label != null &&
          (index == 0 ||
              widget.sectionLabel?.call(filtered[index - 1]) != label);
      if (!isGroupStart) return row;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (index > 0) const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(label, style: _sectionStyle(theme)),
          ),
          row,
        ],
      );
    },
  );

  TextStyle? _sectionStyle(ThemeData theme) =>
      theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      );

  /// True when the current search leaves this category nothing to show. Dimmed,
  /// not removed, and still selectable.
  bool _isEmpty(int? index) => index == null
      ? _searched.isEmpty
      : !_searched.any(widget.filters[index].matches);

  Widget _chips(ThemeData theme) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = -1; i < widget.filters.length; i++)
          _chip(theme, i < 0 ? null : i),
      ],
    ),
  );

  Widget _chip(ThemeData theme, int? index) {
    final empty = _isEmpty(index);
    final label = index == null
        ? (widget.allFilterLabel ?? '')
        : widget.filters[index].label;
    return FilterChip(
      key: Key('ringdrill-picker-filter-${index ?? 'all'}'),
      label: Text(label),
      selected: _filter == index,
      onSelected: (_) => setState(() => _filter = index),
      visualDensity: VisualDensity.compact,
      labelStyle: empty
          ? TextStyle(color: theme.colorScheme.onSurfaceVariant)
          : null,
    );
  }

  Widget _rail(ThemeData theme) => SizedBox(
    width: 132,
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = -1; i < widget.filters.length; i++)
            _railEntry(theme, i < 0 ? null : i),
        ],
      ),
    ),
  );

  Widget _railEntry(ThemeData theme, int? index) {
    final selected = _filter == index;
    final empty = _isEmpty(index);
    final label = index == null
        ? (widget.allFilterLabel ?? '')
        : widget.filters[index].label;
    return InkWell(
      key: Key('ringdrill-picker-filter-${index ?? 'all'}'),
      onTap: () => setState(() => _filter = index),
      child: Container(
        color: selected ? theme.colorScheme.secondaryContainer : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: selected ? FontWeight.w700 : null,
            color: empty && !selected
                ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
                : null,
          ),
        ),
      ),
    );
  }
}
