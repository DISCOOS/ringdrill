import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/services/edit_permissions.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/theme.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/active_plan_actions.dart' as active_actions;
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/drill_player/drill_player_scope.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/plan_form_screen.dart';
import 'package:ringdrill/views/roleplay_list_view.dart';
import 'package:ringdrill/views/shared_file_widget.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/station_form_screen.dart';
import 'package:ringdrill/views/station_list_view.dart';
import 'package:ringdrill/views/teams_view.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/edit_affordance.dart';
import 'package:ringdrill/views/widgets/exercise_description_rollup.dart';
import 'package:ringdrill/views/widgets/exercise_mini_map.dart';
import 'package:ringdrill/views/widgets/exercise_number_badge.dart';
import 'package:ringdrill/views/widgets/exercise_scope.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:ringdrill/views/widgets/live_accent.dart';
import 'package:ringdrill/views/widgets/plan_text.dart';
import 'package:ringdrill/views/widgets/reorderable_section.dart';
import 'package:ringdrill/views/widgets/resolved_markdown_text.dart';
import 'package:ringdrill/views/widgets/ringdrill_text.dart';
import 'package:ringdrill/views/widgets/start_here_pill.dart';
import 'package:ringdrill/views/widgets/station_number_badge.dart';
import 'package:ringdrill/views/widgets/station_position_panel.dart';
import 'package:ringdrill/views/widgets/station_role_summary.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';
import 'package:ringdrill/views/widgets/teaching_empty_state.dart';

import 'exercise_form_screen.dart';
import 'plan_additions.dart';

export 'package:ringdrill/web/plan_page_controller.dart'
    if (dart.library.io) 'plan_page_controller.dart';

enum PlanSegment { exercises, stations, script, teams }

/// URL slug for a [PlanSegment]. Mirrors the constants in
/// [app_routes.dart] and is used by the segment switcher and the router
/// redirect gate (ADR-0032 *Activation contract*).
extension PlanSegmentUrl on PlanSegment {
  String get urlSlug => switch (this) {
    PlanSegment.exercises => planSegmentExercisesSlug,
    PlanSegment.stations => planSegmentStationsSlug,
    PlanSegment.script => planSegmentScriptSlug,
    PlanSegment.teams => planSegmentTeamsSlug,
  };
}

/// Inverse of [PlanSegmentUrl.urlSlug]. Returns `null` for unknown
/// slugs so the redirect gate can fall back to the default segment.
PlanSegment? planSegmentFromSlug(String slug) => switch (slug) {
  planSegmentExercisesSlug => PlanSegment.exercises,
  planSegmentStationsSlug => PlanSegment.stations,
  planSegmentScriptSlug => PlanSegment.script,
  planSegmentTeamsSlug => PlanSegment.teams,
  _ => null,
};

/// The [PlanSegment] that owns [target], so a redirect that changes the
/// detail target (e.g. a cross-entity link such as the Spill viewer's
/// post-context card) can drive the wide master pane to follow. Returns
/// `null` for [BriefSheetTarget]: the brief is a modal, not a master-detail
/// selection, so the master is left untouched. Centralizes the mapping so
/// callers never need their own `is StationSheetTarget` checks.
PlanSegment? segmentForTarget(ContextSheetTarget target) => switch (target) {
  ExerciseSheetTarget() => PlanSegment.exercises,
  StationSheetTarget() => PlanSegment.stations,
  RoleSheetTarget() => PlanSegment.script,
  TeamSheetTarget() || TeamOverviewSheetTarget() => PlanSegment.teams,
  BriefSheetTarget() => null,
};

enum _SortAction { byStartTime, alphabetically }

class PlanView extends StatefulWidget {
  const PlanView({
    super.key,
    required this.controller,
    required this.stationListController,
    required this.rolePlaysController,
    this.refreshIndicatorKey,
  });

  final PlanPageControllerBase controller;
  final StationListController stationListController;
  final RolePlaysController rolePlaysController;

  /// Lets the host (`MainScreen`) reuse this view's pull-to-refresh
  /// [RefreshIndicator] from elsewhere — the drawer's "Oppdater fra
  /// katalog" entry triggers it via [CatalogRefreshIndicatorRegistry]
  /// instead of running the refresh with no visible progress. Null in
  /// contexts that don't need that (e.g. most tests).
  final GlobalKey<RefreshIndicatorState>? refreshIndicatorKey;

