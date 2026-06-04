import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';

/// A sort-action descriptor: a flat [TextButton] label and the callback to
/// fire when the user taps it. Sort actions are one-shot (they apply once and
/// leave reorder mode untouched); only the reorder toggle is a sticky mode.
typedef SortAction = ({String label, VoidCallback onPressed});

/// A generic, list-agnostic reorder section used by the Exercises, Stations
/// and Coordinator lists (ADR-0036).
///
/// ## Behaviour summary
///
/// **Default mode** (≥ 2 items, [enabled] true): a muted [orderLabel] on the
/// left, optional one-shot [sortActions] as flat [TextButton]s, and an
/// outlined "Reorder" toggle (`OutlinedButton.icon`, `Icons.swap_vert`).
/// Below the header the list is rendered by [itemBuilder] in default mode.
///
/// **Reorder mode**: the header collapses to a single "Done"
/// [FilledButton.tonal]; the list swaps to a [ReorderableListView] with
/// `buildDefaultDragHandles: false`. A trailing [ReorderableDragStartListener]
/// drag handle is passed into [itemBuilder] as the `dragHandle` argument; the
/// `reordering` flag lets the host suppress row tap/swipe/long-press gestures.
///
/// **Deferred commit**: drags mutate an in-memory working copy synchronously
/// so [ReorderableListView] animates to the dropped slot without snapping
/// back. [onCommitReorder] is fired exactly once, when the user leaves reorder
/// mode, not on every drop (ADR-0035 §"Deferred commit", ADR-0036).
///
/// **< 2 items**: the whole header strip collapses to nothing.
///
/// **[enabled] false**: the reorder toggle is hidden (e.g. while an exercise
/// is running) but the sort actions remain.
///
/// ## Reorder-mode flag ownership
///
/// If the host supplies [reorderMode], this widget listens to it and lets the
/// host flip it externally (e.g. `exerciseReorderMode` on the
/// `ProgramPageControllerBase` so a segment switch can force-exit reorder
/// mode). When [reorderMode] is null, the widget owns an internal notifier.
class ReorderableSection<T> extends StatefulWidget {
  const ReorderableSection({
    super.key,
    required this.items,
    required this.keyOf,
    required this.itemBuilder,
    required this.onCommitReorder,
    required this.orderLabel,
    this.sortActions = const [],
    this.enabled = true,
    this.reorderMode,
    this.shrinkWrap = false,
  });

  /// The ordered list of items to display.
  final List<T> items;

  /// Returns a stable [Key] for an item, used to key rows in both modes.
  final Key Function(T item) keyOf;

  /// Builds a row for [item] at [position] (0-based).
  ///
  /// [reordering] is true while reorder mode is active; the host should
  /// suppress tap/swipe/long-press when true. [dragHandle] is a
  /// [ReorderableDragStartListener] widget; it should be passed as the
  /// `trailing` (or equivalent) of the row in reorder mode and ignored in
  /// default mode.
  final Widget Function(
    BuildContext context,
    T item,
    int position,
    bool reordering,
    Widget dragHandle,
  ) itemBuilder;

  /// Called exactly once, when the user leaves reorder mode ("Done"), with the
  /// new ordering. Not called on every individual drop.
  final void Function(List<T> newOrder) onCommitReorder;

  /// One-shot sort actions shown as flat [TextButton]s to the right of the
  /// [orderLabel]. Each fires [SortAction.onPressed] without entering reorder
  /// mode. Empty by default.
  final List<SortAction> sortActions;

  /// Muted anchor label on the left of the header strip, e.g.
  /// `l10n.exerciseSortBy`.
  final String orderLabel;

  /// When false the reorder toggle is hidden (e.g. while an exercise is
  /// running). Sort actions remain visible. Defaults to true.
  final bool enabled;

  /// Optional host-owned reorder-mode flag. If non-null, this widget listens
  /// to it and uses it as the source of truth for reorder mode instead of an
  /// internal notifier. The host can flip it externally to force-exit (e.g. on
  /// segment switch).
  final ValueNotifier<bool>? reorderMode;

  /// When true, the widget sizes itself to its content (suitable for use
  /// inside a [SingleChildScrollView]). Lists use `shrinkWrap: true` and
  /// `NeverScrollableScrollPhysics`. When false (default), the widget fills
  /// its parent using [Expanded] (requires a bounded height constraint from
  /// an ancestor [Column] or [Flexible]).
  final bool shrinkWrap;

  @override
  State<ReorderableSection<T>> createState() => _ReorderableSectionState<T>();
}

