import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/active_plan_actions.dart' as active_actions;
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/drill_format_messages.dart';
import 'package:ringdrill/views/library_view.dart' show planSubtitle;
import 'package:ringdrill/views/plan_diff_widgets.dart';
import 'package:ringdrill/views/plan_view.dart';
import 'package:ringdrill/views/widgets/catalog_browser.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:ringdrill/views/widgets/picker_error_banner.dart';
import 'package:ringdrill/views/widgets/plan_text.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';
import 'package:ringdrill/views/widgets/ringdrill_text.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> showAddExercisesDialog(BuildContext context) {
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
          child: const _AddExercisesBody(),
        ),
      ),
    );
  }

  return showRingdrillActionSheet<void>(
    context: context,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: const _AddExercisesBody(),
    ),
  );
}

Plan projectMergedPlan(
  Plan active,
  Plan source,
  List<String> selectedExerciseUuids,
) {
  final selected = source.exercises.where(
    (exercise) => selectedExerciseUuids.contains(exercise.uuid),
  );
  return active.copyWith(
    exercises: _unionByUuid(active.exercises, selected, (item) => item.uuid),
    teams: _unionByUuid(active.teams, source.teams, (item) => item.uuid),
  );
}

Plan applyProjectedMerge(
  Plan active,
  Plan source,
  List<String> selectedExerciseUuids,
) {
  return projectMergedPlan(active, source, selectedExerciseUuids);
}

List<T> _unionByUuid<T>(
  Iterable<T> base,
  Iterable<T> incoming,
  String Function(T item) uuid,
) {
  final byUuid = {for (final item in base) uuid(item): item};
  for (final item in incoming) {
    byUuid[uuid(item)] = item;
  }
  return byUuid.values.toList();
}

class _AddExercisesBody extends StatefulWidget {
  const _AddExercisesBody();

  @override
  State<_AddExercisesBody> createState() => _AddExercisesBodyState();
}

class _AddExercisesBodyState extends State<_AddExercisesBody>
    with SingleTickerProviderStateMixin {
  final _planService = PlanService();
  late final TabController _tabController;

  /// Last error message produced by the From-File tab's picker flow.
  /// Rendered inline so the user sees it instead of having it disappear
  /// behind the modal backdrop — same reasoning as the library dialog.
  String? _fromFileError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_fromFileError != null && _tabController.index != 2) {
        setState(() => _fromFileError = null);
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
                Tab(text: localizations.addFromFile),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFromPlans(context),
                  _buildFromCatalog(context),
                  _buildFromFile(context),
                ],
              ),
            ),
          ],
        ),
      ),
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
                    onPressed: () => _mergeFromFile(context),
                  ),
                  if (_fromFileError != null) ...[
                    const SizedBox(height: 20),
                    PickerErrorBanner(
                      message: _fromFileError!,
                      onDismiss: () => setState(() => _fromFileError = null),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        TabFooter(subtitle: localizations.addExercisesFromFileSubtitle),
      ],
    );
  }

  Widget _buildFromPlans(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final activeUuid = _planService.activePlanUuid;
    final plans = _planService
        .listPlans()
        .where((plan) => plan.uuid != activeUuid)
        .toList();

    // Mirror the "Åpne plan" dialog's "Mine planer" tab
    // (_LibraryBodyState._buildMyPlans): ExpandableTile cards on the
    // scaffold colour, with the shared source · exercise count ·
    // last-updated subtitle, so pulling exercises from a plan looks like
    // the same picker as opening one.
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Expanded(
            child: plans.isEmpty
                ? EmptyState(
                    icon: Icons.folder_open_outlined,
                    text: localizations.addExercisesEmptyMyPlans,
                  )
                : ListView.builder(
                    // Matches _buildMyPlansList: ExpandableTile's own 5px
                    // vertical margin plus this 5px makes every edge 10px.
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    itemCount: plans.length,
                    itemBuilder: (context, index) {
                      final plan = plans[index];
                      final loaded = _planService.loadPlan(plan.uuid) ?? plan;
                      return ExpandableTile(
                        // Neutral leading: this list is a source to pull
                        // exercises from, not a single-select of the active
                        // plan, so it uses an add glyph rather than the
                        // active/inactive radio the "Mine planer" tab shows.
                        leading: const Icon(Icons.playlist_add, size: 24),
                        // Cross-plan list — see library_view.
                        title: RingDrillText.forPlan(loaded, plan.name),
                        subtitle: Text(planSubtitle(localizations, loaded)),
                        onOpen: () => _mergeIntoActivePlan(context, loaded),
                      );
                    },
                  ),
          ),
          TabFooter(subtitle: localizations.addExercisesMyPlansSubtitle),
        ],
      ),
    );
  }

  Widget _buildFromCatalog(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final activeSlug = _activeCatalogSlug();
    return CatalogBrowser(
      subtitle: localizations.addExercisesOnlineSubtitle,
      installedSlugs: _installedCatalogSlugs(),
      // Hide the active plan's catalog source: merging it back into itself
      // would either be a no-op (same content) or silently duplicate every
      // exercise. The user is already adding to that plan.
      itemFilter: activeSlug == null ? null : (item) => item.slug != activeSlug,
      onItemTap: (context, item) => _mergeFromCatalog(context, item),
    );
  }

  String? _activeCatalogSlug() {
    return _planService.activePlan?.source.whenOrNull(
      catalog: (slug, latestEtag, installedAt, latestVersion) => slug,
    );
  }

  Set<String> _installedCatalogSlugs() {
    return _planService
        .listPlans()
        .map(
          (plan) => plan.source.whenOrNull(
            catalog: (slug, latestEtag, installedAt, latestVersion) => slug,
          ),
        )
        .whereType<String>()
        .toSet();
  }

  Future<void> _mergeFromCatalog(
    BuildContext context,
    MarketFeedItem item,
  ) async {
    final localizations = AppLocalizations.of(context)!;
    try {
      final download = await active_actions.buildCatalogClient().download(
        item.slug,
      );
      if (!context.mounted) return;
      final source = download.file.plan();
      await _mergeIntoActivePlan(context, source);
    } on Exception catch (e, stackTrace) {
      if (context.mounted) {
        _showSnackBar(context, localizations.libraryErrorLoad);
      }
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
    }
  }

  Future<void> _mergeFromFile(BuildContext context) async {
    // Wipe any stale banner before kicking off — re-tapping after a
    // bad pick should read as a fresh attempt, not a stuck error.
    if (_fromFileError != null) setState(() => _fromFileError = null);
    final localizations = AppLocalizations.of(context)!;
    final drillFile = await PlanPageController.pickOpenFile(
      context,
      _constraintsFor(context),
      localizations,
    );
    if (!context.mounted || drillFile == null) return;

    try {
      final source = drillFile.plan();
      final selectedUuids = await _selectAndConfirmMerge(context, source);
      if (!context.mounted || selectedUuids == null) return;

      final plan = await _planService.importPlan(
        localizations,
        drillFile,
        onSelect: (items) async =>
            items.where((exercise) => selectedUuids.contains(exercise.uuid)),
      );
      if (!context.mounted || plan == null) return;
      _showSnackBar(context, localizations.importSuccess(drillFile.fileName));
      Navigator.pop(context);
    } on DrillFormatException catch (e) {
      // Format errors are bad input, not bugs. Show the reason-
      // specific message inline so the user sees it (a snackbar from
      // inside this dialog lands behind the modal backdrop), and
      // skip Sentry.
      if (mounted) {
        setState(() {
          _fromFileError = drillFormatMessage(
            localizations,
            drillFile.fileName,
            e.reason,
          );
        });
      }
    } on Exception catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          _fromFileError = localizations.importFailure(drillFile.fileName);
        });
      }
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
    }
  }

  Future<void> _mergeIntoActivePlan(BuildContext context, Plan source) async {
    final merged = await mergePlanIntoActivePlan(context, source);
    if (!context.mounted || merged == null) return;
    Navigator.pop(context);
  }
}

