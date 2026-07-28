import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/views/drill_player/drill_player_scope.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/plan_additions.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/station_form_screen.dart';
import 'package:ringdrill/views/widgets/cast_picker_sheet.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/exercise_number_badge.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:ringdrill/views/widgets/live_accent.dart';
import 'package:ringdrill/views/widgets/reorderable_section.dart';
import 'package:ringdrill/views/widgets/ringdrill_picker.dart';
import 'package:ringdrill/views/widgets/ringdrill_text.dart';
import 'package:ringdrill/views/widgets/station_description_rollup.dart';
import 'package:ringdrill/views/widgets/station_number_badge.dart';
import 'package:ringdrill/views/widgets/station_position_panel.dart';
import 'package:ringdrill/views/widgets/station_role_summary.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';
import 'package:ringdrill/views/widgets/teaching_empty_state.dart';

class StationListView extends StatefulWidget {
  const StationListView({super.key, required this.controller});

  /// Owned by the parent (e.g. `_MainScreenState`). The view shares the
  /// same instance with `PageWidget` so the FAB and the list react to
  /// the same filter state. See the note in `_MainScreenState._pages`
  /// for why this is a constructor parameter and not an InheritedWidget
  /// lookup.
  final StationListController controller;

  @override
  State<StationListView> createState() => _StationListViewState();
}

class _StationListViewState extends State<StationListView> {
  final _planService = PlanService();
  StreamSubscription? _subscription;
  StreamSubscription<ExerciseEvent>? _exerciseSubscription;

  /// The effective plan-variable map (ADR-0046) at [station]'s scope. Empty
  /// when there is no active plan.
  Map<String, String> _overridesFor(Exercise exercise, Station station) {
    final plan = _planService.activePlan;
    if (plan == null) return const {};
    return effectivePlanVariables(plan, exercise: exercise, station: station);
  }

  // Identifies the open row by its owning exercise + station, not by the
  // per-exercise rowIndex. rowIndex restarts at 0 for every exercise's first
  // station, so keying on it made "station 1" of every exercise share one
  // expansion flag and open together. The (uuid, station.index) pair is
  // globally unique across the flat list.
  String? _expandedRowKey;
  ExerciseEvent? _liveEvent;

  static String _rowKey(Exercise exercise, Station station) =>
      '${exercise.uuid}-${station.index}';

  // Optimistic display of the committed reorder order. Set synchronously in
  // onCommitReorder so the new order is shown immediately without waiting for
  // the async save round-trip (same pattern as _exercises in PlanView).
  // Cleared when the service fires a refresh event (new data loaded).
  List<(int, Exercise, Station)>? _stagedRows;

  StationListController get _controller => widget.controller;

  // DESIGN-010 stage 3b: the Station description card renders per the settings
  // role (director sees the gated directorNotesMd section too), not an
  // in-sheet toggle. Defaults to director (participants do not use the
  // app) until [_bindRole] seeds the stored value, which is synchronous.
  AppUserRole _role = AppUserRole.director;

  /// Seeded synchronously and kept current: the role decides what this surface
  /// offers (ADR-0057), so it has to be right on the first frame *and* follow a
  /// change made from the drawer while this screen is open. It used to be awaited
  /// once, which was both a frame late and permanently stale.
  void _bindRole() {
    _role = loadStoredAppUserRole();
    appUserRole.addListener(_onRoleChanged);
  }

  void _onRoleChanged() {
    if (mounted) setState(() => _role = appUserRole.value);
  }

  @override
  void initState() {
    super.initState();
    _bindRole();
    // Drop `done` events so a stopped exercise's stations stop being
    // highlighted with the live-accent treatment on the badge and tile.
    _liveEvent = _filterLive(ExerciseService().last);
    _subscription = _planService.events.listen((_) {
      if (mounted) setState(() => _stagedRows = null);
    });
    // Track the running exercise so rows belonging to it get the same
    // blue "live" treatment used in the team and exercises views.
    _exerciseSubscription = ExerciseService().events.listen((event) {
      if (!mounted) return;
      setState(() {
        _liveEvent = _filterLive(event);
      });
    });
    _controller.filterExerciseUuid.addListener(_onFilterChanged);
  }