class _ReorderableSectionState<T> extends State<ReorderableSection<T>> {
  // The notifier that drives reorder mode. Either the host-supplied
  // widget.reorderMode or _ownedNotifier (if the host did not supply one).
  late ValueNotifier<bool> _notifier;

  // Owned only when widget.reorderMode is null. Disposed in dispose().
  ValueNotifier<bool>? _ownedNotifier;

  // Working copy mutated synchronously by drags. Null when not reordering.
  // On leaving reorder mode the draft is committed once via onCommitReorder
  // and the displayed list is updated synchronously from the draft.
  List<T>? _draft;

  @override
  void initState() {
    super.initState();
    _setupNotifier();
  }

  @override
  void didUpdateWidget(ReorderableSection<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reorderMode != widget.reorderMode) {
      oldWidget.reorderMode?.removeListener(_onModeChanged);
      _ownedNotifier?.dispose();
      _ownedNotifier = null;
      _setupNotifier();
    }
  }

  void _setupNotifier() {
    if (widget.reorderMode != null) {
      _notifier = widget.reorderMode!;
    } else {
      _ownedNotifier = ValueNotifier<bool>(false);
      _notifier = _ownedNotifier!;
    }
    _notifier.addListener(_onModeChanged);
  }

  void _onModeChanged() {
    if (!mounted) return;
    final reordering = _notifier.value;
    if (reordering) {
      // Entering reorder mode: seed a fresh draft from current items.
      setState(() => _draft = [...widget.items]);
      return;
    }
    // Leaving reorder mode: commit the draft, show new order immediately
    // without waiting for the async save round-trip.
    final draft = _draft;
    _draft = null;
    if (draft == null) {
      setState(() {});
      return;
    }
    widget.onCommitReorder(draft);
  }

  @override
  void dispose() {
    _notifier.removeListener(_onModeChanged);
    _ownedNotifier?.dispose();
    super.dispose();
  }

  void _enterReorderMode() => _notifier.value = true;
  void _exitReorderMode() => _notifier.value = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _notifier,
      builder: (context, reordering, _) {
        final l10n = AppLocalizations.of(context)!;
        final items = reordering ? (_draft ?? widget.items) : widget.items;

        final header = _buildHeader(context, l10n, reordering, items.length);
        final list = reordering
            ? _buildReorderList(context, items)
            : _buildDefaultList(context, items);

        if (widget.shrinkWrap) {
          // Intrinsic-height mode for use inside SingleChildScrollView.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [header, list],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(child: list),
          ],
        );
      },
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    AppLocalizations l10n,
    bool reordering,
    int itemCount,
  ) {
    if (reordering) return _buildDoneBar(context, l10n);
    if (itemCount < 2) return const SizedBox.shrink();
    return _buildSortBar(context, l10n);
  }

  Widget _buildDoneBar(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: _exitReorderMode,
            child: Text(l10n.exerciseReorderDone),
          ),
        ],
      ),
    );
  }

  Widget _buildSortBar(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final sortButtonStyle = TextButton.styleFrom(
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.orderLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final action in widget.sortActions)
                  TextButton(
                    style: sortButtonStyle,
                    onPressed: action.onPressed,
                    child: Text(action.label),
                  ),
                if (widget.enabled)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.swap_vert, size: 18),
                    onPressed: _enterReorderMode,
                    label: Text(l10n.exerciseReorderMode),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Lists ────────────────────────────────────────────────────────────────────

  Widget _buildDefaultList(BuildContext context, List<T> items) {
    // A placeholder drag handle that is never shown in default mode; itemBuilder
    // receives it as the dragHandle argument so the signature is consistent
    // across both modes.
    const placeholder = SizedBox.shrink();
    return ListView.builder(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: items.length,
      itemBuilder: (context, index) {
        return widget.itemBuilder(context, items[index], index, false, placeholder);
      },
    );
  }

  Widget _buildReorderList(BuildContext context, List<T> items) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: items.length,
      onReorderItem: (oldIndex, newIndex) {
        // onReorderItem already adjusts newIndex for the removed item.
        setState(() {
          final draft = _draft ??= [...widget.items];
          final moved = draft.removeAt(oldIndex);
          draft.insert(newIndex, moved);
        });
      },
      itemBuilder: (context, index) {
        final item = items[index];
        final dragHandle = ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Icon(Icons.drag_handle),
          ),
        );
        return KeyedSubtree(
          key: widget.keyOf(item),
          child: widget.itemBuilder(context, item, index, true, dragHandle),
        );
      },
    );
  }
}
