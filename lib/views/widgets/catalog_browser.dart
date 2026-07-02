import 'package:flutter/material.dart';
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/catalog_status_service.dart';
import 'package:ringdrill/views/active_plan_actions.dart' as active_actions;
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';

/// Builds the widget shown in the [ListTile.trailing] slot for one catalog
/// item. Return `null` to render no trailing affordance.
typedef CatalogItemTrailingBuilder =
    Widget? Function(BuildContext context, MarketFeedItem item, bool installed);

/// Predicate that decides whether [item] should appear in the feed. Return
/// `false` to hide the item entirely. The default is "include everything".
typedef CatalogItemFilter = bool Function(MarketFeedItem item);

/// Shared catalog feed view used by the open-plan and add-exercises sheets.
///
/// Owns its own feed future and [CatalogStatusService] subscription, so
/// callers do not need to wire those up. Pass [onItemTap] to control what
/// happens when the user picks a plan (install it locally, or download and
/// merge selected exercises into the active plan).
class CatalogBrowser extends StatefulWidget {
  const CatalogBrowser({
    super.key,
    required this.onItemTap,
    required this.subtitle,
    this.installedSlugs = const <String>{},
    this.trailingBuilder,
    this.itemFilter,
  });

  /// Invoked when the user taps a catalog tile.
  final Future<void> Function(BuildContext context, MarketFeedItem item)
  onItemTap;

  /// Helper text rendered in the [TabFooter] under the list.
  final String subtitle;

  /// Slugs already installed locally. Used to drive the "already in library"
  /// affordance via [trailingBuilder] and the leading icon variant.
  final Set<String> installedSlugs;

  /// Optional builder for the per-tile trailing widget. When omitted, no
  /// trailing widget is shown.
  final CatalogItemTrailingBuilder? trailingBuilder;

  /// Optional predicate to hide feed items (e.g. the active plan's catalog
  /// source in the add-exercises sheet). When omitted, every item is shown.
  final CatalogItemFilter? itemFilter;

  @override
  State<CatalogBrowser> createState() => _CatalogBrowserState();
}

class _CatalogBrowserState extends State<CatalogBrowser> {
  final _catalogStatus = CatalogStatusService();
  late Future<MarketFeedPageResponse> _feed;

  @override
  void initState() {
    super.initState();
    _catalogStatus.listenable.addListener(_onCatalogStatusChanged);
    // Defer the first catalog probe to a follow-up event loop task so the
    // initial CatalogStatusService.setStatus(checking) call inside
    // _loadFeed() runs after the surrounding frame has finished building.
    // Calling setStatus synchronously from initState() notifies any
    // ValueListenableBuilder<CatalogStatus> already in the tree (e.g. the
    // appbar plan badge) while the framework is still in the build phase,
    // which trips the "setState() or markNeedsBuild() called during build"
    // assertion. FutureBuilder is fine with a future that completes a tick
    // later — it just shows the progress indicator in the meantime.
    _feed = Future<MarketFeedPageResponse>(_loadFeed);
  }

  @override
  void dispose() {
    _catalogStatus.listenable.removeListener(_onCatalogStatusChanged);
    super.dispose();
  }

  void _onCatalogStatusChanged() {
    if (mounted) setState(() {});
  }

  Future<MarketFeedPageResponse> _loadFeed() =>
      active_actions.probeCatalogService(context);

  void _reload() {
    setState(() {
      _feed = _loadFeed();
    });
  }

  String _catalogSubtitle(AppLocalizations localizations, MarketFeedItem item) {
    final parts = <String>[
      localizations.librarySourceCatalog(item.slug),
      if (item.tags.isNotEmpty) item.tags.join(', '),
      if (item.updatedAt != null)
        item.updatedAt!.toLocal().toString().split('.').first,
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    // Match the picker sheets (select_plans_dialog.dart,
    // ProgramPageControllerBase.selectExercises): ExpandableTile cards use
    // the default card surface, which only contrasts against a lighter
    // scaffold behind it. Paint the tab body with the scaffold colour so
    // "På nett" reads with the same card contrast as the pickers.
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _reload();
                await _feed;
              },
              child: FutureBuilder<MarketFeedPageResponse>(
                future: _feed,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final currentState = _catalogStatus.value.state;
                  if (currentState == CatalogServiceState.unavailable ||
                      currentState == CatalogServiceState.corsBlocked) {
                    return ListView(
                      children: [
                        const SizedBox(height: 80),
                        EmptyState(
                          icon: Icons.cloud_off,
                          text: localizations.libraryErrorLoad,
                        ),
                      ],
                    );
                  }
                  final allItems =
                      snapshot.data?.items ?? const <MarketFeedItem>[];
                  final filter = widget.itemFilter;
                  final items = filter == null
                      ? allItems
                      : allItems.where(filter).toList(growable: false);
                  if (items.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 80),
                        EmptyState(
                          icon: Icons.cloud_outlined,
                          text: localizations.libraryEmptyCatalog,
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final installed = widget.installedSlugs.contains(
                        item.slug,
                      );
                      final trailing = widget.trailingBuilder?.call(
                        context,
                        item,
                        installed,
                      );
                      return ExpandableTile(
                        leading: Icon(
                          installed
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_outlined,
                          color: colors.onSurfaceVariant,
                        ),
                        title: Text(item.name),
                        subtitle: Text(_catalogSubtitle(localizations, item)),
                        trailing: trailing,
                        onOpen: () => widget.onItemTap(context, item),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          TabFooter(
            subtitle: widget.subtitle,
            trailing: _CatalogStatusIndicator(
              status: _catalogStatus.value,
              onRefresh: _reload,
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogStatusIndicator extends StatelessWidget {
  const _CatalogStatusIndicator({
    required this.status,
    required this.onRefresh,
  });

  final CatalogStatus status;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final visual = catalogStatusVisual(status.state, localizations);
    final color = visual.isError
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: status.tooltip ?? visual.label,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  visual.label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(color: color),
                ),
              ),
              const SizedBox(width: 6),
              Icon(visual.icon, size: 18, color: color),
            ],
          ),
        ),
        IconButton(
          tooltip: localizations.libraryRetry,
          icon: const Icon(Icons.refresh),
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          onPressed: onRefresh,
        ),
      ],
    );
  }
}

/// Helper that maps a [CatalogServiceState] to icon, label, and error flag.
/// Lives here so the AppBar plan badge can reuse the same mapping.
class CatalogStatusVisual {
  const CatalogStatusVisual({
    required this.icon,
    required this.label,
    required this.isError,
  });

  final IconData icon;
  final String label;
  final bool isError;
}

CatalogStatusVisual catalogStatusVisual(
  CatalogServiceState state,
  AppLocalizations localizations,
) {
  return switch (state) {
    CatalogServiceState.unknown => CatalogStatusVisual(
      icon: Icons.cloud_queue,
      label: localizations.catalogServiceChecking,
      isError: false,
    ),
    CatalogServiceState.checking => CatalogStatusVisual(
      icon: Icons.cloud_sync,
      label: localizations.catalogServiceChecking,
      isError: false,
    ),
    CatalogServiceState.online => CatalogStatusVisual(
      icon: Icons.cloud_done,
      label: localizations.catalogServiceOnline,
      isError: false,
    ),
    CatalogServiceState.unavailable => CatalogStatusVisual(
      icon: Icons.cloud_off,
      label: localizations.catalogServiceUnavailable,
      isError: true,
    ),
    CatalogServiceState.corsBlocked => CatalogStatusVisual(
      icon: Icons.policy,
      label: localizations.catalogServiceCorsBlocked,
      isError: true,
    ),
  };
}