  @override
  State<PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends State<PlanView> {
  final _planService = PlanService();
  final List<StreamSubscription> _subscriptions = [];
  List<Exercise> _exercises = [];
  ExerciseEvent? _liveEvent;
  String? _expandedExerciseUuid;

  // Whether the overview prose is expanded ("show more"). Held here so it
  // survives the overview scrolling out of view and back.
  bool _overviewExpanded = false;

  @override
  void initState() {
    super.initState();
    _initExercises();
    // Treat a `done` event as "no live exercise" so a stopped exercise
    // stops being painted with the blue live-card treatment and the
    // "FERDIG" subtitle stub. The service keeps `_last` around after
    // `stop()` for diagnostics, but the list views only care about
    // currently-live exercises.
    _liveEvent = _filterLive(ExerciseService().last);

    // Listen to exercise changes
    _subscriptions.add(
      _planService.events.listen((event) {
        setState(() {
          _exercises = _planService.loadExercises();
        });
      }),
    );

    // The play/stop control used to live on each card; that part no longer
    // needs ExerciseService updates here. We re-subscribe so the live "blue
    // card" marker on the running exercise — mirroring the team view —
    // tracks start/stop/phase transitions while the user is on this tab.
    _subscriptions.add(
      ExerciseService().events.listen((event) {
        if (!mounted) return;
        setState(() {
          _liveEvent = _filterLive(event);
        });
      }),
    );

    widget.controller.activeSegment.addListener(_onSegmentChanged);
  }

  void _onSegmentChanged() {
    // Exit reorder mode whenever the user switches to another segment so the
    // exercises list always starts in the clean default view on re-entry.
    widget.controller.exerciseReorderMode.value = false;
  }

  @override
  void dispose() {
    widget.controller.activeSegment.removeListener(_onSegmentChanged);
    super.dispose();
    for (var e in _subscriptions) {
      e.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final targetNotifier = MasterDetailScope.maybeOf(context)?.target;
    // ----------------------------------------------------------------
    // The exercises segment body: a slim list header (sort + reorder
    // toggle) pinned above the scrollable list. ReorderableSection owns
    // the mode toggle, the in-memory draft, and the deferred-commit
    // logic (ADR-0035, ADR-0036). The host supplies the reorderMode
    // notifier so _onSegmentChanged can force-exit reorder mode on
    // segment switch.
    // ----------------------------------------------------------------

    // Build a row for a given exercise. [reordering] drives gesture
    // suspension; [dragHandle] is passed as ExerciseCard.trailing in
    // reorder mode and ignored in default mode.
    Widget buildExerciseRow(
      BuildContext context,
      Exercise exercise,
      int index,
      bool reordering,
      Widget dragHandle,
    ) {
      // Numbered, not name-only: matches the app-wide station-marker
      // convention (station's plan number as MapMarkerSpec.shortLabel,
      // "number name" as the full label) so this card's map behaves the
      // same as every other station-position surface once labels are
      // shown, instead of showing bare names with no zoom-tiered short
      // form at all.
      final markers = exercise.getNumberedLocations(
        exerciseNumber: index + 1,
        format:
            _planService.activePlan?.stationNumberFormat ??
            StationNumberFormat.dotted,
      );
      final selectedTarget = targetNotifier?.value;
      final isSelected =
          selectedTarget is ExerciseSheetTarget &&
          selectedTarget.exerciseUuid == exercise.uuid;

      if (reordering) {
        // Drag-handle variant: trailing is the handle; row body gestures
        // suspended (no onOpen, onLongPress, onToggle).
        return ExerciseCard(
          exercise: exercise,
          plan: _planService.activePlan,
          exerciseNumber: index + 1,
          localizations: l10n,
          markers: markers,
          liveEvent: _liveEvent,
          selected: isSelected,
          trailing: dragHandle,
          // allowExpand: false suppresses the chevron; the drag handle is
          // the only trailing affordance in reorder mode.
          allowExpand: false,
        );
      }

      // Default mode: swipe- and long-press-to-edit, gated on the role
      // (ADR-0057) — an exercise is director-only, and frozen while it runs.
      return EditableRow(
        target: EditTarget.exercise,
        exerciseUuid: exercise.uuid,
        dismissKey: ValueKey(exercise.uuid),
        label: l10n.editExercise,
        onEdit: () => _openExerciseForm(context, l10n, exercise),
        builder: (context, onLongPress) => ExerciseCard(
          exercise: exercise,
          plan: _planService.activePlan,
          exerciseNumber: index + 1,
          localizations: l10n,
          markers: markers,
          liveEvent: _liveEvent,
          selected: isSelected,
          // trailing: null → ExpandableTile shows its own expand chevron.
          expanded: _expandedExerciseUuid == exercise.uuid,
          onToggle: () {
            setState(() {
              _expandedExerciseUuid = _expandedExerciseUuid == exercise.uuid
                  ? null
                  : exercise.uuid;
            });
          },
          onLongPress: onLongPress,
          // V1: live card opens the DrillPlayer sheet (DESIGN-001).
          // All other cards keep the ContextSheet flow.
          // openContextTarget owns the live-vs-planning split (ADR-0056):
          // a running exercise opens in the player, anything else in the
          // ordinary sheet. This used to branch here and push a bare
          // CoordinatorScreen with no ContextSheet above it, so the player's
          // own mini bar mutated the shell's detail pane behind it.
          onOpen: () => unawaited(
            openContextTarget(
              context,
              ExerciseSheetTarget(exerciseUuid: exercise.uuid),
            ),
          ),
        ),
      );
    }

    final exerciseSegment = _exercises.isEmpty
        ? SliverFillRemaining(
            hasScrollBody: false,
            child: TeachingEmptyState(
              icon: Icons.update,
              title: l10n.emptyExercisesTitle,
              body: l10n.emptyExercisesBody,
            ),
          )
        : ReorderableSection<Exercise>(
            sliver: true,
            items: _exercises,
            keyOf: (e) => ValueKey(e.uuid),
            orderLabel: l10n.exerciseSortBy,
            // Reordering exercises renumbers them for everyone (ADR-0057).
            target: EditTarget.exercise,
            sortActions: [
              (
                label: l10n.exerciseSortByStartTimeShort,
                onPressed: () => _sortExercises(_SortAction.byStartTime),
              ),
              (
                label: l10n.exerciseSortAlphabeticallyShort,
                onPressed: () => _sortExercises(_SortAction.alphabetically),
              ),
            ],
            // Hand the controller notifier to ReorderableSection so
            // _onSegmentChanged can force-exit reorder mode by flipping it.
            reorderMode: widget.controller.exerciseReorderMode,
            onCommitReorder: (newOrder) {
              // Show the committed order immediately (no async round-trip).
              setState(() => _exercises = newOrder);
              _planService.reorderExercises(
                newOrder.map((e) => e.uuid).toList(),
              );
            },
            itemBuilder: buildExerciseRow,
          );
    final exerciseBody = kIsWeb
        ? exerciseSegment
        : SharedFileWidget(child: exerciseSegment);

    // The overview and segmented switcher are real slivers ahead of the
    // segment's own row slivers in ONE CustomScrollView per segment — not
    // siblings above a separately-scrolling body, and not a second
    // NestedScrollView-coordinated scrollable. A single scroll view is what
    // makes both requirements hold at once:
    //  - the switcher is pinned (SliverPersistentHeader) so it stays visible
    //    while the rows scroll beneath it, and the overview above it scrolls
    //    away only when the rows are long enough to need the room — ordinary
    //    sliver layout, no manual collapse logic;
    //  - a wrapping RefreshIndicator sees one real Scrollable, so a pull
    //    started anywhere in the segment (over the overview, the switcher,
    //    or the rows) reaches the same scroll position and triggers
    //    correctly, with no NestedScrollView inner/outer ambiguity.
    // Each segment gets its own CustomScrollView instance (IndexedStack keeps
    // all four mounted so each keeps its own scroll/expansion state across
    // switches, same as before this change).
    Widget buildSegmentScrollView(
      List<Widget> contentSlivers, {
      Widget? footer,
      Widget? overlay,
    }) {
      Widget scrollView = CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            // The overview itself is read-only content everyone sees; only its
            // edit entry point is gated (ADR-0057). A null onEdit makes the card
            // untappable and drops the empty-state "Rediger plan" row, which is
            // nothing but an edit CTA.
            child: EditGate(
              target: EditTarget.plan,
              builder: (context, allowed) => _PlanOverview(
                expanded: _overviewExpanded,
                onToggleExpanded: () =>
                    setState(() => _overviewExpanded = !_overviewExpanded),
                onEdit: allowed ? () => _openPlanForm(context, l10n) : null,
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SwitcherHeaderDelegate(controller: widget.controller),
          ),
          ...contentSlivers,
        ],
      );
      if (overlay != null) {
        scrollView = Stack(
          children: [
            Positioned.fill(child: scrollView),
            overlay,
          ],
        );
      }
      if (footer == null) return scrollView;
      return Column(
        children: [
          Expanded(child: scrollView),
          footer,
        ],
      );
    }

    final plan = _planService.activePlan;
    final isCatalogPlan = plan != null && active_actions.isCatalogPlan(plan);

    final segmentedBody = ValueListenableBuilder<PlanSegment>(
      valueListenable: widget.controller.activeSegment,
      builder: (context, activeSegment, _) {
        return IndexedStack(
          index: activeSegment.index,
          children: [
            buildSegmentScrollView([exerciseBody]),
            buildSegmentScrollView(
              [StationListView(controller: widget.stationListController)],
              footer: StationFilterBanner(
                controller: widget.stationListController,
              ),
            ),
            buildSegmentScrollView(
              [RolePlayListView(controller: widget.rolePlaysController)],
              footer: RolePlaysFilterBanner(
                controller: widget.rolePlaysController,
              ),
              overlay: RolePlaysCreateFab(
                controller: widget.rolePlaysController,
              ),
            ),
            buildSegmentScrollView([const TeamsView()]),
          ],
        );
      },
    );

    // Drag-to-update is only meaningful for a plan installed from the online
    // catalog — local plans have nothing to refresh against. Reusing
    // `refreshActivePlanFromCatalog` (the same flow as the drawer's "Oppdater
    // fra katalog" entry) means an unreachable catalog is already handled:
    // it shows the existing "unavailable" snackbar rather than failing
    // silently, so there is no need to pre-check online status here.
    if (!isCatalogPlan) return segmentedBody;
    return RefreshIndicator(
      key: widget.refreshIndicatorKey,
      onRefresh: () => active_actions.refreshActivePlanFromCatalog(context),
      child: segmentedBody,
    );
  }

  void _initExercises() {
    _exercises = _planService.loadExercises();
  }

  Future<void> _openPlanForm(
    BuildContext context,
    AppLocalizations localizations,
  ) async {
    // On the very first launch there is no active plan yet — the
    // user tapped the empty-state "Edit plan" action without ever
    // adding an exercise. The previous early-return left the button
    // doing nothing; instead, create the default plan on demand
    // (same pattern as `saveExercise` and friends) so the form has
    // something to edit. After `ensureActivePlan`,
    // `activePlan` is guaranteed non-null.
    await _planService.ensureActivePlan(localizations);
    final plan = _planService.activePlan;
    if (plan == null || !context.mounted) return;
    final updated = await openFormSurface<Plan>(
      context,
      builder: (_) => PlanFormScreen(plan: plan),
    );
    if (updated != null && context.mounted) {
      await _planService.replacePlan(updated);
      // The overview reads from PlanService.activePlan on each build,
      // but the description/briefIntro shown comes from that snapshot —
      // setState forces a rebuild so the new prose appears immediately
      // instead of waiting for the next external event.
      setState(() {});
    }
  }

  Future<void> _openExerciseForm(
    BuildContext context,
    AppLocalizations localizations,
    Exercise exercise,
  ) async {
    final numberOfTeams = _planService.loadTeams().length;
    final result = await openFormSurface<ExerciseFormResult>(
      context,
      builder: (_) => ExerciseFormScreen(
        exercise: exercise,
        numberOfTeams: numberOfTeams == 0 ? null : numberOfTeams,
        variables: _planService.activePlan?.variables ?? const [],
      ),
    );
    if (result == null || !context.mounted) return;
    switch (result) {
      case ExerciseFormSave(:final exercise, :final additions):
        await applyVariableAdditionsToActivePlan(_planService, additions);
        await _planService.saveExercise(localizations, exercise);
      case ExerciseFormDelete(:final exercise):
        await _planService.deleteExercise(exercise.uuid);
    }
    if (mounted) setState(_initExercises);
  }

  /// One-shot sort: rewrites all exercise indices in the chosen order via
  /// [PlanService.reorderExercises] and refreshes the list. Available
  /// without entering reorder mode (ADR-0035 §"One-shot sort").
  Future<void> _sortExercises(_SortAction action) async {
    final sorted = [..._exercises];
    switch (action) {
      case _SortAction.byStartTime:
        sorted.sort((a, b) => a.startTime.compareTo(b.startTime));
      case _SortAction.alphabetically:
        sorted.sort((a, b) => a.name.compareTo(b.name));
    }
    await _planService.reorderExercises(sorted.map((e) => e.uuid).toList());
    if (mounted) setState(_initExercises);
  }

  /// Returns `event` only when it represents a currently-live exercise.
  /// A `done` event is dropped so the list view stops styling the
  /// stopped exercise as live (no "FERDIG" subtitle, no blue card).
  ExerciseEvent? _filterLive(ExerciseEvent? event) {
    if (event == null || event.isDone) return null;
    return event;
  }
}

/// Pins [_PlanSegmentSwitcher] to the top of a segment's `CustomScrollView`
/// (below the collapsing [_PlanOverview]) so it stays visible while the
/// rows scroll beneath it, matching the pre-sliver layout where the switcher
/// was an always-visible row above an `Expanded` list.
///
/// [SliverPersistentHeaderDelegate] requires a fixed extent — it cannot
/// measure the switcher's natural size — so [_extent] is a constant sized to
/// fit the segmented button row plus its padding. An opaque background is
/// required because the rows scroll underneath a pinned header; without one
/// they would show through.
class _SwitcherHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SwitcherHeaderDelegate({required this.controller});

