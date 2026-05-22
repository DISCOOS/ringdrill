import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/services/catalog_status_service.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/views/active_plan_actions.dart' as active_actions;
import 'package:ringdrill/views/catalog_conflict_dialog.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/publish_plan_dialog.dart';
import 'package:share_plus/share_plus.dart';

Future<void> showOpenPlanDialog(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width > 600) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 560,
            maxHeight: 560,
            minWidth: 460,
          ),
          child: const _LibraryBody(),
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
    ),
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: const _LibraryBody(),
    ),
  );
}

class _LibraryBody extends StatefulWidget {
  const _LibraryBody();

  @override
  State<_LibraryBody> createState() => _LibraryBodyState();
}

class _LibraryBodyState extends State<_LibraryBody>
    with SingleTickerProviderStateMixin {
  final _programService = ProgramService();
  final _catalogStatus = CatalogStatusService();
  late final TabController _tabController;
  late Future<MarketFeedPageResponse> _feed;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    _tabController.dispose();
    super.dispose();
  }

  void _onCatalogStatusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            const SizedBox(height: 8),
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: localizations.libraryMyPlans),
                Tab(text: localizations.libraryOnlineTab),
                Tab(text: localizations.fromFileAction),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMyPlans(context),
                  _buildCatalog(context),
                  _buildFromFile(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyPlans(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final programs = _programService.listPrograms();
    return Column(
      children: [
        Expanded(
          child: programs.isEmpty
              ? EmptyState(
                  icon: Icons.folder_open_outlined,
                  text: localizations.libraryEmptyMyPlans,
                )
              : _buildMyPlansList(context, localizations, programs),
        ),
        TabFooter(subtitle: localizations.libraryMyPlansSubtitle),
      ],
    );
  }

  Widget _buildMyPlansList(
    BuildContext context,
    AppLocalizations localizations,
    List<Program> programs,
  ) {
    return ListView.builder(
      itemCount: programs.length,
      itemBuilder: (context, index) {
        final program = programs[index];
        final loaded = _programService.activeProgramUuid == program.uuid
            ? _programService.activeProgram
            : program;
        final isActive = _programService.activeProgramUuid == program.uuid;
        final isCatalog = program.source.toJson()['runtimeType'] == 'catalog';
        final trailingChildren = <Widget>[
          if (isCatalog)
            Tooltip(
              message: localizations.libraryCatalogBadge,
              child: Icon(
                Icons.cloud_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          if (isCatalog && isActive) const SizedBox(width: 8),
          if (isActive) Chip(label: Text(localizations.libraryActive)),
        ];
        return Dismissible(
          key: ValueKey(program.uuid),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) => _confirmDelete(context, program),
          onDismissed: (_) => _deleteProgram(program),
          child: ListTile(
            leading: Icon(
              isActive
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: Text(program.name),
            subtitle: Text(_programSubtitle(localizations, loaded ?? program)),
            trailing: trailingChildren.isEmpty
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: trailingChildren,
                  ),
            onTap: () => _activate(context, program.uuid, closeOnSuccess: true),
            onLongPress: () => _showPlanActions(context, program),
          ),
        );
      },
    );
  }

  Widget _buildCatalog(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _feed = _loadFeed();
              });
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
                final items = snapshot.data?.items ?? const <MarketFeedItem>[];
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
                final installedSlugs = _installedCatalogSlugs();
                final colors = Theme.of(context).colorScheme;
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final installed = installedSlugs.contains(item.slug);
                    final trailingChildren = <Widget>[
                      if (installed)
                        Chip(label: Text(localizations.libraryInstalled))
                      else
                        FilledButton(
                          onPressed: () => _installCatalog(item),
                          child: Text(localizations.libraryInstall),
                        ),
                    ];
                    return ListTile(
                      leading: Icon(
                        installed
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_outlined,
                        color: colors.onSurfaceVariant,
                      ),
                      title: Text(item.name),
                      subtitle: Text(_catalogSubtitle(localizations, item)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: trailingChildren,
                      ),
                      onTap: installed
                          ? null
                          : () => _installCatalog(item),
                    );
                  },
                );
              },
            ),
          ),
        ),
        TabFooter(
          subtitle: localizations.libraryOnlineSubtitle,
          trailing: _CatalogStatusIndicator(
            status: _catalogStatus.value,
            onRefresh: () {
              setState(() {
                _feed = _loadFeed();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFromFile(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.upload_file_outlined,
                    size: 64,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localizations.libraryFromFileHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: Text(localizations.libraryFromFilePickAction),
                    onPressed: () => _installFromFile(context),
                  ),
                ],
              ),
            ),
          ),
        ),
        TabFooter(subtitle: localizations.libraryFromFileSubtitle),
      ],
    );
  }

  Future<MarketFeedPageResponse> _loadFeed() async {
    _catalogStatus.setStatus(CatalogServiceState.checking);
    try {
      final feed = await _buildCatalogClient().marketFeed();
      _catalogStatus.setStatus(CatalogServiceState.online);
      return feed;
    } catch (error) {
      final isCorsBlocked = _isLikelyCorsBlocked(error);
      _catalogStatus.setStatus(
        isCorsBlocked
            ? CatalogServiceState.corsBlocked
            : CatalogServiceState.unavailable,
        tooltip: _catalogErrorTooltip(error, isCorsBlocked: isCorsBlocked),
      );
      return const MarketFeedPageResponse(items: []);
    }
  }

  String _catalogBaseUrl() {
    return AppConfig.catalogBaseUrl(
      isWeb: kIsWeb,
      isRelease: kReleaseMode,
      isDebug: kDebugMode,
    );
  }

  // Builds a DrillClient configured for the catalog endpoint. When the
  // base URL points at a local `netlify functions:serve` (no /api/* or
  // /d/* redirects), we route the deep-link calls directly at the
  // function path. See ADR-0013.
  DrillClient _buildCatalogClient() {
    final baseUrl = _catalogBaseUrl();
    return DrillClient(
      baseUrl: baseUrl,
      deepLinkBasePath: AppConfig.deepLinkBasePathFor(baseUrl),
    );
  }

  bool _isLikelyCorsBlocked(Object error) {
    final message = error.toString();
    return kIsWeb &&
        message.contains('ClientException') &&
        message.contains('Failed to fetch') &&
        message.contains(AppConfig.ringDrillBaseUrl);
  }

  String _catalogErrorTooltip(Object error, {required bool isCorsBlocked}) {
    final details = error.toString();
    if (!isCorsBlocked || !mounted) return details;
    final localizations = AppLocalizations.of(context)!;
    return '${localizations.catalogServiceCorsBlockedTooltip}\n\n$details';
  }

  Set<String> _installedCatalogSlugs() {
    return _programService
        .listPrograms()
        .map((program) {
          final source = program.source.toJson();
          return source['runtimeType'] == 'catalog'
              ? source['slug'] as String
              : null;
        })
        .whereType<String>()
        .toSet();
  }

  String _programSubtitle(AppLocalizations localizations, Program program) {
    final source = program.source.toJson();
    final sourceLabel = switch (source['runtimeType']) {
      'imported' => localizations.librarySourceImported(
        source['fileName'] as String,
      ),
      'catalog' => localizations.librarySourceCatalog(source['slug'] as String),
      _ => localizations.librarySourceLocal,
    };
    return [
      sourceLabel,
      '${program.exercises.length} ${localizations.exercise(program.exercises.length).toLowerCase()}',
      program.metadata.updated.toLocal().toString().split('.').first,
    ].join(' · ');
  }

  String _catalogSubtitle(
    AppLocalizations localizations,
    MarketFeedItem item,
  ) {
    final parts = <String>[
      localizations.librarySourceCatalog(item.slug),
      if (item.tags.isNotEmpty) item.tags.join(', '),
      if (item.updatedAt != null)
        item.updatedAt!.toLocal().toString().split('.').first,
    ];
    return parts.join(' · ');
  }

  Future<void> _activate(
    BuildContext context,
    String uuid, {
    bool closeOnSuccess = false,
  }) async {
    final localizations = AppLocalizations.of(context)!;
    try {
      await _programService.setActive(uuid);
      if (mounted) setState(() {});
      if (closeOnSuccess && context.mounted) Navigator.pop(context);
    } on StateError {
      if (!context.mounted) return;
      _showSnackBar(context, localizations.libraryCannotSwitchRunning);
    }
  }

  Future<void> _installFromFile(BuildContext context) async {
    final before = _programService.activeProgramUuid;
    await active_actions.installPickedPlanFile(context);
    if (!context.mounted) return;
    if (_programService.activeProgramUuid != null &&
        _programService.activeProgramUuid != before) {
      Navigator.pop(context);
    }
  }

  Future<bool> _confirmDelete(BuildContext context, Program program) async {
    final localizations = AppLocalizations.of(context)!;
    if (_programService.activeProgramUuid == program.uuid &&
        ExerciseService().isStarted) {
      _showSnackBar(context, localizations.libraryCannotSwitchRunning);
      return false;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(localizations.confirm),
        content: Text(localizations.confirmDeleteExercise),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(localizations.delete),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteProgram(Program program) async {
    await _programService.deleteProgram(program.uuid);
    if (mounted) setState(() {});
  }

  Future<void> _showPlanActions(BuildContext context, Program program) async {
    final localizations = AppLocalizations.of(context)!;
    final source = program.source.toJson();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(localizations.libraryRename),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            if (source['runtimeType'] == 'catalog')
              ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(localizations.libraryRefresh),
                onTap: () => Navigator.pop(context, 'refresh'),
              ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: Text(localizations.libraryExport),
              onTap: () => Navigator.pop(context, 'export'),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: Text(localizations.libraryPublish),
              onTap: () => Navigator.pop(context, 'publish'),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_sync_outlined),
              title: Text(localizations.libraryPublishAs),
              onTap: () => Navigator.pop(context, 'publishAs'),
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: Text(localizations.libraryDelete),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'rename':
        await _renameProgram(context, program);
      case 'refresh':
        await _refreshProgram(context, program);
      case 'export':
        await _exportProgram(context, program);
      case 'publish':
        await _publishProgram(context, program);
      case 'publishAs':
        await _publishProgramAs(context, program);
      case 'delete':
        if (await _confirmDelete(context, program)) {
          await _deleteProgram(program);
        }
    }
  }

  Future<void> _renameProgram(BuildContext context, Program program) async {
    await active_actions.renamePlan(context, program);
    if (mounted) setState(() {});
  }

  Future<void> _refreshProgram(BuildContext context, Program program) async {
    final localizations = AppLocalizations.of(context)!;
    final client = _buildCatalogClient();
    try {
      await _programService.refreshCatalogItem(
        program.uuid,
        client,
        onConflict: (diff, {required ownedSlug}) {
          return showCatalogConflictDialog(
            context,
            diff: diff,
            ownedSlug: ownedSlug,
          );
        },
      );
      if (mounted) setState(() {});
    } catch (_) {
      if (!context.mounted) return;
      _showSnackBar(context, localizations.catalogServiceUnavailable);
    }
  }

  Future<void> _exportProgram(BuildContext context, Program program) async {
    final loaded = _programService.loadProgram(program.uuid);
    if (loaded == null) return;
    final file = DrillFile.fromProgram(loaded, path.basename(loaded.name));
    final params = ShareParams(
      text: loaded.name,
      files: [
        XFile.fromData(
          Uint8List.fromList(file.content),
          name: file.fileName,
          mimeType: file.mimeType,
        ),
      ],
    );
    await SharePlus.instance.share(params);
  }

  Future<void> _publishProgram(BuildContext context, Program program) async {
    final loaded = _programService.loadProgram(program.uuid);
    if (loaded == null) return;
    final currentSlug = loaded.source.whenOrNull(
      catalog: (slug, latestEtag, installedAt) => slug,
    );
    if (currentSlug != null) {
      // Already published — push a new version silently without a dialog.
      await runPublishProgram(
        context,
        programUuid: loaded.uuid,
        slug: currentSlug,
        tags: const [],
        client: _buildCatalogClient(),
      );
      if (mounted) setState(() {});
      return;
    }
    // First-time publish — show the dialog so the user can pick slug + tags.
    final input = await showPublishPlanDialog(
      context,
      program: loaded,
      mode: PublishDialogMode.firstTime,
    );
    if (input == null || !context.mounted) return;
    await runPublishProgram(
      context,
      programUuid: loaded.uuid,
      slug: input.slug,
      tags: input.tags,
      client: _buildCatalogClient(),
    );
    if (mounted) setState(() {});
  }

  Future<void> _publishProgramAs(BuildContext context, Program program) async {
    final loaded = _programService.loadProgram(program.uuid);
    if (loaded == null) return;
    final input = await showPublishPlanDialog(
      context,
      program: loaded,
      mode: PublishDialogMode.publishAs,
    );
    if (input == null || !context.mounted) return;
    await runPublishProgramAs(
      context,
      programUuid: loaded.uuid,
      slug: input.slug,
      tags: input.tags,
      client: _buildCatalogClient(),
    );
    if (mounted) setState(() {});
  }

  Future<void> _installCatalog(MarketFeedItem item) async {
    final localizations = AppLocalizations.of(context)!;
    try {
      await _programService.installFromCatalog(
        item,
        _buildCatalogClient(),
        activate: true,
      );
      if (!mounted) return;
      setState(() {});
      if (context.mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar(context, localizations.libraryErrorLoad);
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        showCloseIcon: true,
        dismissDirection: DismissDirection.endToStart,
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
