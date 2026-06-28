import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/context_extensions.dart';
import 'package:ringdrill/views/active_plan_actions.dart' as active_actions;
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/catalog_conflict_dialog.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/publish_plan_dialog.dart';
import 'package:ringdrill/views/widgets/catalog_browser.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';
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

  return showRingdrillActionSheet<void>(
    context: context,
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
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    return CatalogBrowser(
      subtitle: localizations.libraryOnlineSubtitle,
      installedSlugs: _installedCatalogSlugs(),
      trailingBuilder: (context, item, installed) {
        if (installed) {
          return Chip(label: Text(localizations.libraryInstalled));
        }
        return FilledButton(
          onPressed: () => _installCatalog(item),
          child: Text(localizations.libraryInstall),
        );
      },
      onItemTap: (context, item) async {
        if (_installedCatalogSlugs().contains(item.slug)) return;
        await _installCatalog(item);
      },
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

  DrillClient _buildCatalogClient() => active_actions.buildCatalogClient();

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

  Future<void> _activate(
    BuildContext context,
    String uuid, {
    bool closeOnSuccess = false,
  }) async {
    final localizations = AppLocalizations.of(context)!;
    // Snapshot the router before any navigation. After `Navigator.pop`
    // the bottom-sheet `context` is deactivated and `context.go` becomes
    // a no-op; reading the [GoRouter] now gives us a long-lived handle
    // that survives the pop.
    final router = GoRouter.of(context);
    // ExerciseService guard is enforced inside ProgramService.setActive,
    // but we re-check here so we can surface the user-friendly snackbar
    // without going through the router. The router would still refuse
    // activation, but the URL would have already moved, which is worse UX.
    if (ExerciseService().isStarted &&
        _programService.activeProgramUuid != uuid) {
      _showSnackBar(context, localizations.libraryCannotSwitchRunning);
      return;
    }
    if (closeOnSuccess && context.mounted) Navigator.pop(context);
    // ADR-0032 *Activation contract*: UI-initiated plan activation goes
    // through the router; `_activateCanonicalProgramPath` runs `setActive`
    // as the redirect-gate side effect so the URL and the in-memory active
    // program never disagree.
    router.go(programPath(uuid));
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
    final localizations = context.l10n;
    if (_programService.activeProgramUuid == program.uuid &&
        ExerciseService().isStarted) {
      _showSnackBar(context, localizations.libraryCannotSwitchRunning);
      return false;
    }
    // Per ADR-0038 the library always keeps at least one plan
    // around. Refuse early so the destructive-confirm dialog never
    // appears for the last plan — the user gets a snackbar
    // explaining what to do instead.
    if (_programService.listPrograms().length <= 1) {
      _showSnackBar(context, localizations.cannotDeleteLastPlan);
      return false;
    }
    return confirmDestructive(
      context,
      title: localizations.confirm,
      message: localizations.confirmDeleteExercise,
      confirmLabel: localizations.delete,
    );
  }

  Future<void> _deleteProgram(Program program) async {
    await _programService.deleteProgram(program.uuid);
    if (mounted) setState(() {});
  }

  Future<void> _showPlanActions(BuildContext context, Program program) async {
    final localizations = AppLocalizations.of(context)!;
    final source = program.source.toJson();
    final action = await showRingdrillActionSheet<String>(
      context: context,
      builder: (context) => Column(
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
      final outcome = await _programService.refreshCatalogItem(
        program.uuid,
        client,
        onConflict: (diff, {required ownedSlug, required remoteUnchanged}) {
          return showCatalogConflictDialog(
            context,
            diff: diff,
            ownedSlug: ownedSlug,
            remoteUnchanged: remoteUnchanged,
          );
        },
      );
      if (mounted) setState(() {});
      if (!context.mounted) return;
      final message = _refreshOutcomeMessage(localizations, outcome, program);
      if (message != null) _showSnackBar(context, message);
    } catch (_) {
      if (!context.mounted) return;
      _showSnackBar(context, localizations.catalogServiceUnavailable);
    }
  }

  String? _refreshOutcomeMessage(
    AppLocalizations localizations,
    CatalogRefreshOutcome outcome,
    Program program,
  ) {
    switch (outcome.kind) {
      case CatalogRefreshKind.upToDate:
        return localizations.catalogRefreshUpToDate(program.name);
      case CatalogRefreshKind.updatedSilently:
        return localizations.catalogRefreshUpdated(program.name);
      case CatalogRefreshKind.updatedAfterPrompt:
        return outcome.remoteUnchanged
            ? localizations.catalogRefreshReverted(program.name)
            : localizations.catalogRefreshUpdated(program.name);
      case CatalogRefreshKind.cancelled:
        return localizations.catalogRefreshCancelled;
      case CatalogRefreshKind.forked:
        return localizations.catalogRefreshForked;
      case CatalogRefreshKind.published:
        return localizations.catalogRefreshPublished;
      case CatalogRefreshKind.failed:
        return null;
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

