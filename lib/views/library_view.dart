import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/services/auth_service.dart';
import 'package:ringdrill/services/edit_permissions.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/utils/context_extensions.dart';
import 'package:ringdrill/views/active_plan_actions.dart' as active_actions;
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/catalog_conflict_dialog.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/drill_format_messages.dart';
import 'package:ringdrill/views/publish_plan_dialog.dart';
import 'package:ringdrill/views/widgets/catalog_browser.dart';
import 'package:ringdrill/views/widgets/edit_affordance.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:ringdrill/views/widgets/picker_error_banner.dart';
import 'package:ringdrill/views/widgets/plan_text.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';
import 'package:ringdrill/views/widgets/ringdrill_text.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Which tab [showOpenPlanDialog] should land on when it opens. Order
/// matches the [TabBar] in [_LibraryBodyState.build] so `.index` can be
/// used directly as the [TabController]'s initial index.
///
/// `account` sits between `online` and `fromFile` rather than at the end,
/// because the three plan *sources* belong together and "New from file" is the
/// action. [online] keeps its name while its label became "Public"
/// (DESIGN-015 §5.7): renaming the enum would churn every call site to say the
/// same thing.
enum LibraryTab { myPlans, online, account, fromFile }

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
  final _planService = PlanService();
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
      length: LibraryTab.values.length,
      vsync: this,
      initialIndex: widget.initialTab.index,
    );
    // Clear the From-File feedback as soon as the user navigates away
    // from the tab — re-entering on a clean slate matches the
    // expectation that feedback is scoped to the in-progress action.
    _tabController.addListener(() {
      if ((_fromFileError != null || _fromFileBundleResult != null) &&
          _tabController.index != LibraryTab.fromFile.index) {
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
                Tab(text: localizations.libraryAccountTab),
                Tab(text: localizations.fromFileAction),
              ],
              // Four labels do not fit a phone's width side by side, and a
              // squeezed tab bar truncates every label rather than the longest.
              isScrollable: true,
              tabAlignment: TabAlignment.center,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMyPlans(context),
                  _buildCatalog(context),
                  _buildAccountPlans(context),
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
    final plans = _planService.listPlans();
    // Match the picker sheets (select_plans_dialog.dart,
    // PlanPageControllerBase.selectExercises): ExpandableTile cards use
    // the default card surface, which only contrasts against a lighter
    // scaffold behind it. Paint the tab body with the scaffold colour so
    // "Mine planer" reads with the same card contrast as the pickers.
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Expanded(
            child: plans.isEmpty
                ? EmptyState(
                    icon: Icons.folder_open_outlined,
                    text: localizations.libraryEmptyMyPlans,
                  )
                : _buildMyPlansList(context, localizations, plans),
          ),
          TabFooter(
            subtitle: localizations.libraryMyPlansSubtitle,
            trailing: IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: localizations.libraryExportAll,
              onPressed: plans.isEmpty
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
    List<Plan> plans,
  ) {
    return ListView.builder(
      // ExpandableTile's own margin (vertical: 5) already gives every
      // between-card gap 10px (5 + 5), matching its horizontal 10px. Without
      // this, the first card's top and the last card's bottom only get the
      // single 5px side of their own margin. Add the matching 5px here so
      // every edge — top, bottom, left, right, and between cards — is 10px.
      padding: const EdgeInsets.symmetric(vertical: 5),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        final loaded = _planService.activePlanUuid == plan.uuid
            ? _planService.activePlan
            : plan;
        final isActive = _planService.activePlanUuid == plan.uuid;
        // No catalog badge here: the source is already spelled out as text
        // in the subtitle ("Fra katalog · slug" via planSubtitle), so a
        // second cloud icon next to "Aktiv" was redundant.
        final trailingChildren = <Widget>[
          if (isActive) Chip(label: Text(localizations.libraryActive)),
        ];
        // Deleting a plan is director-only (ADR-0057), and DeletableRow asks
        // canDelete rather than canEdit — the stricter question. The long-press
        // menu below rides the same gate because it *contains* the delete entry.
        return DeletableRow(
          target: EditTarget.plan,
          dismissKey: ValueKey(plan.uuid),
          confirmDelete: () => _confirmDelete(context, plan),
          onDelete: () => _deletePlan(plan),
          onLongPress: () => _showPlanActions(context, plan),
          builder: (context, onLongPress) {
            final tile = ExpandableTile(
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
              // forPlan, not plain: these rows are cross-plan, so the
              // ambient PlanScope is the *active* plan's — resolving another
              // plan's name against it would substitute the wrong values.
              title: RingDrillText.forPlan(loaded ?? plan, plan.name),
              subtitle: Text(planSubtitle(localizations, loaded ?? plan)),
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
              onOpen: () => _activate(context, plan.uuid, closeOnSuccess: true),
              // Plan actions include destructive ones, so the long-press follows
              // the same gate as the swipe — DeletableRow passes null when the
              // role may not delete.
              onLongPress: onLongPress,
            );
            return tile;
          },
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
      activeSlug: _planService.activePlan?.source.whenOrNull(
        catalog: (slug, latestEtag, installedAt, latestVersion) => slug,
      ),
      trailingBuilder: (context, item, installed, busy, onTap) {
        if (installed) {
          return Chip(label: Text(localizations.libraryInstalled));
        }
        if (busy) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        // Routed through onTap (CatalogBrowser's busy-tracked handler),
        // not a direct _installCatalog(item) call — this button and
        // tapping the row do the same thing, so both must share the one
        // busy state instead of racing each other.
        return FilledButton(
          onPressed: onTap,
          child: Text(localizations.libraryInstall),
        );
      },
      onItemTap: (context, item) async {
        // Already installed: open it exactly like tapping it in "Mine
        // planer" would, instead of silently doing nothing. Re-downloading
        // an already-installed plan just to activate it would also be
        // wrong — the local copy may have edits the catalog doesn't have.
        final installedPlan = _installedPlanForSlug(item.slug);
        if (installedPlan != null) {
          await _activate(context, installedPlan.uuid, closeOnSuccess: true);
          return;
        }
        await _installCatalog(item);
      },
    );
  }

  /// The account's own plans (DESIGN-015 §5.7).
  ///
  /// Reuses [CatalogBrowser] with a different loader rather than growing a
  /// near-copy: install, busy state, empty and error states are all the same
  /// problem, and two implementations would drift the first time either
  /// changed.
  ///
  /// Signed out is not an error state here. An account is optional and stays
  /// optional (§5.1), so this reads as an explanation rather than a setup step
  /// somebody skipped — no badge, no call to action dressed as a warning.
  Widget _buildAccountPlans(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    if (!AuthService.isInstalled) {
      // Only in tests and `AUTH_MODE=off` builds. Same message: there is
      // nothing the user could do differently.
      return EmptyState(
        icon: Icons.badge_outlined,
        text: localizations.libraryAccountSignedOut,
      );
    }

    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final account = AuthService.instance.state.activeAccount;
        if (account == null) {
          return EmptyState(
            icon: Icons.badge_outlined,
            text: localizations.libraryAccountSignedOut,
          );
        }

        return CatalogBrowser(
          // Keyed by account so switching organisations rebuilds the state
          // rather than showing the previous account's list against the new
          // account's footer.
          key: ValueKey('account-plans-${account.accountId}'),
          subtitle: localizations.libraryAccountSubtitle(account.displayName),
          emptyText: localizations.libraryAccountEmpty,
          loader: () => active_actions.buildCatalogClient().accountPlans(
            account.accountId,
          ),
          installedSlugs: _installedCatalogSlugs(),
          showActiveRadio: true,
          activeSlug: _planService.activePlan?.source.whenOrNull(
            catalog: (slug, latestEtag, installedAt, latestVersion) => slug,
          ),
          trailingBuilder: (context, item, installed, busy, onTap) {
            if (busy) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            // A draft is the one thing this tab shows that the public one
            // cannot, so it is labelled rather than left to be inferred from
            // its absence elsewhere. It is a listing flag, not a lock: the
            // plan is still downloadable by anyone with the link.
            final chips = <Widget>[
              if (item.published == false)
                Chip(label: Text(localizations.libraryAccountDraft)),
              if (installed) Chip(label: Text(localizations.libraryInstalled)),
            ];
            if (chips.isNotEmpty) {
              return Row(mainAxisSize: MainAxisSize.min, children: chips);
            }
            return FilledButton(
              onPressed: onTap,
              child: Text(localizations.libraryInstall),
            );
          },
          onItemTap: (context, item) async {
            final installedPlan = _installedPlanForSlug(item.slug);
            if (installedPlan != null) {
              await _activate(
                context,
                installedPlan.uuid,
                closeOnSuccess: true,
              );
              return;
            }
            await _installCatalog(item);
          },
        );
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
    return _planService
        .listPlans()
        .map((plan) {
          final source = plan.source.toJson();
          return source['runtimeType'] == 'catalog'
              ? source['slug'] as String
              : null;
        })
        .whereType<String>()
        .toSet();
  }

  /// The locally-installed [Plan] whose catalog source matches [slug],
  /// or null if that plan hasn't been installed yet.
  Plan? _installedPlanForSlug(String slug) {
    for (final plan in _planService.listPlans()) {
      final source = plan.source.toJson();
      if (source['runtimeType'] == 'catalog' && source['slug'] == slug) {
        return plan;
      }
    }
    return null;
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
    // ExerciseService guard is enforced inside PlanService.setActive,
    // but we re-check here so we can surface the user-friendly snackbar
    // without going through the router. The router would still refuse
    // activation, but the URL would have already moved, which is worse UX.
    if (ExerciseService().isStarted && _planService.activePlanUuid != uuid) {
      _showSnackBar(context, localizations.libraryCannotSwitchRunning);
      return;
    }
    if (closeOnSuccess && context.mounted) Navigator.pop(context);
    // ADR-0032 *Activation contract*: UI-initiated plan activation goes
    // through the router; `_activateCanonicalPlanPath` runs `setActive`
    // as the redirect-gate side effect so the URL and the in-memory active
    // plan never disagree.
    router.go(planPath(uuid));
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
      // wrote `activePlanUuid`, so the redirect gate short-circuits
      // and only the URL catches up.
      router.go(planPath(outcome.plan!.uuid));
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

  Future<bool> _confirmDelete(BuildContext context, Plan plan) async {
    final localizations = context.l10n;
    // Deleting the active plan would leave nothing active for the app to
    // fall back on — require the user to explicitly activate a different
    // plan first (which itself refuses while an exercise is running, via
    // _activate's own ExerciseService guard) rather than the app silently
    // picking one, or worse, leaving activePlanUuid pointing at nothing.
    if (_planService.activePlanUuid == plan.uuid) {
      _showSnackBar(context, localizations.cannotDeleteActivePlan);
      return false;
    }
    // Per ADR-0038 the library always keeps at least one plan
    // around. Refuse early so the destructive-confirm dialog never
    // appears for the last plan — the user gets a snackbar
    // explaining what to do instead.
    if (_planService.listPlans().length <= 1) {
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

  Future<void> _deletePlan(Plan plan) async {
    await _planService.deletePlan(plan.uuid);
    if (mounted) setState(() {});
  }

  Future<void> _showPlanActions(BuildContext context, Plan plan) async {
    final localizations = AppLocalizations.of(context)!;
    final source = plan.source.toJson();
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
        await _renamePlan(context, plan);
      case 'refresh':
        await _refreshPlan(context, plan);
      case 'export':
        await _exportPlan(context, plan);
      case 'publish':
        await _publishPlan(context, plan);
      case 'publishAs':
        await _publishPlanAs(context, plan);
      case 'delete':
        if (await _confirmDelete(context, plan)) {
          await _deletePlan(plan);
        }
    }
  }

  Future<void> _renamePlan(BuildContext context, Plan plan) async {
    await active_actions.renamePlan(context, plan);
    if (mounted) setState(() {});
  }

  Future<void> _refreshPlan(BuildContext context, Plan plan) async {
    final localizations = AppLocalizations.of(context)!;
    final client = _buildCatalogClient();
    try {
      final outcome = await _planService.refreshCatalogItem(
        plan.uuid,
        client,
        onConflict:
            (
              diff, {
              required ownedSlug,
              required remoteUnchanged,
              required localVersion,
              required catalogVersion,
            }) {
              return showCatalogConflictDialog(
                context,
                diff: diff,
                ownedSlug: ownedSlug,
                remoteUnchanged: remoteUnchanged,
                localVersion: localVersion,
                catalogVersion: catalogVersion,
              );
            },
      );
      if (mounted) setState(() {});
      if (!context.mounted) return;
      final message = _refreshOutcomeMessage(localizations, outcome, plan);
      // plan:, not the active plan — this row may be any plan in the library, and
      // the message interpolates *its* name.
      if (message != null) _showSnackBar(context, message, plan: plan);
    } catch (e, stackTrace) {
      if (context.mounted) {
        _showSnackBar(context, localizations.catalogServiceUnavailable);
      }
      // The 404 "plan removed from catalog" case is handled as a normal
      // outcome above, not an exception, so anything landing here is
      // genuinely unexpected — worth having in Sentry rather than silently
      // swallowed.
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
    }
  }

  String? _refreshOutcomeMessage(
    AppLocalizations localizations,
    CatalogRefreshOutcome outcome,
    Plan plan,
  ) {
    switch (outcome.kind) {
      case CatalogRefreshKind.upToDate:
        return localizations.catalogRefreshUpToDate(plan.name);
      case CatalogRefreshKind.updatedSilently:
        return localizations.catalogRefreshUpdated(plan.name);
      case CatalogRefreshKind.updatedAfterPrompt:
        return outcome.remoteUnchanged
            ? localizations.catalogRefreshReverted(plan.name)
            : localizations.catalogRefreshUpdated(plan.name);
      case CatalogRefreshKind.cancelled:
        return localizations.catalogRefreshCancelled;
      case CatalogRefreshKind.forked:
        return localizations.catalogRefreshForked;
      case CatalogRefreshKind.published:
        return localizations.catalogRefreshPublished;
      case CatalogRefreshKind.failed:
        return null;
      case CatalogRefreshKind.removedFromCatalog:
        return localizations.catalogRefreshRemoved(plan.name);
    }
  }

  Future<void> _exportPlan(BuildContext context, Plan plan) async {
    final loaded = _planService.loadPlan(plan.uuid);
    if (loaded == null) return;
    final file = DrillFile.fromPlan(loaded, path.basename(loaded.name));
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

  Future<void> _publishPlan(BuildContext context, Plan plan) async {
    final loaded = _planService.loadPlan(plan.uuid);
    if (loaded == null) return;
    final currentSlug = loaded.source.whenOrNull(
      catalog: (slug, latestEtag, installedAt, latestVersion) => slug,
    );
    if (currentSlug != null) {
      // Already published — push a new version silently without a dialog.
      await runPublishPlan(
        context,
        planUuid: loaded.uuid,
        slug: currentSlug,
        client: _buildCatalogClient(),
      );
      if (mounted) setState(() {});
      return;
    }
    // First-time publish — show the dialog so the user can pick a slug.
    final input = await showPublishPlanDialog(
      context,
      plan: loaded,
      mode: PublishDialogMode.firstTime,
    );
    if (input == null || !context.mounted) return;
    await runPublishPlan(
      context,
      planUuid: loaded.uuid,
      slug: input.slug,
      client: _buildCatalogClient(),
    );
    if (mounted) setState(() {});
  }

  Future<void> _publishPlanAs(BuildContext context, Plan plan) async {
    final loaded = _planService.loadPlan(plan.uuid);
    if (loaded == null) return;
    final input = await showPublishPlanDialog(
      context,
      plan: loaded,
      mode: PublishDialogMode.publishAs,
    );
    if (input == null || !context.mounted) return;
    await runPublishPlanAs(
      context,
      planUuid: loaded.uuid,
      slug: input.slug,
      client: _buildCatalogClient(),
    );
    if (mounted) setState(() {});
  }

  Future<void> _installCatalog(MarketFeedItem item) async {
    final localizations = AppLocalizations.of(context)!;
    try {
      await _planService.installFromCatalog(
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

  /// Delegates to [showRingdrillSnackBar], which resolves the plan tokens a
  /// name-bearing message carries. [plan] matters here more than anywhere else:
  /// this list acts on plans that are *not* the active one, so the active plan's
  /// variables are the wrong ones to resolve against.
  void _showSnackBar(BuildContext context, String message, {Plan? plan}) =>
      showRingdrillSnackBar(context, message, plan: plan);
}

/// Source label · exercise count · last-updated line shown under a plan's
/// name. Shared between the "Mine planer" tab and [showSelectPlansDialog]
/// so a plan reads the same way wherever it's listed.
String planSubtitle(AppLocalizations localizations, Plan plan) {
  final source = plan.source.toJson();
  final sourceLabel = switch (source['runtimeType']) {
    'imported' => localizations.librarySourceImported(
      source['fileName'] as String,
    ),
    'catalog' => localizations.librarySourceCatalog(source['slug'] as String),
    _ => localizations.librarySourceLocal,
  };
  return [
    sourceLabel,
    '${plan.exercises.length} ${localizations.exercise(plan.exercises.length).toLowerCase()}',
    plan.metadata.updated.toLocal().toString().split('.').first,
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

  /// Cap on how many skipped-entry lines are listed individually before
  /// collapsing the rest into a "+N more" line — a bundle with many
  /// failures would otherwise push the "Velg fil" button off-screen.
  static const int _maxSkippedListed = 5;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final message = result.hasFailures
        ? localizations.importBundlePartial(
            result.imported,
            result.skipped.length,
          )
        : localizations.importBundleSuccess(result.imported);
    final textStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: colors.onPrimaryContainer);
    return Container(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: colors.onPrimaryContainer,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: textStyle)),
              IconButton(
                icon: Icon(Icons.close, color: colors.onPrimaryContainer),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: onDismiss,
              ),
            ],
          ),
          // Per-file reason list — the summary count alone ("1 hoppet
          // over") gives no way to act on it, e.g. re-export just that
          // one plan. Each line reuses drillFormatMessage so the wording
          // matches the single-.drill open/import failure exactly.
          if (result.hasFailures)
            Padding(
              padding: const EdgeInsets.only(left: 28, right: 8, bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in result.skipped.take(_maxSkippedListed))
                    Text(
                      '•  ${drillFormatMessage(localizations, entry.fileName, entry.reason)}',
                      style: textStyle,
                    ),
                  if (result.skipped.length > _maxSkippedListed)
                    Text(
                      localizations.importBundleMoreSkipped(
                        result.skipped.length - _maxSkippedListed,
                      ),
                      style: textStyle,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