  @override
  void didUpdateWidget(covariant StationListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.filterExerciseUuid.removeListener(_onFilterChanged);
      widget.controller.filterExerciseUuid.addListener(_onFilterChanged);
    }
  }

  void _onFilterChanged() {
    if (!mounted) return;
    setState(() {
      _expandedRowKey = null;
      _stagedRows = null;
    });
  }

  @override
  void dispose() {
    appUserRole.removeListener(_onRoleChanged);
    _controller.filterExerciseUuid.removeListener(_onFilterChanged);
    _subscription?.cancel();
    _exerciseSubscription?.cancel();
    super.dispose();
  }

  /// Builds a flat list of `(exerciseNumber, Exercise, Station)`
  /// triples sorted by exercise order (matching the Exercises tab),
  /// then by station index within the exercise. `exerciseNumber` is the
  /// 1-based position in the unfiltered exercise list, kept stable
  /// across filter toggles so badge codes do not jump when the user
  /// narrows the view.
  List<(int, Exercise, Station)> _collectRows() {
    final exercises = _planService.loadExercises();
    final filterUuid = _controller.filterExerciseUuid.value;
    final rows = <(int, Exercise, Station)>[];
    for (var i = 0; i < exercises.length; i++) {
      final exercise = exercises[i];
      if (filterUuid != null && exercise.uuid != filterUuid) continue;
      final exerciseNumber = i + 1;
      final stations = [...exercise.stations]
        ..sort((a, b) => a.index.compareTo(b.index));
      for (final station in stations) {
        rows.add((exerciseNumber, exercise, station));
      }
    }
    return rows;
  }

  /// Returns the set of `(exerciseUuid, stationIndex)` pairs that have at
  /// least one [RolePlay] attached. Computed once per build so the badge
  /// "has markører" treatment doesn't re-scan roleplays per row.
  Set<(String, int)> _collectStationsWithRoles() {
    final pairs = <(String, int)>{};
    for (final rp in _planService.loadRolePlays()) {
      final idx = rp.stationIndex;
      if (idx == null) continue;
      pairs.add((rp.exerciseUuid, idx));
    }
    return pairs;
  }

  /// Returns `event` only when it represents a currently-live
  /// exercise. A `done` event (emitted by `ExerciseService.stop()`)
  /// is dropped so the station rows stop being styled as live.
  ExerciseEvent? _filterLive(ExerciseEvent? event) {
    if (event == null || event.isDone) return null;
    return event;
  }

  Exercise? _filterExercise() {
    final uuid = _controller.filterExerciseUuid.value;
    if (uuid == null) return null;
    return _planService.getExercise(uuid);
  }

  /// Returns the sliver content for the station rows, meant to be embedded
  /// directly in plan_view.dart's per-segment `CustomScrollView` (see
  /// [ReorderableSection.sliver]). The exercise filter banner is a separate
  /// widget ([StationFilterBanner]) rendered by the host outside the scroll
  /// view — it needs to stay pinned to the bottom of the segment's viewport
  /// rather than scroll with the rows, which a sliver can't do on its own.
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final allExercises = _planService.loadExercises();
    final hasAnyStation = allExercises.any((e) => e.stations.isNotEmpty);

    // Use staged rows (synchronous post-commit display) when available so the
    // new order is shown immediately after Done without waiting for the async
    // save to round-trip back through the service event.
    final rows = _stagedRows ?? _collectRows();
    final stationsWithRoles = _collectStationsWithRoles();
    final filterExercise = _filterExercise();

    final targetNotifier = MasterDetailScope.maybeOf(context)?.target;

    if (!hasAnyStation) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: TeachingEmptyState(
          icon: Icons.place,
          title: localizations.emptyStationsTitle,
          body: localizations.emptyStationsBody,
        ),
      );
    }
    if (rows.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              localizations.noStationsInExercise,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    {
      final isSingleExercise = filterExercise != null;

      Widget buildStationRow(
        BuildContext context,
        (int, Exercise, Station) row,
        int position,
        bool reordering,
        Widget dragHandle,
      ) {
        final (exerciseNumber, exercise, station) = row;
        final hasRoles = stationsWithRoles.contains((
          exercise.uuid,
          station.index,
        ));
        final selectedTarget = targetNotifier?.value;
        final isSelected =
            selectedTarget is StationSheetTarget &&
            selectedTarget.exerciseUuid == exercise.uuid &&
            selectedTarget.stationIndex == station.index;
        // The badge sub-index must restart at the first station of each
        // exercise (1a, 1b … 2a, 2b …), not run continuously across the
        // flat list. Rows are grouped contiguously by exercise, so the
        // exercise's first-row offset turns the global `position` into a
        // per-exercise local index. In single-exercise (filtered/reorder)
        // mode the block starts at 0, so this still equals the live drag
        // position and the badge renumbers correctly during a drag.
        final exerciseStart = rows.indexWhere(
          (r) => r.$2.uuid == exercise.uuid,
        );
        final localIndex = exerciseStart < 0
            ? position
            : position - exerciseStart;
        return _buildStationRow(
          context,
          localizations,
          exerciseNumber: exerciseNumber,
          exercise: exercise,
          station: station,
          rowIndex: localIndex,
          hasRoles: hasRoles,
          selected: isSelected,
          reordering: reordering,
          dragHandle: dragHandle,
        );
      }

      // Reorder is only meaningful when scoped to one exercise (ADR-0036
      // §"Where stations can be reordered"). When spanning exercises the whole
      // order header is irrelevant, so skip ReorderableSection entirely and
      // use a plain list — no header, no toggle.
      if (isSingleExercise) {
        return ReorderableSection<(int, Exercise, Station)>(
          sliver: true,
          items: rows,
          keyOf: (row) =>
              ValueKey('station-row-${row.$2.uuid}-${row.$3.index}'),
          orderLabel: localizations.exerciseSortBy,
          onCommitReorder: (newOrder) {
            final exerciseUuid = filterExercise.uuid;
            setState(() => _stagedRows = newOrder);
            final orderedOldIndices = newOrder.map((r) => r.$3.index).toList();
            _planService.reorderStations(exerciseUuid, orderedOldIndices);
          },
          itemBuilder: buildStationRow,
        );
      }
      return SliverPadding(
        padding: const EdgeInsets.only(top: 11),
        sliver: SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) => buildStationRow(
            context,
            rows[index],
            index,
            false,
            const SizedBox.shrink(),
          ),
        ),
      );
    }
  }

  Widget _buildStationRow(
    BuildContext context,
    AppLocalizations localizations, {
    required int exerciseNumber,
    required Exercise exercise,
    required Station station,
    required int rowIndex,
    required bool hasRoles,
    bool selected = false,
    bool reordering = false,
    Widget? dragHandle,
  }) {
    final rowKey = _rowKey(exercise, station);
    final expanded = !reordering && _expandedRowKey == rowKey;
    final colorScheme = Theme.of(context).colorScheme;
    final isLive = _liveEvent?.exercise.uuid == exercise.uuid;
    final accent = LiveAccent.of(context, isLive: isLive);

    final badge = StationNumberBadge(
      label: Numbering.station(
        _planService.activePlan?.stationNumberFormat ??
            StationNumberFormat.dotted,
        exerciseNumber: exerciseNumber,
        // rowIndex is the station's position within its own exercise (see
        // buildStationRow), so the badge sub-index restarts per exercise and
        // still renumbers live during a single-exercise drag (ADR-0035,
        // ADR-0036).
        stationIndex: rowIndex,
      ),
      highlight: isLive,
      hasRoles: hasRoles,
    );

    // Reorder mode: show drag handle, suspend gestures (no swipe/long-press).
    final Widget tile;
    if (reordering) {
      tile = ExpandableTile(
        leading: badge,
        title: RingDrillText.plain(
          station.name,
          overrides: _overridesFor(exercise, station),
          style: accent.textStyle,
        ),
        subtitle: RingDrillText.plain(
          '${localizations.exercise(1)}: ${exercise.name}',
          overrides: _overridesFor(exercise, station),
          style: accent.textStyle,
        ),
        accent: accent,
        selected: selected,
        trailing: dragHandle,
        // No onOpen, onLongPress, onToggle — gestures suspended in reorder mode.
      );
    } else {
      tile = Dismissible(
        key: ValueKey('station-row-${exercise.uuid}-${station.index}'),
        direction: DismissDirection.endToStart,
        background: Container(
          color: colorScheme.secondaryContainer,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                localizations.editStation,
                style: TextStyle(color: colorScheme.onSecondaryContainer),
              ),
              const SizedBox(width: 8),
              Icon(Icons.edit, color: colorScheme.onSecondaryContainer),
            ],
          ),
        ),
        confirmDismiss: (_) async {
          await _openStationForm(exercise, station);
          return false;
        },
        child: ExpandableTile(
          onLongPress: () => _openStationForm(exercise, station),
          leading: badge,
          title: RingDrillText.plain(
            station.name,
            overrides: _overridesFor(exercise, station),
            style: accent.textStyle,
          ),
          subtitle: RingDrillText.plain(
            '${localizations.exercise(1)}: ${exercise.name}',
            overrides: _overridesFor(exercise, station),
            style: accent.textStyle,
          ),
          accent: accent,
          selected: selected,
          expanded: expanded,
          onOpen: () => _openStation(exercise, station),
          onToggle: () {
            setState(() {
              _expandedRowKey = expanded ? null : rowKey;
            });
          },
          body: _buildExpandedBody(
            context,
            localizations,
            exercise,
            station,
            hasRoles: hasRoles,
          ),
        ),
      );
    }

    // DESIGN-010 browser tile polish: each row lists a different station, so
    // it seeds its own scope (rather than sharing one ancestor) — this is what
    // lets `{{station.*}}` (e.g. `{{station.position}}`) resolve inside
    // the tile's title/subtitle/body instead of showing literally.
    return StationScope.forStation(
      exercise: exercise,
      station: station,
      child: tile,
    );
  }

  Widget _buildExpandedBody(
    BuildContext context,
    AppLocalizations localizations,
    Exercise exercise,
    Station station, {
    required bool hasRoles,
  }) {
    // Description/Position/Markers, each spaced evenly via the Column's own
    // `spacing` below — no separate divider widget needed.
    final sections = <Widget>[
      StationDescriptionRollup(
        exercise: exercise,
        station: station,
        role: _role,
      ),
      StationPositionPanel(
        mapHeight: 140,
        withTitle: true,
        withBorder: true,
        exercise: exercise,
        station: station,
        key: ValueKey<String>(
          'stations-list-map-${exercise.uuid}-${station.index}',
        ),
      ),
      if (hasRoles)
        StationRoleSummary(
          exercise: exercise,
          stationIndex: station.index,
          // DESIGN-010 browser tile polish Fix 4: the marker-row icon opens
          // the shared marker sheet here (unified with the Spill tile's
          // cast chip) instead of the Spill viewer.
          onTapMarker: (role) => _openMarkerSheet(context, role),
        ),
    ];
    return Column(
      spacing: 16.0,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: sections,
    );
  }

  Future<void> _openStation(Exercise exercise, Station station) async {
    // A post of the *running* exercise opens as a mode of the player rather
    // than in a sheet beside it (ADR-0056); everything else is unchanged.
    await openContextTarget(
      context,
      StationSheetTarget(
        exerciseUuid: exercise.uuid,
        stationIndex: station.index,
      ),
    );
  }

  /// Opens the shared marker sheet for [role] (DESIGN-010 browser tile
  /// polish, Fix 4) — the Poster tile's `StationRoleSummary.onTapMarker`
  /// hook, mirroring the Spill tile's own cast chip via the same helper.
  Future<void> _openMarkerSheet(BuildContext context, RolePlay role) async {
    final localizations = AppLocalizations.of(context)!;
    await openCastPickerAndApply(context, localizations, role);
  }

  Future<void> _openStationForm(Exercise exercise, Station station) async {
    final localizations = AppLocalizations.of(context)!;
    final exerciseService = ExerciseService();
    if (exerciseService.isStarted) {
      final runningExercise = exerciseService.last?.exercise;
      if (runningExercise != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.stopExerciseFirst(runningExercise.name),
            ),
          ),
        );
      }
      return;
    }
    // DESIGN-009 prompt 5: the delete-guard and save-block need to know
    // whether a roleplay linked to this station references a Location/
    // Person before letting the author remove or leave one dangling.
    final roleplays = _planService
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
        markers: _planService.getLocations().toMarkerSpecs(),
        variables: _planService.activePlan?.variables ?? const [],
        parentExercise: exercise,
        roleplays: roleplays,
      ),
    );
    if (!mounted || result == null) return;

    await applyVariableAdditionsToActivePlan(_planService, result.additions);
    // A marker authored/edited inline from the Persons section's "Legg til
    // markør" / "Spilles av {navn}" row (DESIGN-009 prompt 4j) — held in
    // the post editor's own working copy, written back here alongside the
    // station's own save.
    await applyPendingRolePlayAdditions(
      _planService,
      localizations,
      result.additions,
    );
    // Persist the edited station back into its owning exercise.
    final current = _planService.getExercise(exercise.uuid);
    if (current == null) return;
    final stations = [...current.stations];
    final idxInList = stations.indexWhere((s) => s.index == station.index);
    if (idxInList < 0) return;
    stations[idxInList] = result.station;
    await _planService.saveExercise(
      localizations,
      current.copyWith(stations: stations),
    );
  }
}