  final PlanPageControllerBase controller;

  // Tallest natural height of `_PlanSegmentSwitcher` across platforms
  // (its 8px top padding plus the SegmentedButton's 48px row on mobile,
  // where standard visual density and padded tap targets apply). A
  // SliverPersistentHeaderDelegate must report a fixed extent since it
  // cannot measure its child, and the rendered content must fill that
  // extent exactly — a shorter child fails a sliver-geometry assertion
  // (paintExtent < layoutExtent). The SizedBox.expand below is what fills
  // `_extent`; the switcher itself must NOT be height-forced to it, because
  // on desktop/web (compact density, shrink-wrapped tap targets) the
  // SegmentedButton is naturally shorter and stretching it distorts the
  // segment outlines. Align gives it loose constraints instead.
  static const double _extent = 56;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Align(
          alignment: Alignment.topCenter,
          child: _PlanSegmentSwitcher(controller: controller),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SwitcherHeaderDelegate oldDelegate) {
    return oldDelegate.controller != controller;
  }
}

class _PlanSegmentSwitcher extends StatelessWidget {
  const _PlanSegmentSwitcher({required this.controller});

  final PlanPageControllerBase controller;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconOnly = constraints.maxWidth < 340;
        return ValueListenableBuilder<PlanSegment>(
          valueListenable: controller.activeSegment,
          builder: (context, activeSegment, _) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<PlanSegment>(
                  expandedInsets: EdgeInsets.zero,
                  // No check on the selected segment. It would add width on
                  // the selected item and wrap its label in the narrow
                  // master pane.
                  showSelectedIcon: false,
                  segments: [
                    _segment(
                      value: PlanSegment.exercises,
                      icon: Icons.update,
                      label: localizations.exercise(2),
                      iconOnly: iconOnly,
                    ),
                    _segment(
                      value: PlanSegment.stations,
                      icon: Icons.place,
                      label: localizations.stationsTab,
                      iconOnly: iconOnly,
                    ),
                    _segment(
                      value: PlanSegment.script,
                      icon: Icons.theater_comedy,
                      label: localizations.scriptSegment,
                      iconOnly: iconOnly,
                    ),
                    _segment(
                      value: PlanSegment.teams,
                      icon: Icons.group,
                      label: localizations.team(2),
                      iconOnly: iconOnly,
                    ),
                  ],
                  selected: {activeSegment},
                  onSelectionChanged: (selected) {
                    // ADR-0032 *Activation contract*: segment selection
                    // flows URL → state. Push the canonical path and let
                    // MainScreen._initTab write `activeSegment` when the
                    // router rebuilds. Falls back to a direct write only
                    // if no plan is active (defensive — the switcher
                    // should not be visible in that case).
                    final uuid = PlanService().activePlanUuid;
                    if (uuid == null) {
                      controller.activeSegment.value = selected.single;
                      return;
                    }
                    context.go(planSegmentPath(uuid, selected.single.urlSlug));
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  ButtonSegment<PlanSegment> _segment({
    required PlanSegment value,
    required IconData icon,
    required String label,
    required bool iconOnly,
  }) {
    return ButtonSegment<PlanSegment>(
      value: value,
      // Never show icon and label together: four icon+label segments
      // overflow the master pane (320-420 px) and wrap the label. Show the
      // label only in normal mode, and fall back to icon-only (with a
      // tooltip) when the pane is too narrow for text.
      icon: iconOnly ? Tooltip(message: label, child: Icon(icon)) : null,
      label: iconOnly
          ? null
          : Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
}

/// Collapsing read-only overview rendered above the segment switcher.
/// Scrolls off as the user moves down the active segment list.
class _PlanOverview extends StatelessWidget {
  const _PlanOverview({
    required this.expanded,
    required this.onToggleExpanded,
    required this.onEdit,
  });

  /// Whether the prose is shown in full. Owned by [_PlanViewState] so it
  /// survives the overview being hidden and shown by the scroll collapse.
  final bool expanded;
  final VoidCallback onToggleExpanded;

  /// Opens the [PlanFormScreen] so the active plan's description and brief
  /// markdown sections can be edited from the overview. The AppBar title still
  /// owns the quick-rename action; this is the deeper edit entry point.
  ///
  /// Null when this role may not edit the plan: the card stays, its tap does
  /// not, and the empty-state edit row is not rendered at all.
  final VoidCallback? onEdit;

  static const int _collapsedLines = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final plan = PlanService().activePlan;

    // The "no content" branch covers two cases that present the same
    // way to the user: there is no plan yet at all (first launch
    // before they tap anything), or there is a plan but its
    // description / brief sections are empty. Render the same
    // teaching affordance in both — the row turns the otherwise
    // empty space above the segmented switcher into a discoverable
    // entry point for the PlanFormScreen.
    final description = plan?.description.trim() ?? '';
    final briefIntro = plan == null
        ? null
        : _firstParagraphText(_resolvePlanText(plan, plan.briefIntroMd, l10n));
    final comms = plan == null
        ? null
        : _firstParagraphText(_resolvePlanText(plan, plan.commsMd, l10n));
    final beforeRound = plan == null
        ? null
        : _firstParagraphText(_resolvePlanText(plan, plan.beforeRoundMd, l10n));
    final hasContent =
        description.isNotEmpty ||
        briefIntro != null ||
        comms != null ||
        beforeRound != null;
    if (!hasContent) {
      if (onEdit == null) return const SizedBox.shrink();
      final scheme = Theme.of(context).colorScheme;
      final textTheme = Theme.of(context).textTheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        // Subtle "settings-row" affordance: muted background + leading
        // pencil + trailing chevron read as tappable without competing
        // with the segmented switcher below or the FAB's add-exercise
        // CTA. Less prominent than a FilledButton/tonal would be, more
        // discoverable than the bare TextButton it replaces.
        child: Material(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.editPlan,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Render the filled state in the SAME soft container the empty
    // state uses, so the visual language is consistent: same muted
    // surface, same rounded corners, same tap target opening the
    // PlanFormScreen. The content inside the container changes
    // (description + optional brief sections + Show more/less),
    // but the container itself is one stable element above the
    // segmented switcher — no competing Card elevation.
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final briefSections = <({String label, String text})>[
      if (briefIntro != null)
        (label: l10n.briefSectionPlanIntro, text: briefIntro),
      if (comms != null) (label: l10n.briefSectionPlanComms, text: comms),
      if (beforeRound != null)
        (label: l10n.briefSectionPlanBeforeRound, text: beforeRound),
    ];
    final maxLines = expanded ? null : _collapsedLines;
    final overflow = expanded ? TextOverflow.clip : TextOverflow.ellipsis;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                final descriptionOverflows =
                    description.isNotEmpty &&
                    _exceedsLines(
                      context,
                      description,
                      textTheme.bodyMedium,
                      maxWidth,
                    );

                // Edge case: brief sections are filled but
                // description is empty. Collapsed-state would
                // otherwise be blank above the toggle, so promote
                // the first brief section into the always-visible
                // slot (with its label, since it's not the
                // description). The remaining sections still hide
                // behind "Show more".
                final hasDescription = description.isNotEmpty;
                final primaryBrief = hasDescription
                    ? null
                    : briefSections.firstOrNull;
                final hiddenWhenCollapsed = hasDescription
                    ? briefSections
                    : briefSections.skip(1).toList();
                final toggleVisible =
                    descriptionOverflows || hiddenWhenCollapsed.isNotEmpty;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasDescription)
                      RingDrillText.plain(
                        description,
                        style: textTheme.bodyMedium,
                        maxLines: maxLines,
                        overflow: overflow,
                      )
                    else if (primaryBrief != null) ...[
                      Text(primaryBrief.label, style: labelStyle),
                      const SizedBox(height: 2),
                      Text(
                        primaryBrief.text,
                        style: textTheme.bodyMedium,
                        maxLines: maxLines,
                        overflow: overflow,
                      ),
                    ],
                    if (expanded)
                      for (final section in hiddenWhenCollapsed) ...[
                        const SizedBox(height: 8),
                        Text(section.label, style: labelStyle),
                        const SizedBox(height: 2),
                        Text(section.text, style: textTheme.bodySmall),
                      ],
                    if (toggleVisible)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: const Size(0, 32),
                          ),
                          onPressed: onToggleExpanded,
                          child: Text(expanded ? l10n.showLess : l10n.showMore),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Whether [text] would exceed [_collapsedLines] at [maxWidth], used to
  /// decide whether the "show more" toggle is needed.
  bool _exceedsLines(
    BuildContext context,
    String text,
    TextStyle? style,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: _collapsedLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }

  /// Resolves `{{var.<name>}}` tokens and plan-scope cross-references
  /// before this preview truncates to the first paragraph, via the same
  /// [ResolvedMarkdownText.resolve] entry point used everywhere a
  /// plan-scope markdown field is shown outside the full brief — see that
  /// widget's doc comment for why the raw model field must never be read
  /// directly.
  String? _resolvePlanText(Plan plan, String? md, AppLocalizations l10n) {
    if (md == null) return null;
    return ResolvedMarkdownText.resolve(plan, md, l10n);
  }

  /// Returns the first paragraph of a markdown string stripped of leading
  /// markers (`#`, `>`, `-`), or null when the input is null or empty.
  String? _firstParagraphText(String? md) {
    if (md == null || md.trim().isEmpty) return null;
    final first = md.trim().split('\n\n').first.trim();
    // Strip leading markdown markers from each line.
    final stripped = first
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'^[#>*-]+\s*'), '').trim())
        .where((l) => l.isNotEmpty)
        .join(' ');
    return stripped.isEmpty ? null : stripped;
  }
}

class ExerciseCard extends StatefulWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    this.plan,
    this.exerciseNumber,
    required this.localizations,
    this.trailing,
    required this.markers,
    this.liveEvent,
    this.selected = false,
    this.expanded,
    this.onOpen,
    this.onLongPress,
    this.onToggle,
    this.allowStationActions = true,
    this.allowExpand = true,
    this.selectionControl,
  });

  /// Optional leading-most control, placed to the left of the number badge.
  /// The export/import picker injects its selection [Switch] here so the
  /// card is otherwise identical to the exercises tab (badge, styling,
  /// expandable map preview) while the toggle reads on the left.
  final Widget? selectionControl;

  final Widget? trailing;
  final Exercise exercise;

  /// Owning plan, used to resolve [exerciseNumberFormat] for the badge.
  /// When null, no badge is shown in [leading] and the live indicator
  /// falls back to the standard [LiveAccent.indicator] behaviour.
  final Plan? plan;

  /// 1-based position of [exercise] in [plan.exercises]. When null,
  /// no badge is shown (picker mode, no numbering needed).
  final int? exerciseNumber;

  final AppLocalizations localizations;
  final List<StationLocation> markers;

  /// Latest [ExerciseEvent] from [ExerciseService], if any. When this
  /// event belongs to the card's exercise, the card is rendered with
  /// the same blue "live" treatment used in `team_screen.dart` so the
  /// running exercise stands out at a glance. Default `null` keeps the
  /// neutral look — that is what the export/import picker uses, where
  /// "live" styling would be misleading.
  final ExerciseEvent? liveEvent;

  /// Whether this card is the currently selected item in a master-detail
  /// layout. Forwarded to [ExpandableTile.selected].
  final bool selected;

  /// Controlled expansion state. List owners set this together with
  /// [onToggle] so opening one card can collapse the previously-open card.
  /// Standalone cards leave it null and use local state.
  final bool? expanded;

  /// Fires when the row is tapped. When `null`, tapping the row toggles
  /// the inline map preview instead (used by the export/import picker
  /// where there is no detail screen to navigate to).
  final VoidCallback? onOpen;

  /// Fires when the row is long-pressed. The exercises tab uses this as
  /// its direct edit gesture; picker cards leave it unset.
  final VoidCallback? onLongPress;

  /// Controlled expansion callback. See [expanded].
  final VoidCallback? onToggle;

  /// Whether the expanded station list offers edit (swipe / long-press)
  /// and tap-to-open-detail gestures. The exercises tab enables them so
  /// the inline station list mirrors `StationListView` and the
  /// `CoordinatorScreen` station list. The export/import picker leaves it
  /// `false`: there the card is a read-only selection row, so the
  /// expanded body shows the map preview only.
  final bool allowStationActions;

  /// Whether the inline expand/collapse affordance (chevron + body) is
  /// active. Set to `false` in exercise reorder mode to suppress the
  /// chevron so the only trailing affordance is the drag handle.
  final bool allowExpand;

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  bool _expanded = false;

  /// Index of the station row whose inline detail is currently open, or
  /// null when all rows are collapsed. Single-value because each card
  /// shows exactly one exercise, so opening a row collapses the previous
  /// one — same mutex behaviour as `StationListView`.
  int? _expandedStationIndex;

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final localizations = widget.localizations;
    final markers = widget.markers;
    final hasMap = markers.isNotEmpty;
    // The picker disables station actions, so it falls back to the
    // map-only preview rather than rendering an interactive station list.
    final showStations =
        widget.allowStationActions && exercise.stations.isNotEmpty;
    // In reorder mode allowExpand is false, which suppresses the chevron and
    // the body so the only trailing affordance is the drag handle.
    final allowExpand = widget.allowExpand;
    final st = exercise.startTime.toMaterial();
    final et = exercise.endTime.toMaterial();
    final liveEvent = widget.liveEvent;
    final isLive = liveEvent?.exercise.uuid == exercise.uuid;
    final accent = LiveAccent.of(context, isLive: isLive);
    final subtitleParts = <String>[
      if (isLive) liveEvent!.getState(localizations),
      '${st.formal()} - ${et.formal()}',
      et.toDateTime().formal(localizations, st.toDateTime()),
      '${exercise.numberOfRounds} ${localizations.round(exercise.numberOfRounds).toLowerCase()}',
      '${exercise.numberOfTeams} ${localizations.team(exercise.numberOfTeams).toLowerCase()}',
    ];

    final exerciseNum = widget.exerciseNumber;
    final plan = widget.plan;
    final Widget? badge = (exerciseNum != null && plan != null)
        ? ExerciseNumberBadge(
            label: Numbering.exercise(plan.exerciseNumberFormat, exerciseNum),
            highlight: isLive,
          )
        : accent.indicator;
    // Selection control (picker) sits leftmost; the badge follows it. When
    // no selection control is supplied the leading is just the badge, so the
    // exercises tab renders exactly as before.
    final selectionControl = widget.selectionControl;
    final Widget? leading = selectionControl == null
        ? badge
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              selectionControl,
              if (badge != null) ...[const SizedBox(width: 8), badge],
            ],
          );

    return ExpandableTile(
      accent: accent,
      selected: widget.selected,
      leading: leading,
      title: RingDrillText.plain(
        exercise.name,
        overrides: widget.plan == null
            ? const {}
            : effectivePlanVariables(widget.plan!, exercise: exercise),
        style: TextStyle(fontWeight: FontWeight.bold, color: accent.foreground),
      ),
      subtitle: Text(subtitleParts.join(' | '), style: accent.textStyle),
      trailing: widget.trailing,
      onOpen: widget.onOpen,
      onLongPress: widget.onLongPress,
      onToggle: allowExpand && (showStations || hasMap)
          ? widget.onToggle ?? _toggleExpanded
          : null,
      expanded: widget.expanded ?? _expanded,
      body: allowExpand && (showStations || hasMap)
          ? _buildExpandedBody(exercise, markers, showStations)
          : null,
    );
  }

  Widget _buildExpandedBody(
    Exercise exercise,
    List<StationLocation> markers,
    bool showStations,
  ) {
    final liveEvent = widget.liveEvent?.exercise.uuid == exercise.uuid
        ? widget.liveEvent
        : null;

    // `{{exercise.*}}` (e.g. `numberOfRounds`) resolves via
    // `ExerciseScope.maybeOf` (resolve_scoped_field.dart) — without this
    // ancestor the exercise facet map is simply absent and the reference
    // stays literal (ADR-0048), which is what `ExerciseDescriptionRollup`'s
    // sections were hitting before this scope existed. `_buildStationDetail`
    // gets the same thing for free via `StationScope.forStation`, which
    // wraps its own `ExerciseScope` internally.
    return ExerciseScope(
      exercise: exercise,
      variableOverrides: exercise.variableOverrides,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExerciseDescriptionRollup(
            exercise: exercise,
            role: StaffRole.director,
            onTapSection: (_) {
              if (widget.onLongPress != null) {
                widget.onLongPress!();
              }
            },
          ),
          if (markers.isNotEmpty) ...[
            ExerciseMiniMap(
              exercise: exercise,
              markers: markers,
              liveEvent: liveEvent,
              mapKey: ValueKey<String>('exercise-card-map-${exercise.uuid}'),
            ),
            if (showStations) const SizedBox(height: 8),
          ],
          if (showStations)
            for (
              var stationIndex = 0;
              stationIndex < exercise.stations.length;
              stationIndex++
            )
              _buildStationRow(exercise, stationIndex, liveEvent),
        ],
      ),
    );
  }

  /// One station row inside the expanded card. Mirrors the
  /// `CoordinatorScreen` station list: swipe end-to-start or long-press to
  /// edit the station, and tap the row to open `StationScreen` in the
  /// context sheet. The round-by-round rotation strip is deliberately
  /// omitted here — the exercises list is an overview, so per-round team
  /// allocation belongs to the live player, not this card.
  Widget _buildStationRow(
    Exercise exercise,
    int stationIndex,
    ExerciseEvent? liveEvent,
  ) {
    return Builder(
      builder: (context) {
        final localizations = AppLocalizations.of(context)!;
        final station = exercise.stations[stationIndex];
        final isLive =
            liveEvent?.isRunning == true &&
            exercise.teamIndex(stationIndex, liveEvent!.currentRound) >= 0;
        final accent = LiveAccent.of(context, isLive: isLive);
        // Show the same numbered badge as the Poster segment so a station
        // reads as "1a", "2c" etc. here too. `stationIndex` is already the
        // 0-based position within this exercise, so the sub-index restarts
        // per exercise. Falls back to the live-accent indicator only when
        // the card has no owning plan / exercise number to format with.
        final exerciseNum = widget.exerciseNumber;
        final plan = widget.plan;
        final hasRoles = PlanService().loadRolePlays().any(
          (rp) =>
              rp.exerciseUuid == exercise.uuid &&
              rp.stationIndex == station.index,
        );
        final leading = (exerciseNum != null && plan != null)
            ? StationNumberBadge(
                label: Numbering.station(
                  plan.stationNumberFormat,
                  exerciseNumber: exerciseNum,
                  stationIndex: stationIndex,
                ),
                highlight: isLive,
                hasRoles: hasRoles,
              )
            : accent.indicator;
        // Gated on the role (ADR-0057), like the Poster segment's own rows —
        // these are the same posts, reached through an expanded exercise card.
        Widget buildTile(VoidCallback? onLongPress) => ExpandableTile(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
          color: Theme.of(context).brightness == Brightness.dark
              ? RingDrillColors.brandDeep
              : Theme.of(context).colorScheme.surfaceContainerHigh,
          accent: accent,
          leading: leading,
          title: RingDrillText.plain(
            station.name,
            overrides: plan == null
                ? const {}
                : effectivePlanVariables(
                    plan,
                    exercise: exercise,
                    station: station,
                  ),
            // ADR-0037 drillAccent: centralised size instead of hardcoded 18.
            style: TextStyle(
              fontSize: kDrillAccentFontSize,
              color: accent.foreground,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onOpen: () => _openStation(context, exercise, station),
          onLongPress: onLongPress,
          expanded: _expandedStationIndex == stationIndex,
          onToggle: () => setState(() {
            _expandedStationIndex = _expandedStationIndex == stationIndex
                ? null
                : stationIndex;
          }),
          body: _buildStationDetail(exercise, station),
        );
        return EditableRow(
          target: EditTarget.station,
          exerciseUuid: exercise.uuid,
          dismissKey: ValueKey<String>(
            'exercise-card-station-${exercise.uuid}-${station.index}',
          ),
          label: localizations.editStation,
          onEdit: () =>
              _openStationForm(context, localizations, exercise, station),
          builder: (context, onLongPress) => buildTile(onLongPress),
        );
      },
    );
  }

  /// Opens the station detail in the context sheet (or detail pane on
  /// wide layouts), matching the tap behaviour of `StationListView`.
  Future<void> _openStation(
    BuildContext context,
    Exercise exercise,
    Station station,
  ) async {
    await ContextSheet.of(context).show(
      context,
      StationSheetTarget(
        exerciseUuid: exercise.uuid,
        stationIndex: station.index,
      ),
    );
  }

  /// Opens the station form, guarding against edits while an exercise is
  /// running, then persists the edited station back into its exercise.
  /// Same flow as `StationListView._openStationForm`.
  Future<void> _openStationForm(
    BuildContext context,
    AppLocalizations localizations,
    Exercise exercise,
    Station station,
  ) async {
    final planService = PlanService();
    final exerciseService = ExerciseService();
    if (exerciseService.isStarted) {
      final runningExercise = exerciseService.last?.exercise;
      if (runningExercise != null) {
        showRingdrillSnackBar(
          context,
          localizations.stopExerciseFirst(runningExercise.name),
          exercise: runningExercise,
        );
      }
      return;
    }
    // DESIGN-009 prompt 5/4j: the delete-guard, save-block and the Persons
    // section's inline marker row all need to know which roleplays are
    // already linked to this station.
    final roleplays = planService
        .loadRolePlays()
        .where(
          (r) =>
              r.exerciseUuid == exercise.uuid &&
              r.stationIndex == station.index,
        )
        .toList();
    final result = await openFormSurface<StationFormResult>(
      context,
      builder: (_) => StationFormScreen(
        station: station,
        markers: planService.getLocations().toMarkerSpecs(),
        variables: planService.activePlan?.variables ?? const [],
        parentExercise: exercise,
        roleplays: roleplays,
      ),
    );
    if (!mounted || result == null) return;

    await applyVariableAdditionsToActivePlan(planService, result.additions);
    // A marker authored/edited inline from the Persons section's "Legg til
    // markør" / "Spilles av {navn}" row (DESIGN-009 prompt 4j) — held in
    // the post editor's own working copy, written back here alongside the
    // station's own save.
    await applyPendingRolePlayAdditions(
      planService,
      localizations,
      result.additions,
    );
    final current = planService.getExercise(exercise.uuid);
    if (current == null) return;
    final stations = [...current.stations];
    final idxInList = stations.indexWhere((s) => s.index == station.index);
    if (idxInList < 0) return;
    stations[idxInList] = result.station;
    await planService.saveExercise(
      localizations,
      current.copyWith(stations: stations),
    );
  }

  /// Inline detail shown when a station row is expanded. Mirrors the
  /// `StationListView` / `CoordinatorScreen` body: description, the shared
  /// position panel (label row + tappable mini-map) and the role summary.
  /// The mini-map height is kept compact (140) so the detail stays tight
  /// inside the already-expanded card.
  Widget _buildStationDetail(Exercise exercise, Station station) {
    final description = station.description;
    final plan = widget.plan;
    // Seed this station's own scope so `{{station.*}}` resolves in the
    // Exercises-tab expanded card instead of showing literally.
    return StationScope.forStation(
      exercise: exercise,
      station: station,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (description != null && description.trim().isNotEmpty) ...[
            RingDrillText.rich(
              description,
              overrides: plan == null
                  ? const {}
                  : effectivePlanVariables(
                      plan,
                      exercise: exercise,
                      station: station,
                    ),
            ),
            const SizedBox(height: 12),
          ],
          StationPositionPanel(
            exercise: exercise,
            station: station,
            mapHeight: 140,
            miniMapKey: ValueKey<String>(
              'exercise-card-station-map-${exercise.uuid}-${station.index}',
            ),
          ),
          const SizedBox(height: 12),
          StationRoleSummary(exercise: exercise, stationIndex: station.index),
        ],
      ),
    );
  }
}

