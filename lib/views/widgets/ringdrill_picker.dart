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
  List<Widget> footerActions = const [],
}) {
  final wide = WindowSizeClass.of(context).hasMasterDetail;
  Widget builder(BuildContext context) => _RingdrillPickerBody<T>(
    title: title,
    items: items,
    itemBuilder: itemBuilder,
    searchText: searchText,
    searchHint: searchHint,
    searchThreshold: searchThreshold,
    footerActions: footerActions,
    showCloseButton: wide,
  );

  if (wide) {
    return showRingdrillDialogShell<T>(
      context: context,
      builder: builder,
      maxWidth: 480,
      maxHeightFraction: 0.7,
    );
  }
  return showRingdrillActionSheet<T>(context: context, builder: builder);
}

class _RingdrillPickerBody<T> extends StatefulWidget {
  const _RingdrillPickerBody({
    required this.title,
    required this.items,
    required this.itemBuilder,
    required this.searchText,
    required this.searchHint,
    required this.searchThreshold,
    required this.footerActions,
    required this.showCloseButton,
  });

  final String title;
  final List<T> items;
  final Widget Function(BuildContext context, T item, VoidCallback onTap)
  itemBuilder;
  final String Function(T item)? searchText;
  final String? searchHint;
  final int searchThreshold;
  final List<Widget> footerActions;
  final bool showCloseButton;

  @override
  State<_RingdrillPickerBody<T>> createState() =>
      _RingdrillPickerBodyState<T>();
}

class _RingdrillPickerBodyState<T> extends State<_RingdrillPickerBody<T>> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<T> get _filtered {
    final searchText = widget.searchText;
    if (searchText == null || _query.isEmpty) return widget.items;
    final q = _query.toLowerCase();
    return widget.items
        .where((item) => searchText(item).toLowerCase().contains(q))
        .toList();
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
              if (widget.showCloseButton)
                IconButton(
                  key: const Key('ringdrill-picker-close'),
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ),
        if (showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final item = filtered[index];
              return widget.itemBuilder(
                context,
                item,
                () => Navigator.of(context).pop(item),
              );
            },
          ),
        ),
        if (widget.footerActions.isNotEmpty) ...[
          const Divider(height: 1),
          ...widget.footerActions,
        ],
      ],
    );
  }
}
