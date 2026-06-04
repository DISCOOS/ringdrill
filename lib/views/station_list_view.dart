import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/station_form_screen.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/exercise_number_badge.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:ringdrill/views/widgets/live_accent.dart';
import 'package:ringdrill/views/widgets/reorderable_section.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';
import 'package:ringdrill/views/widgets/station_number_badge.dart';
import 'package:ringdrill/views/widgets/station_position_panel.dart';
import 'package:ringdrill/views/widgets/station_role_summary.dart';

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
  final _programService = ProgramService();
  StreamSubscription? _subscription;
  StreamSubscription<ExerciseEvent>? _exerciseSubscription;

  int? _expandedRowIndex;
  ExerciseEvent? _liveEvent;

  // Optimistic display of the committed reorder order. Set synchronously in
  // onCommitReorder so the new order is shown immediately without waiting for
  // the async save round-trip (same pattern as _exercises in ProgramView).
  // Cleared when the service fires a refresh event (new data loaded).
  List<(int, Exercise, Station)>? _stagedRows;

  StationListController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    // Drop `done` events so a stopped exercise's stations stop being
    // highlighted with the live-accent treatment on the badge and tile.
    _liveEvent = _filterLive(ExerciseService().last);
    _subscription = _programService.events.listen((_) {
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
      _expandedRowIndex = null;
      _stagedRows = null;
    });
  }

  @override
  void dispose() {
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
    final exercises = _programService.loadExercises();
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
    for (final rp in _programService.loadRolePlays()) {
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
    return _programService.getExercise(uuid);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final allExercises = _programService.loadExercises();
    final hasAnyStation = allExercises.any((e) => e.stations.isNotEmpty);

    // Use staged rows (synchronous post-commit display) when available so the
    // new order is shown immediately after Done without waiting for the async
    // save to round-trip back through the service event.
    final rows = _stagedRows ?? _collectRows();
    final stationsWithRoles = _collectStationsWithRoles();
    final filterExercise = _filterExercise();

    final targetNotifier = MasterDetailScope.maybeOf(context)?.target;

    final Widget body;
    if (!hasAnyStation) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(localizations.noStationsYet, textAlign: TextAlign.center),
        ),
      );
    } else if (rows.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            localizations.noStationsInExercise,
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
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
        return _buildRow(
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
        body = ReorderableSection<(int, Exercise, Station)>(
          items: rows,
          keyOf: (row) =>
              ValueKey('station-row-${row.$2.uuid}-${row.$3.index}'),
          orderLabel: localizations.exerciseSortBy,
          onCommitReorder: (newOrder) {
            final exerciseUuid = filterExercise.uuid;
            setState(() => _stagedRows = newOrder);
            final orderedOldIndices = newOrder.map((r) => r.$3.index).toList();
            _programService.reorderStations(exerciseUuid, orderedOldIndices);
          },
          itemBuilder: buildStationRow,
        );
      } else {
        body = ListView.builder(
          padding: const EdgeInsets.only(top: 11),
          itemCount: rows.length,
          itemBuilder: (context, index) => buildStationRow(
            context,
            rows[index],
            index,
            false,
            const SizedBox.shrink(),
          ),
        );
      }
    }

    // Filtering is an AppBar action (see [StationListController.buildActions]),
    // matching the Markører segment, so the FAB slot is free and the filter
    // banner at the bottom is never covered by a floating button.
    return Column(
      children: [
        Expanded(child: body),
        if (filterExercise != null)
          _buildFilterBanner(context, localizations, filterExercise),
      ],
    );
  }

  Widget _buildRow(
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
    final expanded = !reordering && _expandedRowIndex == rowIndex;
    final colorScheme = Theme.of(context).colorScheme;
    final isLive = _liveEvent?.exercise.uuid == exercise.uuid;
    final accent = LiveAccent.of(context, isLive: isLive);

    final badge = StationNumberBadge(
      label: Numbering.station(
        _programService.activeProgram?.stationNumberFormat ??
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
    if (reordering) {
      return ExpandableTile(
        leading: badge,
        title: Text(station.name, style: accent.textStyle),
        subtitle: Text(
          '${localizations.exercise(1)}: ${exercise.name}',
          style: accent.textStyle,
        ),
        accent: accent,
        selected: selected,
        trailing: dragHandle,
        // No onOpen, onLongPress, onToggle — gestures suspended in reorder mode.
      );
    }

    return Dismissible(
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
        title: Text(station.name, style: accent.textStyle),
        subtitle: Text(
          '${localizations.exercise(1)}: ${exercise.name}',
          style: accent.textStyle,
        ),
        accent: accent,
        selected: selected,
        expanded: expanded,
        onOpen: () => _openStation(exercise, station),
        onToggle: () {
          setState(() {
            _expandedRowIndex = expanded ? null : rowIndex;
          });
        },
        body: _buildExpandedBody(context, localizations, exercise, station),
      ),
    );
  }

  Widget _buildExpandedBody(
    BuildContext context,
    AppLocalizations localizations,
    Exercise exercise,
    Station station,
  ) {
    final hasDescription =
        station.description != null && station.description!.trim().isNotEmpty;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasDescription) ...[
          Text(station.description!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
        ],
        // Shared "Posisjon" label + pin/coords row + tappable mini-map
        // (140 px tall to match the previous inline layout). Keeping the
        // 140 px height — instead of falling back to the widget's 200 px
        // default — preserves the compact look this list relies on.
        StationPositionPanel(
          exercise: exercise,
          station: station,
          mapHeight: 140,
          miniMapKey: ValueKey<String>(
            'stations-list-map-${exercise.uuid}-${station.index}',
          ),
        ),
        const SizedBox(height: 12),
        StationRoleSummary(exercise: exercise, stationIndex: station.index),
      ],
    );
  }

  Widget _buildFilterBanner(
    BuildContext context,
    AppLocalizations localizations,
    Exercise exercise,
  ) {
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
                child: Text(
                  localizations.showingStationsIn(exercise.name),
                  style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => _controller.filterExerciseUuid.value = null,
                child: Text(localizations.showAll),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openStation(Exercise exercise, Station station) async {
    await ContextSheet.of(context).show(
      context,
      StationSheetTarget(
        exerciseUuid: exercise.uuid,
        stationIndex: station.index,
      ),
    );
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
    final newStation = await openFormSurface<Station>(
      context,
      builder: (_) => StationFormScreen(
        station: station,
        markers: _programService.getLocations().toMarkerSpecs(),
      ),
    );
    if (!mounted || newStation == null) return;

    // Persist the edited station back into its owning exercise.
    final current = _programService.getExercise(exercise.uuid);
    if (current == null) return;
    final stations = [...current.stations];
    final idxInList = stations.indexWhere((s) => s.index == station.index);
    if (idxInList < 0) return;
    stations[idxInList] = newStation;
    await _programService.saveExercise(
      localizations,
      current.copyWith(stations: stations),
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
    final hasActiveProgram = ProgramService().activeProgramUuid != null;
    return [
      ValueListenableBuilder<String?>(
        valueListenable: filterExerciseUuid,
        builder: (context, active, _) {
          final button = IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: localizations.selectExercises,
            onPressed: hasActiveProgram ? () => openFilterSheet(context) : null,
          );
          if (active == null) return button;
          return Badge.count(count: 1, child: button);
        },
      ),
    ];
  }

  Future<void> openFilterSheet(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    final program = ProgramService().activeProgram;
    final exercises = ProgramService().loadExercises();
    final exerciseFormat =
        program?.exerciseNumberFormat ?? ExerciseNumberFormat.hash;
    final current = filterExerciseUuid.value;
    final selected = await showRingdrillActionSheet<_FilterChoice>(
      context: context,
      builder: (sheetContext) {
        final groupValue = current == null
            ? const _FilterChoice.all()
            : _FilterChoice.one(current);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RadioGroup<_FilterChoice>(
            groupValue: groupValue,
            onChanged: (choice) {
              if (choice == null) return;
              Navigator.pop(sheetContext, choice);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Radio<_FilterChoice>(
                    value: _FilterChoice.all(),
                  ),
                  title: Text(localizations.allExercises),
                  onTap: () =>
                      Navigator.pop(sheetContext, const _FilterChoice.all()),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: exercises.length,
                    itemBuilder: (context, index) {
                      final ex = exercises[index];
                      final choice = _FilterChoice.one(ex.uuid);
                      return ListTile(
                        leading: Radio<_FilterChoice>(value: choice),
                        title: Row(
                          children: [
                            ExerciseNumberBadge(
                              label: Numbering.exercise(
                                exerciseFormat,
                                index + 1,
                              ),
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(ex.name)),
                          ],
                        ),
                        onTap: () => Navigator.pop(sheetContext, choice),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