abstract class PlanPageControllerBase extends ScreenController {
  PlanPageControllerBase({
    required this.stationListController,
    required this.rolePlaysController,
    required this.teamsPageController,
  });

  @protected
  final planService = PlanService();
  final StationListController stationListController;
  final RolePlaysController rolePlaysController;
  final TeamsPageController teamsPageController;
  final ValueNotifier<PlanSegment> activeSegment = ValueNotifier<PlanSegment>(
    PlanSegment.exercises,
  );

  /// Whether the Øvelser segment is currently in reorder mode.
  ///
  /// When `true` the list switches to [ReorderableListView] with trailing
  /// drag handles; when `false` it uses a plain [ListView] with the standard
  /// chevron affordance (ADR-0035).
  final ValueNotifier<bool> exerciseReorderMode = ValueNotifier<bool>(false);

  void dispose() {
    activeSegment.dispose();
    exerciseReorderMode.dispose();
  }

  @override
  String title(BuildContext context) =>
      planService.activePlan?.name ??
      // Generic tab label when no plan is active yet (first launch
      // before any plan has been created). Matches the bottom nav
      // label so the user sees a consistent name in both chrome
      // surfaces.
      AppLocalizations.of(context)!.planTab;

  @override
  Widget? buildFAB(BuildContext context, BoxConstraints constraints) {
    // Hide the "New exercise" FAB while the Øvelser segment is in reorder
    // mode: it floats over the trailing drag handles and blocks dragging the
    // bottom rows. Reorder mode has its own "Done" affordance in the list
    // header (ADR-0035/0036), so no FAB is needed there.
    if (activeSegment.value == PlanSegment.exercises &&
        exerciseReorderMode.value) {
      return null;
    }
    return switch (activeSegment.value) {
      // Gated on the role (ADR-0057): exercises are director-only.
      PlanSegment.exercises => IfCreatable(
        target: EditTarget.exercise,
        child: _buildExercisesFAB(context),
      ),
      PlanSegment.stations => stationListController.buildFAB(
        context,
        constraints,
      ),
      PlanSegment.script => rolePlaysController.buildFAB(context, constraints),
      PlanSegment.teams => teamsPageController.buildFAB(context, constraints),
    };
  }