/// Fixed banner shown below the Stations tab's scroll view while filtered to
/// one exercise. Rendered by plan_view.dart as a sibling of the segment's
/// `CustomScrollView` (not inside it) so it stays pinned to the bottom of the
/// viewport instead of scrolling with the rows — mirrors the pre-sliver
/// `Column(Expanded(list), banner)` layout. Renders nothing when no filter is
/// active, or if the filtered exercise has since been deleted.
class StationFilterBanner extends StatelessWidget {
  const StationFilterBanner({super.key, required this.controller});

  final StationListController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: controller.filterExerciseUuid,
      builder: (context, uuid, _) {
        final exercise = uuid == null ? null : PlanService().getExercise(uuid);
        if (exercise == null) return const SizedBox.shrink();
        final localizations = AppLocalizations.of(context)!;
        final theme = Theme.of(context);
        return Material(
          color: theme.colorScheme.secondaryContainer,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_alt,
                    size: 18,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RingDrillText.plain(
                      localizations.showingStationsIn(exercise.name),
                      overrides: PlanService().activePlan == null
                          ? const {}
                          : effectivePlanVariables(
                              PlanService().activePlan!,
                              exercise: exercise,
                            ),
                      style: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => controller.filterExerciseUuid.value = null,
                    child: Text(localizations.showAll),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Owns the current "filter to one exercise" selection for the
/// Stations tab. The notifier is shared between the controller's FAB
/// (which renders the badge and opens the picker) and
/// [StationListView] (which reads the filter when collecting rows).
class StationListController extends ScreenController {
  StationListController();

  final ValueNotifier<String?> filterExerciseUuid = ValueNotifier<String?>(
    null,
  );

  void dispose() {
    filterExerciseUuid.dispose();
  }

  @override
  String title(BuildContext context) =>
      AppLocalizations.of(context)!.stationsTab;

  // Filter by exercise as an AppBar action, mirroring RolePlaysController so
  // both the Poster and Markører segments filter the same way and the FAB
  // slot stays free.
  @override
  List<Widget>? buildActions(BuildContext context, BoxConstraints constraints) {
    final localizations = AppLocalizations.of(context)!;
    final hasActivePlan = PlanService().activePlanUuid != null;
    return [
      ValueListenableBuilder<String?>(
        valueListenable: filterExerciseUuid,
        builder: (context, active, _) {
          final button = IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: localizations.selectExercises,
            onPressed: hasActivePlan ? () => openFilterSheet(context) : null,
          );
          if (active == null) return button;
          return Badge.count(count: 1, child: button);
        },
      ),
    ];
  }

  Future<void> openFilterSheet(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    final plan = PlanService().activePlan;
    final exercises = PlanService().loadExercises();
    final exerciseFormat =
        plan?.exerciseNumberFormat ?? ExerciseNumberFormat.hash;
    final current = filterExerciseUuid.value;
    // Adaptive picker (ADR-0049): bottom sheet on compact, dialog on
    // medium/expanded. Tap applies the filter (a check marks the active
    // one) — no radios. "All exercises" first, then one per exercise.
    final choices = <_FilterChoice>[
      const _FilterChoice.all(),
      for (final ex in exercises) _FilterChoice.one(ex.uuid),
    ];
    final selected = await showRingdrillPicker<_FilterChoice>(
      context: context,
      title: localizations.pickerFilterByExerciseTitle,
      items: choices,
      itemBuilder: (context, choice, onTap) {
        final theme = Theme.of(context);
        final isActive = choice.uuid == current;
        final check = isActive
            ? Icon(Icons.check, color: theme.colorScheme.primary)
            : null;
        if (choice.uuid == null) {
          return ListTile(
            leading: const Icon(Icons.clear_all),
            title: Text(localizations.allExercises),
            trailing: check,
            onTap: onTap,
          );
        }
        final index = exercises.indexWhere((e) => e.uuid == choice.uuid);
        return ListTile(
          leading: ExerciseNumberBadge(
            label: Numbering.exercise(exerciseFormat, index + 1),
            size: 36,
          ),
          title: Text(exercises[index].name),
          trailing: check,
          onTap: onTap,
        );
      },
      searchText: (choice) => choice.uuid == null
          ? localizations.allExercises
          : exercises.firstWhere((e) => e.uuid == choice.uuid).name,
      searchHint: localizations.pickerSearchHint,
    );
    if (selected != null) {
      filterExerciseUuid.value = selected.uuid;
    }
  }
}

class _FilterChoice {
  final String? uuid;
  const _FilterChoice.all() : uuid = null;
  const _FilterChoice.one(String this.uuid);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _FilterChoice && other.uuid == uuid;

  @override
  int get hashCode => uuid.hashCode;
}