/// Shows the exercise-selection screen for merging [source] into the active
/// plan, confirms via a diff dialog when the merge would touch existing
/// exercises/teams, then performs the merge. Top-level (not tied to
/// [_AddExercisesBodyState]) so the Open/Import bottom sheet for a shared
/// `/i/`/`/o/` plan can run the exact same flow — same selection screen,
/// same "LEGG TIL"/addAction wording, same diff confirmation — instead of a
/// second, less complete "import" path with its own label.
///
/// Returns the merged active [Plan], or null if the user cancelled at
/// any step (no selection, or declined the diff confirmation).
Future<Plan?> mergePlanIntoActivePlan(BuildContext context, Plan source) async {
  final localizations = AppLocalizations.of(context)!;
  final selectedUuids = await _selectAndConfirmMerge(context, source);
  if (!context.mounted || selectedUuids == null) return null;

  return PlanService().mergeFromPlan(localizations, source, selectedUuids);
}

Future<List<String>?> _selectAndConfirmMerge(
  BuildContext context,
  Plan source,
) async {
  final localizations = AppLocalizations.of(context)!;
  final active = PlanService().activePlan;
  if (active == null) return null;

  final selectedUuids = await PlanPageControllerBase.selectExercises(
    context,
    localizations.addExercisesTitle,
    source.exercises,
    localizations,
    confirmLabel: localizations.addAction,
    preselectAll: true,
    showSelectAllControls: true,
    plan: source,
  );
  if (!context.mounted || selectedUuids.isEmpty) return null;

  final projected = projectMergedPlan(active, source, selectedUuids);
  final diff = diffPlans(active, projected);
  if (diff.modifiedExercises.isEmpty && diff.modifiedTeams.isEmpty) {
    return selectedUuids;
  }

  final apply = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(localizations.confirmChangesTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DiffGroup(
                title: localizations.catalogDiffExercises,
                added: diff.addedExercises,
                removed: diff.removedExercises,
                modified: diff.modifiedExercises,
              ),
              DiffGroup(
                title: localizations.catalogDiffTeams,
                added: diff.addedTeams,
                removed: diff.removedTeams,
                modified: diff.modifiedTeams,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(localizations.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(localizations.apply),
        ),
      ],
    ),
  );

  return apply == true ? selectedUuids : null;
}

BoxConstraints _constraintsFor(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return BoxConstraints.tight(size);
}

/// Delegates to [showRingdrillSnackBar] so a plan/exercise name carrying a
/// `{{var.*}}` token is resolved rather than shown literally.
void _showSnackBar(BuildContext context, String message, {Plan? plan}) =>
    showRingdrillSnackBar(context, message, plan: plan);