  Widget _buildExercisesFAB(BuildContext context) {
    // heroTag is intentionally null. The FAB pushes ExerciseFormScreen via a
    // The destination has no FAB to morph into, so there is no hero
    // animation to preserve. With an explicit string tag the Scaffold's
    // _FloatingActionButtonTransition can keep both the outgoing and incoming
    // FAB widgets briefly alive (in its internal Stack) when the user switches
    // tabs faster than the FAB scale-in/out animation completes — that
    // produced the "multiple heroes that share the same tag" assertion seen
    // when bouncing between /plan and /stations. Disabling the Hero wrapper
    // entirely is the safe fix.
    final label = AppLocalizations.of(context)!.newExercise;
    // On a phone the extended FAB is wide enough to cover the bottom list
    // rows. Use the compact circular FAB there and keep the labelled extended
    // variant only where there is room (medium/expanded).
    final Widget fab;
    if (WindowSizeClass.of(context) == WindowSizeClass.compact) {
      fab = FloatingActionButton(
        heroTag: null,
        onPressed: () => _navigateToCreateExercise(context),
        tooltip: label,
        child: const Icon(Icons.add),
      );
    } else {
      fab = FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _navigateToCreateExercise(context),
        icon: const Icon(Icons.add),
        label: Text(label),
      );
    }

