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
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:ringdrill/views/widgets/picker_error_banner.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';
import 'package:share_plus/share_plus.dart';

/// Which tab [showOpenPlanDialog] should land on when it opens. Order
/// matches the [TabBar] in [_LibraryBodyState.build] so `.index` can be
/// used directly as the [TabController]'s initial index.
enum LibraryTab { myPlans, online, fromFile }

Future<void> showOpenPlanDialog(
  BuildContext context, {
  LibraryTab initialTab = LibraryTab.myPlans,
}) {
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
          child: _LibraryBody(initialTab: initialTab),
        ),
      ),
    );
  }

  return showRingdrillActionSheet<void>(
    context: context,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: _LibraryBody(initialTab: initialTab),
    ),
  );
}

class _LibraryBody extends StatefulWidget {
  const _LibraryBody({this.initialTab = LibraryTab.myPlans});

  final LibraryTab initialTab;

  @override
  State<_LibraryBody> createState() => _LibraryBodyState();
}

class _LibraryBodyState extends State<_LibraryBody>
    with SingleTickerProviderStateMixin {
  final _programService = ProgramService();
  late final TabController _tabController;

  /// Last error message produced by the From-File tab's picker flow.
  /// Rendered as an inline banner above the pick-file button so the
  /// user can read and dismiss it without leaving the dialog — a
  /// snackbar from inside a modal lands behind the modal backdrop
  /// and never reaches the user.
  String? _fromFileError;

  /// Result of the last successful drill-library import. Rendered inline
  /// like [_fromFileError] instead of navigating away, because a bundle
  /// import (unlike a single `.drill`) never activates anything — the
  /// user stays on the "Mine planer" list to see what landed.
  BundleInstallResult? _fromFileBundleResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.index,
    );
    // Clear the From-File feedback as soon as the user navigates away
    // from the tab — re-entering on a clean slate matches the
    // expectation that feedback is scoped to the in-progress action.
    _tabController.addListener(() {
      if ((_fromFileError != null || _fromFileBundleResult != null) &&
          _tabController.index != 2) {
        setState(() {
          _fromFileError = null;
          _fromFileBundleResult = null;
        });
      }
    });
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
    // Match the picker sheets (select_plans_dialog.dart,
    // ProgramPageControllerBase.selectExercises): ExpandableTile cards use
    // the default card surface, which only contrasts against a lighter
    // scaffold behind it. Paint the tab body with the scaffold colour so
    // "Mine planer" reads with the same card contrast as the pickers.
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Expanded(
            child: programs.isEmpty
                ? EmptyState(
                    icon: Icons.folder_open_outlined,
                    text: localizations.libraryEmptyMyPlans,
                  )
                : _buildMyPlansList(context, localizations, programs),
          ),
          TabFooter(
            subtitle: localizations.libraryMyPlansSubtitle,
            trailing: IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: localizations.libraryExportAll,
              onPressed: programs.isEmpty
                  ? null
                  : () => active_actions.downloadAllPlans(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyPlansList(
    BuildContext context,
    AppLocalizations localizations,
    List<Program> programs,
  ) {
    return ListView.builder(
      // ExpandableTile's own margin (vertical: 5) already gives every
      // between-card gap 10px (5 + 5), matching its horizontal 10px. Without
      // this, the first card's top and the last card's bottom only get the
      // single 5px side of their own margin. Add the matching 5px here so
      // every edge — top, bottom, left, right, and between cards — is 10px.
      padding: const EdgeInsets.symmetric(vertical: 5),
      itemCount: programs.length,
      itemBuilder: (context, index) {
        final program = programs[index];
        final loaded = _programService.activeProgramUuid == program.uuid
            ? _programService.activeProgram
            : program;
        final isActive = _programService.activeProgramUuid == program.uuid;
        // No catalog badge here: the source is already spelled out as text
        // in the subtitle ("Fra katalog · slug" via programSubtitle), so a
        // second cloud icon next to "Aktiv" was redundant.
        final trailingChildren = <Widget>[
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
          child: ExpandableTile(
            // Radio icon, not the picker's Switch: this list is
            // single-select (which plan is active), not multi-select.
            leading: Icon(
              isActive
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              // ExpandableTile does not clamp a bare leading Icon to the
              // standard ListTile leading size the way ListTile does
              // internally — size explicitly so the row height is driven
              // by the text block, not an oversized icon.
              size: 24,
            ),
            title: Text(program.name),
            subtitle: Text(programSubtitle(localizations, loaded ?? program)),
            // ExpandableTile only wraps trailing in 4px of padding, unlike
            // the 16px its own `padding` param gives the leading side. Add
            // the missing 12px here so the right edge matches the left.
            trailing: trailingChildren.isEmpty
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: trailingChildren,
                    ),
                  ),
            onOpen: () =>
                _activate(context, program.uuid, closeOnSuccess: true),
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
      // Same radio semantics as "Mine planer" — checked when this catalog
      // item is the currently active plan. The cloud icon is dropped here
      // since installed status is already shown via trailingBuilder's chip.
      showActiveRadio: true,
      activeSlug: _programService.activeProgram?.source.whenOrNull(
        catalog: (slug, latestEtag, installedAt) => slug,
      ),
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
                  // The `?import=guide` deep link (ADR-0045) lands here with
                  // no other context — the generic "pick a .drill or .zip"
                  // hint alone left first-time migration users unsure what
                  // they were even looking for. Guide mode replaces it with
                  // a fuller explanation of what happened and what happens
                  // next, instead of stacking both hints.
                  Text(
                    widget.initialTab == LibraryTab.fromFile
                        ? localizations.importGuideHint
                        : localizations.libraryFromFileHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: Text(localizations.libraryFromFilePickAction),
                    onPressed: () => _installFromFile(context),
                  ),
                  if (_fromFileError != null) ...[
                    const SizedBox(height: 20),
                    PickerErrorBanner(
                      message: _fromFileError!,
                      onDismiss: () => setState(() => _fromFileError = null),
                    ),
                  ],
                  if (_fromFileBundleResult != null) ...[
                    const SizedBox(height: 20),
                    _BundleResultBanner(
                      result: _fromFileBundleResult!,
                      onDismiss: () =>
                          setState(() => _fromFileBundleResult = null),
                    ),
                  ],
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
    // Clear any stale banner before kicking off a fresh attempt so a
    // second pick of the same bad file still reads as a new outcome.
    if (_fromFileError != null || _fromFileBundleResult != null) {
      setState(() {
        _fromFileError = null;
        _fromFileBundleResult = null;
      });
    }
    final router = GoRouter.of(context);
    final outcome = await active_actions.installPickedPlanFile(context);
    if (!context.mounted) return;
    if (outcome.isSuccess) {
      // ADR-0032 *Activation contract*: navigate to the newly active
      // plan, then close the library dialog. installFromFile already
      // wrote `activeProgramUuid`, so the redirect gate short-circuits
      // and only the URL catches up.
      router.go(programPath(outcome.program!.uuid));
      Navigator.pop(context);
      return;
    }
    if (outcome.isBundle) {
      // A bundle import never activates anything (ADR-0045): stay in the
      // dialog, refresh the "Mine planer" list, and show the summary
      // inline instead of navigating.
      setState(() => _fromFileBundleResult = outcome.bundle);
      return;
    }
    if (outcome.errorMessage != null) {
      // Inline error inside the dialog so the message is not
      // covered by the modal backdrop.
      setState(() => _fromFileError = outcome.errorMessage);
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
        client: _buildCatalogClient(),
      );
      if (mounted) setState(() {});
      return;
    }
    // First-time publish — show the dialog so the user can pick a slug.
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

/// Source label · exercise count · last-updated line shown under a plan's
/// name. Shared between the "Mine planer" tab and [showSelectPlansDialog]
/// so a plan reads the same way wherever it's listed.
String programSubtitle(AppLocalizations localizations, Program program) {
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

/// Inline summary shown after a drill-library import. Mirrors
/// [PickerErrorBanner]'s shape but uses the primary palette instead of the
/// error one — a bundle import is a (possibly partial) success, not a
/// picked-the-wrong-file failure.
class _BundleResultBanner extends StatelessWidget {
  const _BundleResultBanner({required this.result, required this.onDismiss});

  final BundleInstallResult result;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final message = result.hasFailures
        ? localizations.importBundlePartial(result.imported, result.skipped)
        : localizations.importBundleSuccess(result.imported);
    return Container(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: colors.onPrimaryContainer,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: colors.onPrimaryContainer),
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
