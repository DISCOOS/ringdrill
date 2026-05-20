import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/views/catalog_conflict_dialog.dart';
import 'package:share_plus/share_plus.dart';

class LibraryView extends StatefulWidget {
  const LibraryView({super.key});

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView>
    with SingleTickerProviderStateMixin {
  final _programService = ProgramService();
  late final TabController _tabController;
  late Future<MarketFeedPageResponse> _feed;
  _CatalogServiceState _catalogServiceState = _CatalogServiceState.checking;
  String? _catalogServiceTooltip;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _feed = _loadFeed();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.library),
        actions: [
          _CatalogStatusAction(
            state: _catalogServiceState,
            tooltip: _catalogServiceTooltip,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'refresh_catalog') {
                setState(() {
                  _feed = _loadFeed();
                });
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'refresh_catalog',
                child: Text(localizations.libraryRetry),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: localizations.libraryMyPlans),
            Tab(text: localizations.libraryCatalog),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMyPlans(context), _buildCatalog(context)],
      ),
    );
  }

  Widget _buildMyPlans(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final programs = _programService.listPrograms();
    if (programs.isEmpty) {
      return Center(child: Text(localizations.noExercisesYet));
    }

    return ListView.builder(
      itemCount: programs.length,
      itemBuilder: (context, index) {
        final program = programs[index];
        final loaded = _programService.activeProgramUuid == program.uuid
            ? _programService.activeProgram
            : program;
        final isActive = _programService.activeProgramUuid == program.uuid;
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
            trailing: isActive
                ? Chip(label: Text(localizations.libraryActive))
                : null,
            onTap: () => _activate(context, program.uuid),
            onLongPress: () => _showPlanActions(context, program),
          ),
        );
      },
    );
  }

  Widget _buildCatalog(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return RefreshIndicator(
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
          if (_catalogServiceState == _CatalogServiceState.unavailable) {
            return ListView(
              children: [
                const SizedBox(height: 120),
                Center(child: Text(localizations.libraryErrorLoad)),
                const SizedBox(height: 12),
                Center(
                  child: FilledButton(
                    onPressed: () {
                      setState(() {
                        _feed = _loadFeed();
                      });
                    },
                    child: Text(localizations.libraryRetry),
                  ),
                ),
              ],
            );
          }
          final items = snapshot.data?.items ?? const <MarketFeedItem>[];
          if (items.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 120),
                Center(child: Text(localizations.libraryEmptyCatalog)),
              ],
            );
          }
          final installedSlugs = _installedCatalogSlugs();
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final installed = installedSlugs.contains(item.slug);
              return ListTile(
                title: Text(item.name),
                subtitle: Text(item.tags.join(', ')),
                trailing: FilledButton(
                  onPressed: installed ? null : () => _installCatalog(item),
                  child: Text(
                    installed
                        ? localizations.libraryInstalled
                        : localizations.libraryInstall,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<MarketFeedPageResponse> _loadFeed() async {
    _setCatalogServiceState(_CatalogServiceState.checking);
    try {
      final feed = await DrillClient(baseUrl: _catalogBaseUrl()).marketFeed();
      _setCatalogServiceState(_CatalogServiceState.online);
      return feed;
    } catch (error) {
      final isCorsBlocked = _isLikelyCorsBlocked(error);
      _setCatalogServiceState(
        isCorsBlocked
            ? _CatalogServiceState.corsBlocked
            : _CatalogServiceState.unavailable,
        tooltip: _catalogErrorTooltip(error, isCorsBlocked: isCorsBlocked),
      );
      return const MarketFeedPageResponse(items: []);
    }
  }

  void _setCatalogServiceState(_CatalogServiceState state, {String? tooltip}) {
    if (_catalogServiceState == state && _catalogServiceTooltip == tooltip) {
      return;
    }
    if (!mounted) {
      _catalogServiceState = state;
      _catalogServiceTooltip = tooltip;
      return;
    }
    setState(() {
      _catalogServiceState = state;
      _catalogServiceTooltip = tooltip;
    });
  }

  String _catalogBaseUrl() {
    return kIsWeb && kReleaseMode ? '' : AppConfig.ringDrillBaseUrl;
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

  Future<void> _activate(BuildContext context, String uuid) async {
    final localizations = AppLocalizations.of(context)!;
    try {
      await _programService.setActive(uuid);
      if (mounted) setState(() {});
    } on StateError {
      if (!context.mounted) return;
      _showSnackBar(context, localizations.libraryCannotSwitchRunning);
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
      case 'delete':
        if (await _confirmDelete(context, program)) {
          await _deleteProgram(program);
        }
    }
  }

  Future<void> _renameProgram(BuildContext context, Program program) async {
    final localizations = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: program.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.libraryRename),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(localizations.save),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final loaded = _programService.loadProgram(program.uuid);
    final updated = (loaded ?? program).copyWith(
      name: name,
      metadata: program.metadata.copyWith(updated: DateTime.now()),
    );
    await _programService.replaceProgram(updated);
    if (mounted) setState(() {});
  }

  Future<void> _refreshProgram(BuildContext context, Program program) async {
    final localizations = AppLocalizations.of(context)!;
    final client = DrillClient(baseUrl: _catalogBaseUrl());
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

  Future<void> _installCatalog(MarketFeedItem item) async {
    final localizations = AppLocalizations.of(context)!;
    try {
      final program = await _programService.installFromCatalog(
        item,
        DrillClient(baseUrl: _catalogBaseUrl()),
      );
      if (!mounted) return;
      setState(() {});
      _showSnackBar(context, localizations.importSuccess(program.name));
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

enum _CatalogServiceState { checking, online, unavailable, corsBlocked }

class _CatalogStatusAction extends StatelessWidget {
  const _CatalogStatusAction({required this.state, this.tooltip});

  final _CatalogServiceState state;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final (icon, label) = switch (state) {
      _CatalogServiceState.checking => (
        Icons.cloud_sync,
        localizations.catalogServiceChecking,
      ),
      _CatalogServiceState.online => (
        Icons.cloud_done,
        localizations.catalogServiceOnline,
      ),
      _CatalogServiceState.unavailable => (
        Icons.cloud_off,
        localizations.catalogServiceUnavailable,
      ),
      _CatalogServiceState.corsBlocked => (
        Icons.policy,
        localizations.catalogServiceCorsBlocked,
      ),
    };
    final color =
        state == _CatalogServiceState.unavailable ||
            state == _CatalogServiceState.corsBlocked
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).appBarTheme.foregroundColor;
    final showLabel = MediaQuery.sizeOf(context).width >= 520;

    return Tooltip(
      message: tooltip ?? label,
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLabel) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: color),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(icon, size: 20, color: color),
          ],
        ),
      ),
    );
  }
}