    if (planService.loadExercises().isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          StartHerePill(onActivate: () => _navigateToCreateExercise(context)),
          const SizedBox(width: 12),
          fab,
        ],
      );
    }
    return fab;
  }

  // Navigate to the CreateExerciseScreen to add a new exercise
  Future<void> _navigateToCreateExercise(BuildContext context) async {
    final result = await openFormSurface<ExerciseFormResult>(
      context,
      builder: (context) => ExerciseFormScreen(
        variables: planService.activePlan?.variables ?? const [],
      ),
    );

    // Creating a new exercise — only a save (or cancel), never a delete.
    if (result is ExerciseFormSave && context.mounted) {
      final localizations = AppLocalizations.of(context)!;
      await applyVariableAdditionsToActivePlan(planService, result.additions);
      // Add the new exercise and reload the list
      await planService.saveExercise(localizations, result.exercise);
    }
  }

  @override
  List<Widget>? buildActions(BuildContext context, BoxConstraints constraints) {
    // Sort and reorder controls for the Øvelser segment live in the in-list
    // ReorderableSection header rather than the AppBar (ADR-0035 §"List
    // header", ADR-0036). The AppBar only carries segment-independent actions.
    final segmentActions = switch (activeSegment.value) {
      PlanSegment.exercises => null,
      PlanSegment.stations => stationListController.buildActions(
        context,
        constraints,
      ),
      PlanSegment.script => rolePlaysController.buildActions(
        context,
        constraints,
      ),
      PlanSegment.teams => teamsPageController.buildActions(
        context,
        constraints,
      ),
    };
    // The brief renders the whole plan and is segment-independent, so it shows
    // on every lens, pinned rightmost (next to the status badge). Segment
    // actions (filter, cast roster) sit to its left.
    return [...?segmentActions, ...?_briefAction(context)];
  }

  /// The active segment's first row, as a detail target (collapsible-
  /// master-pane proposal: auto-select in the wide layout so the detail
  /// pane is never empty while the segment has content). Each segment
  /// mirrors its own list's ordering/filtering — the flat exercise→station/
  /// role scan `StationListView`/`RolePlayListView` build, respecting the
  /// shared exercise filter — so the auto-selected row is the same one the
  /// segment would show first.
  @override
  ContextSheetTarget? firstDetailTarget(BuildContext context) {
    return switch (activeSegment.value) {
      PlanSegment.exercises => _firstExerciseTarget(),
      PlanSegment.stations => _firstStationTarget(),
      PlanSegment.script => _firstRoleTarget(),
      PlanSegment.teams => _firstTeamTarget(),
    };
  }

  ContextSheetTarget? _firstExerciseTarget() {
    final exercise = planService.loadExercises().firstOrNull;
    return exercise == null
        ? null
        : ExerciseSheetTarget(exerciseUuid: exercise.uuid);
  }

  ContextSheetTarget? _firstStationTarget() {
    final filterUuid = stationListController.filterExerciseUuid.value;
    for (final exercise in planService.loadExercises()) {
      if (filterUuid != null && exercise.uuid != filterUuid) continue;
      final stations = [...exercise.stations]
        ..sort((a, b) => a.index.compareTo(b.index));
      final station = stations.firstOrNull;
      if (station != null) {
        return StationSheetTarget(
          exerciseUuid: exercise.uuid,
          stationIndex: station.index,
        );
      }
    }
    return null;
  }

  ContextSheetTarget? _firstRoleTarget() {
    final filterUuid = rolePlaysController.filterExerciseUuid.value;
    final rolePlays = planService.loadRolePlays();
    for (final exercise in planService.loadExercises()) {
      if (filterUuid != null && exercise.uuid != filterUuid) continue;
      final roles =
          rolePlays.where((rp) => rp.exerciseUuid == exercise.uuid).toList()
            ..sort((a, b) => a.index.compareTo(b.index));
      final role = roles.firstOrNull;
      if (role != null) return RoleSheetTarget(rolePlayUuid: role.uuid);
    }
    return null;
  }

  ContextSheetTarget? _firstTeamTarget() {
    final team = planService.loadTeams().firstOrNull;
    return team == null ? null : TeamOverviewSheetTarget(teamIndex: team.index);
  }

  /// The wide detail pane's selection, remembered per segment for the
  /// session so switching segments restores the row the user had already
  /// picked instead of re-running auto-select-first over it (fix for the
  /// collapsible-master-pane regression: segment switches used to reset the
  /// shared detail target unconditionally).
  final Map<PlanSegment, ContextSheetTarget?> _rememberedSelection = {};

  /// Records [target] as [segment]'s selection (the active segment when
  /// omitted). Called for explicit in-segment picks, auto-selected-first
  /// targets, and — with an explicit [segment] — a redirect's target-owning
  /// segment when that differs from the active one (see [segmentForTarget]);
  /// re-remembering an already-current target is harmless since it is what
  /// [rememberedTarget] would already return for a segment with no other
  /// memory.
  void rememberSelection(ContextSheetTarget target, {PlanSegment? segment}) {
    _rememberedSelection[segment ?? activeSegment.value] = target;
  }

  /// The remembered selection for [segment], or null when there is none yet
  /// or the remembered item no longer exists (deleted/reordered away) — the
  /// caller falls back to [firstDetailTarget] in that case.
  ContextSheetTarget? rememberedTarget(PlanSegment segment) {
    final target = _rememberedSelection[segment];
    if (target == null || !_targetStillExists(target)) return null;
    return target;
  }

  bool _targetStillExists(ContextSheetTarget target) {
    final exercises = planService.loadExercises();
    return switch (target) {
      ExerciseSheetTarget(:final exerciseUuid) => exercises.any(
        (e) => e.uuid == exerciseUuid,
      ),
      StationSheetTarget(:final exerciseUuid, :final stationIndex) =>
        exercises.any(
          (e) =>
              e.uuid == exerciseUuid &&
              e.stations.any((s) => s.index == stationIndex),
        ),
      RoleSheetTarget(:final rolePlayUuid) => planService.loadRolePlays().any(
        (r) => r.uuid == rolePlayUuid,
      ),
      TeamOverviewSheetTarget(:final teamIndex) => planService.loadTeams().any(
        (t) => t.index == teamIndex,
      ),
      TeamSheetTarget(:final exerciseUuid, :final teamIndex) => exercises.any(
        (e) => e.uuid == exerciseUuid && e.numberOfTeams > teamIndex,
      ),
      _ => false,
    };
  }

  List<Widget>? _briefAction(BuildContext context) {
    final activePlan = planService.activePlan;
    if (activePlan == null) return null;
    final localizations = AppLocalizations.of(context)!;
    return [
      IconButton(
        icon: const Icon(Icons.menu_book),
        tooltip: localizations.briefAction,
        onPressed: () =>
            GoRouter.of(context).push(planBriefPath(activePlan.uuid)),
      ),
    ];
  }

  /// Shows the exercise picker as a bottom sheet on small form factors and as
  /// a centered modal dialog on wide ones (same responsive behaviour as
  /// `showOpenPlanDialog`).
  ///
  /// Each row renders the expandable [ExerciseCard] so the user can see start
  /// and end time, rounds, teams, and tap the chevron to peek at a small map
  /// of the exercise's stations before choosing whether to include it.
  ///
  /// Named parameters drive the export/import flows:
  /// - [confirmLabel] overrides the primary-button label (e.g. "EKSPORTER",
  ///   "IMPORTER"). When omitted, falls back to [AppLocalizations.confirm].
  /// - [preselectAll] starts with every exercise checked. The export/import
  ///   flows use this so the default state is "everything on".
  /// - [showSelectAllControls] adds a row with "VELG ALLE" / "VELG INGEN"
  ///   text buttons above the list, plus a "N av M valgt" counter.
  static Future<List<String>> selectExercises(
    BuildContext context,
    String title,
    List<Exercise> exercises,
    AppLocalizations localizations, {
    String? confirmLabel,
    bool preselectAll = false,
    bool showSelectAllControls = false,
    Plan? plan,
  }) async {
    final List<String> selected = preselectAll
        ? exercises.map((e) => e.uuid).toList()
        : <String>[];
    final allUuids = exercises.map((e) => e.uuid).toList();
    String? expandedExerciseUuid;

    // We rely on the popped return value (not the mutated [selected] list) to
    // tell cancel from confirm. The list is pre-populated when
    // [preselectAll] is true, so reading it directly would treat a cancel
    // as "everything selected" and trigger an unintended export/import.
    final List<String>?
    popped = await showResponsiveSheetOrDialog<List<String>>(
      context,
      maximizeHeight: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final headerLabelStyle = Theme.of(context).textTheme.titleSmall
                ?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                );
            // Match the exercises tab: cards use `darkSurface` and there they
            // contrast because the scaffold behind them is the darker
            // `brandDeep`. The action sheet's own surface is `darkSurface` too,
            // which flattens that contrast — so paint the picker body with the
            // scaffold colour to bring the separation back.
            final sheetBackground = Theme.of(context).scaffoldBackgroundColor;
            return ColoredBox(
              color: sheetBackground,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 8.0,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      if (showSelectAllControls) ...[
                        const SizedBox(height: 8.0),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                localizations.selectedOfTotal(
                                  selected.length,
                                  exercises.length,
                                ),
                                style: headerLabelStyle,
                              ),
                            ),
                            TextButton(
                              onPressed: selected.length == exercises.length
                                  ? null
                                  : () {
                                      setState(() {
                                        selected
                                          ..clear()
                                          ..addAll(allUuids);
                                      });
                                    },
                              child: Text(localizations.selectAll),
                            ),
                            TextButton(
                              onPressed: selected.isEmpty
                                  ? null
                                  : () {
                                      setState(() => selected.clear());
                                    },
                              child: Text(localizations.selectNone),
                            ),
                          ],
                        ),
                        const Divider(height: 16.0),
                      ] else
                        const SizedBox(height: 16.0),
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: exercises.length,
                          itemBuilder: (context, index) {
                            final exercise = exercises[index];
                            final uuid = exercise.uuid;
                            // Numbered, not name-only — see buildExerciseRow's
                            // identical fix above for why.
                            final markers = exercise.getNumberedLocations(
                              exerciseNumber: index + 1,
                              format:
                                  PlanService()
                                      .activePlan
                                      ?.stationNumberFormat ??
                                  StationNumberFormat.dotted,
                            );
                            return ExerciseCard(
                              exercise: exercise,
                              // Reuse the exercises-tab rendering: passing the
                              // plan + 1-based number gives the same #N badge
                              // and dark-mode card styling. When [plan] is
                              // null (import/add without numbering) no badge is
                              // shown, same as before.
                              plan: plan,
                              exerciseNumber: plan == null ? null : index + 1,
                              localizations: localizations,
                              markers: markers,
                              allowStationActions: false,
                              expanded: expandedExerciseUuid == uuid,
                              // House rule (ExpandableTile): a row with an
                              // expandable body + chevron must supply onOpen.
                              // The picker has no context sheet to open, so a
                              // row tap toggles this exercise's selection —
                              // matching the switch. The chevron still expands
                              // the map preview.
                              onOpen: () {
                                setState(() {
                                  if (selected.contains(uuid)) {
                                    selected.remove(uuid);
                                  } else {
                                    selected.add(uuid);
                                  }
                                });
                              },
                              onToggle: () {
                                setState(() {
                                  expandedExerciseUuid =
                                      expandedExerciseUuid == uuid
                                      ? null
                                      : uuid;
                                });
                              },
                              // Selection toggle on the left (leading), before
                              // the number badge.
                              selectionControl: Switch.adaptive(
                                value: selected.contains(uuid),
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      selected.add(uuid);
                                    } else {
                                      selected.remove(uuid);
                                    }
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20.0),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: headerLabelStyle,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context, null);
                            },
                            child: Text(localizations.cancel),
                          ),
                          const SizedBox(width: 8.0),
                          FilledButton(
                            onPressed: selected.isEmpty
                                ? null
                                : () {
                                    Navigator.pop(context, selected);
                                  },
                            child: Text(confirmLabel ?? localizations.confirm),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    return popped ?? <String>[];
  }
}
