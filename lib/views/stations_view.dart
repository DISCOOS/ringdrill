import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/theme.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/utils/subscription_bag.dart';
import 'package:ringdrill/views/coordinator_screen.dart';
import 'package:ringdrill/views/drill_player/drill_mini_player.dart';
import 'package:ringdrill/views/drill_player/drill_player_coordinator.dart';
import 'package:ringdrill/views/drill_player/drill_player_scope.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/map_command.dart';
import 'package:ringdrill/views/widgets/exercise_number_badge.dart';
import 'package:ringdrill/views/widgets/resolve_scoped_field.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';
import 'package:ringdrill/views/widgets/ringdrill_text.dart';
import 'package:ringdrill/views/widgets/role_mini_map.dart' show roleMarker;

import '../models/exercise.dart' show Exercise, ExerciseX, StationLocation;
import '../services/plan_service.dart' show PlanService;
import 'map_view.dart';

/// Bumped by MainScreen every time the Stations tab is activated, so the
/// already-mounted [StationsView] (kept alive by IndexedStack) can re-fit
/// the camera to the current set of stations.
final ValueNotifier<int> stationsTabReselectTick = ValueNotifier<int>(0);
final ValueNotifier<int> stationsMapDetailClearTick = ValueNotifier<int>(0);

class StationsView extends StatefulWidget {
  const StationsView({super.key});

  @override
  State<StationsView> createState() => _StationsViewState();
}

/// Pending position-pick state. Held while the user is in the inline
/// pick-mode banner, between picking a station from search and pressing
/// either Save or Cancel.
class _PendingPick {
  final String exerciseUuid;
  final int stationIndex;
  final String label;

  const _PendingPick({
    required this.exerciseUuid,
    required this.stationIndex,
    required this.label,
  });
}

class _StationsViewState extends State<StationsView>
    with SubscriptionBag<StationsView> {
  final _mapController = MapController();
  final _planService = PlanService();
  final _exerciseService = ExerciseService();

  /// The effective plan-variable map (ADR-0046) at [exercise]'s scope,
  /// optionally narrowed to [stationIndex]'s station. Empty when there is
  /// no active plan.
  Map<String, String> _overridesFor(Exercise exercise, {int? stationIndex}) {
    final plan = _planService.activePlan;
    if (plan == null) return const {};
    final stations = exercise.stations;
    final station = (stationIndex != null && stationIndex < stations.length)
        ? stations[stationIndex]
        : null;
    return effectivePlanVariables(plan, exercise: exercise, station: station);
  }

  final _mapKey = GlobalKey<_StationsViewState>();
  final _detailTarget = ValueNotifier<ContextSheetTarget?>(null);
  // Context captured from inside MasterDetailScope so that tap handlers
  // (which run on the state's context, above the scope) can find the scope
  // via MasterDetailScope.maybeOf. Null when not in wide/responsive layout.
  BuildContext? _scopeContext;
  _PendingPick? _pickFor;

  /// UUIDs of exercises the user has toggled off in the visibility sheet.
  /// View-state only — does not survive a process restart by design.
  final Set<String> _hiddenExercises = <String>{};

  bool _showLabels = true;
  bool _showStations = true;
  bool _showRoleplays = true;

  @override
  void initState() {
    super.initState();
    // Rebuild when the active plan or its stations change. The parent
    // MainScreen keeps tabs alive in an IndexedStack with identical widget
    // instances, so its own setState does not propagate here. See
    // active_plan_actions.dart and PlanService.setActive/installFromFile.
    listen(_planService.events, (_) {
      if (mounted) setState(() {});
    });
    // Rebuild on every exercise tick so the live-station highlight follows
    // the running exercise from round to round (and clears when it stops).
    listen(_exerciseService.events, (_) {
      if (mounted) setState(() {});
    });
    // Re-fit the camera whenever the Stations tab is (re)selected. Without
    // this hook, IndexedStack just toggles visibility and the map keeps
    // whatever pan/zoom the user last left it on.
    stationsTabReselectTick.addListener(_recenter);
    stationsMapDetailClearTick.addListener(_clearDetail);
  }

  void _clearDetail() {
    _detailTarget.value = null;
  }

  void _recenter() {
    if (!mounted) return;
    final markers = _visibleLocations();
    // Flags mirror the MapView overlays below (search field at top, FAB
    // column at bottom) so an auto-fit after a filter change lands the
    // markers exactly where pressing "centre" would. MapConfig.fitFor
    // handles zero, one or many markers uniformly (zero lands on
    // MapConfig.initialCenter), so there's no need to special-case the
    // count here.
    final fit = MapConfig.fitFor(
      markers.map((m) => m.$3),
      withSearch: true,
      withZoom: true,
      withCenter: true,
      withLocate: true,
      viewport: MediaQuery.sizeOf(context),
      // The fit always lands on an overview zoom, below labelDetailZoomFor
      // — reserve the short chip's footprint, not the full label it won't
      // show yet (mirrors MapView's own internal default-fit logic).
      labels: markers.map((m) => m.$4 ?? m.$2),
    );
    _mapController.fitCamera(fit);
  }

  /// Markers that should currently be plotted — i.e. every station with a
  /// position whose owning exercise has not been hidden via the
  /// visibility sheet.
  List<StationLocation> _visibleLocations() {
    final all = _planService.getLocations();
    if (_hiddenExercises.isEmpty) return all;
    return all.where((m) => !_hiddenExercises.contains(m.$1.$1)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final markers = _visibleLocations();
    // No "no stations created" nag: an empty Map tab is expected on a fresh
    // plan, and the Plan tab's teaching empty states plus onboarding now
    // carry the "you have nothing yet" message. A snackbar here just nagged on
    // first launch (DESIGN-007).

    // Centre on the actual stations when present; markers.average() itself
    // falls back to the configured initial centre (Oslo) when nothing is
    // plotted yet, so there's no need to branch on emptiness here.
    final center = markers.average();

    final allExercises = _planService.loadExercises();
    final localizations = AppLocalizations.of(context)!;

    final hiddenCount = _hiddenExercises.length;
    final scheme = Theme.of(context).colorScheme;

    // Ids of the stations a team is currently at, for the running exercise.
    // Empty whenever no exercise is running, so the map stays all-green.
    final liveEvent = _exerciseService.last;
    final activeIds = (liveEvent != null && liveEvent.isRunning)
        ? liveEvent.exercise.activeLocationIds(liveEvent.currentRound)
        : const <(String, int)>{};

    final stationSpecs = _showStations
        ? markers.toMarkerSpecs(
            clusterGroup: 'markers',
            onTap: _onStationTap,
            activeIds: activeIds,
            activeColor: RingDrillColors.brandAccent,
          )
        : <MapMarkerSpec<(String, int)>>[];

    final roleplays = _planService
        .loadRolePlays()
        .where((rp) => rp.position.isFiniteOrNull)
        .toList();
    final roleSpecs = _showRoleplays
        ? roleplays
              .map((rp) {
                final exercise = _planService.getExercise(rp.exerciseUuid);
                final stationIndex = rp.stationIndex;
                final station =
                    (exercise != null &&
                        stationIndex != null &&
                        stationIndex >= 0 &&
                        stationIndex < exercise.stations.length)
                    ? exercise.stations[stationIndex]
                    : null;
                return roleMarker<(String, int)>(
                  context,
                  rp,
                  station,
                  id: (rp.exerciseUuid, rp.index),
                  exercise: exercise,
                  overrides: exercise == null
                      ? const {}
                      : _overridesFor(exercise, stationIndex: stationIndex),
                  clusterGroup: 'markers',
                  onTap: () {
                    final ctx = _scopeContext ?? context;
                    ContextSheet.of(
                      ctx,
                    ).show(ctx, RoleSheetTarget(rolePlayUuid: rp.uuid));
                  },
                );
              })
              .whereType<MapMarkerSpec<(String, int)>>()
              .toList()
        : <MapMarkerSpec<(String, int)>>[];

    final allSpecs = [...stationSpecs, ...roleSpecs];

    final hasFilterActive =
        hiddenCount > 0 || !_showStations || !_showRoleplays || !_showLabels;
    final onlyExercisesFiltered =
        hiddenCount > 0 && _showStations && _showRoleplays && _showLabels;

    final mapColumn = Column(
      children: [
        if (_pickFor != null) _buildPickBanner(context, _pickFor!),
        Expanded(
          child: MapView<(String, int)>(
            key: _mapKey,
            withCross: true,
            withSearch: true,
            withCenter: true,
            withToggle: true,
            withZoom: true,
            withLocate: true,
            initialCenter: center,
            // No initialFit: MapView computes its own default fit from
            // `markers` below, using its own real render size — this always
            // matches what pressing "centre" would produce, for any window
            // size or embedding context, with no guessing needed here.
            controller: _mapController,
            interactionFlags: MapConfig.interactive,
            layers: MapConfig.layers,
            markers: allSpecs,
            showLabels: _showLabels,
            clusterStyles: {
              'markers': MapClusterStyle(
                // Reuse the FABs' tonal overlay palette so the count badge
                // reads as the same "tool over the map" family in both light
                // and dark mode — neutral fill, high-contrast number, no loud
                // edge. (primaryContainer was too pale; solid primary too loud.)
                color: MapCommandEmphasis.tonal.background(scheme),
                onColor: MapCommandEmphasis.tonal.foreground(scheme),
                // A group goes live (orange) when any station inside it is
                // the one a team is currently at, matching the live accent
                // used for active stations in the player.
                activeColor: RingDrillColors.brandAccent,
                activeOnColor: const Color(0xFF1A0F00),
              ),
            },
            searchTargets: _buildSearchTargets(context),
            topRightCommands: [
              _buildFilterFab(context, localizations, allExercises),
            ],
          ),
        ),
        if (hasFilterActive)
          onlyExercisesFiltered
              ? _buildFilterBanner(
                  context,
                  shown: allExercises.length - hiddenCount,
                  total: allExercises.length,
                )
              : _buildCombinedFilterBanner(context),
      ],
    );
    return _buildResponsiveMap(context, mapColumn);
  }

  Widget _buildResponsiveMap(BuildContext context, Widget mapColumn) {
    final windowSizeClass = WindowSizeClass.of(context);
    if (!windowSizeClass.hasMasterDetail) {
      _scopeContext = null;
      return mapColumn;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          _scopeContext = null;
          return mapColumn;
        }
        final detailRatio = windowSizeClass == WindowSizeClass.expanded
            ? 1 / 3
            : 0.4;
        final desiredDetailWidth = constraints.maxWidth * detailRatio;
        final detailWidth = desiredDetailWidth.clamp(
          360.0,
          constraints.maxWidth,
        );
        final mapWidth = constraints.maxWidth - detailWidth;
        if (detailWidth < 360 || mapWidth < 280) {
          _scopeContext = null;
          return mapColumn;
        }

        // MasterDetailScope must always be present so _onStationTap can find
        // the scope via ContextSheet.of(context).show(). The Builder captures
        // a context that is a descendant of the scope (the state's own context
        // is an ancestor and would miss it). The ValueListenableBuilder on
        // _detailTarget controls width: full-width map when nothing is
        // selected, split layout when a station/role is showing.
        return MasterDetailScope(
          target: _detailTarget,
          emptyPaneBuilder: (_) => const SizedBox.shrink(),
          child: Builder(
            builder: (scopeContext) {
              _scopeContext = scopeContext;
              return ValueListenableBuilder<ContextSheetTarget?>(
                valueListenable: _detailTarget,
                builder: (context, target, _) {
                  final hasDetail = target != null;
                  final activeMapWidth = hasDetail
                      ? mapWidth
                      : constraints.maxWidth;
                  return Row(
                    children: [
                      SizedBox(
                        width: activeMapWidth,
                        child: Column(
                          children: [
                            Expanded(child: mapColumn),
                            if (ExerciseService().isStarted)
                              SafeArea(
                                top: false,
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                  child: DrillMiniPlayer(
                                    onOpen: () => _openDrillPlayer(context),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (hasDetail)
                        SizedBox(
                          width: detailWidth,
                          child: const MasterDetailPane(),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  /// Single filter FAB replacing the old three-FAB stack. The [Badge]
  /// count reflects how many independent filter dimensions are active
  /// (0–4: hidden exercises, stations off, roleplays off, labels off).
  Widget _buildFilterFab(
    BuildContext context,
    AppLocalizations l,
    List<Exercise> allExercises,
  ) {
    final activeDimensions =
        (_hiddenExercises.isNotEmpty ? 1 : 0) +
        (!_showStations ? 1 : 0) +
        (!_showRoleplays ? 1 : 0) +
        (!_showLabels ? 1 : 0);
    return MapCommand(
      heroTag: 'filter',
      tooltip: l.filter,
      onPressed: () => _openFilterSheet(context, l, allExercises),
      icon: Icons.filter_alt,
      badgeCount: activeDimensions,
    );
  }

  /// Unified filter sheet replacing `_openVisibilitySheet` and
  /// `_openMarkerTypesSheet`. Sections: marker-type toggles (stations,
  /// roleplays, labels) then per-exercise visibility, then a "Show all"
  /// reset button that is disabled when nothing is filtered.
  Future<void> _openFilterSheet(
    BuildContext context,
    AppLocalizations l,
    List<Exercise> exercises,
  ) async {
    await showRingdrillActionSheet<void>(
      context: context,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void apply() {
              setState(() {});
            }

            final sectionLabelStyle = Theme.of(sheetContext)
                .textTheme
                .titleSmall
                ?.copyWith(
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                );

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(l.filterShowOnMap, style: sectionLabelStyle),
                  ),
                  SwitchListTile.adaptive(
                    value: _showStations,
                    title: Text(l.showStations),
                    onChanged: (value) {
                      setSheetState(() => _showStations = value);
                      setState(() => _showStations = value);
                    },
                  ),
                  SwitchListTile.adaptive(
                    value: _showRoleplays,
                    title: Text(l.showRoleplays),
                    onChanged: (value) {
                      setSheetState(() => _showRoleplays = value);
                      setState(() => _showRoleplays = value);
                    },
                  ),
                  SwitchListTile.adaptive(
                    value: _showLabels,
                    title: Text(l.showLabels),
                    onChanged: (value) {
                      setSheetState(() => _showLabels = value);
                      setState(() => _showLabels = value);
                    },
                  ),
                  const Divider(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.exercisesShownOfTotal(
                              exercises.length - _hiddenExercises.length,
                              exercises.length,
                            ),
                            style: Theme.of(sheetContext).textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: _hiddenExercises.isEmpty
                              ? null
                              : () {
                                  setSheetState(_hiddenExercises.clear);
                                  apply();
                                },
                          child: Text(l.showAll),
                        ),
                        TextButton(
                          onPressed: _hiddenExercises.length == exercises.length
                              ? null
                              : () {
                                  setSheetState(() {
                                    _hiddenExercises
                                      ..clear()
                                      ..addAll(exercises.map((e) => e.uuid));
                                  });
                                  apply();
                                },
                          child: Text(l.hideAll),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: exercises.length,
                      itemBuilder: (context, index) {
                        final ex = exercises[index];
                        final isVisible = !_hiddenExercises.contains(ex.uuid);
                        final exerciseFormat =
                            _planService.activePlan?.exerciseNumberFormat ??
                            ExerciseNumberFormat.hash;
                        return SwitchListTile.adaptive(
                          value: isVisible,
                          secondary: ExerciseNumberBadge(
                            label: Numbering.exercise(
                              exerciseFormat,
                              index + 1,
                            ),
                            size: 32,
                          ),
                          title: RingDrillText.plain(
                            ex.name,
                            overrides: _overridesFor(ex),
                          ),
                          onChanged: (value) {
                            setSheetState(() {
                              if (value) {
                                _hiddenExercises.remove(ex.uuid);
                              } else {
                                _hiddenExercises.add(ex.uuid);
                              }
                            });
                            apply();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Slim banner shown above the map whenever the visibility filter
  /// hides at least one exercise. Users tend to forget that they
  /// toggled something off; the banner spells out "Showing X of N
  /// exercises" (the same pattern used by the import/export selector)
  /// and offers a one-tap "Show all" shortcut so the recovery path is
  /// visible at all times, not buried inside the bottom sheet.
  Widget _buildFilterBanner(
    BuildContext context, {
    required int shown,
    required int total,
  }) {
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
                child: Text(
                  localizations.exercisesShownOfTotal(shown, total),
                  style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(_hiddenExercises.clear);
                },
                child: Text(localizations.showAll),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shown when two or more filter types are simultaneously active.
  Widget _buildCombinedFilterBanner(BuildContext context) {
    final l = AppLocalizations.of(context)!;
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
                  l.filterActiveCombined,
                  style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _hiddenExercises.clear();
                    _showStations = true;
                    _showRoleplays = true;
                    _showLabels = true;
                  });
                },
                child: Text(l.showAll),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickBanner(BuildContext context, _PendingPick pick) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Material(
      elevation: 4,
      color: theme.colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  localizations.setPositionFor(pick.label),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _cancelPick,
                child: Text(localizations.cancel),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: _savePickedPosition,
                child: Text(localizations.save),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startPickPosition({
    required String exerciseUuid,
    required int stationIndex,
    required String label,
  }) {
    setState(() {
      _pickFor = _PendingPick(
        exerciseUuid: exerciseUuid,
        stationIndex: stationIndex,
        label: label,
      );
    });
    // Drop the user near the other stations of the same exercise so they
    // do not have to pan in from far away. If no sibling has a position,
    // leave the camera where it is.
    final exercise = _planService.getExercise(exerciseUuid);
    if (exercise == null) return;
    final siblingStations = exercise.stations
        .where((s) => s.position != null && s.index != stationIndex)
        .toList(growable: false);
    if (siblingStations.isEmpty) return;
    // Flags mirror this screen's MapView (withSearch/withZoom/withCenter/
    // withLocate all true) so the pick-mode drop lands where "centre" would.
    // MapConfig.fitFor handles one or many siblings uniformly, so there's
    // no need to special-case a lone sibling here.
    final fit = MapConfig.fitFor(
      siblingStations.map((s) => s.position!),
      withSearch: true,
      withZoom: true,
      withCenter: true,
      withLocate: true,
      viewport: MediaQuery.sizeOf(context),
      labels: siblingStations.map((s) => s.name),
    );
    _mapController.fitCamera(fit);
  }

  Future<void> _savePickedPosition() async {
    final pick = _pickFor;
    if (pick == null) return;
    final localizations = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final exercise = _planService.getExercise(pick.exerciseUuid);
    if (exercise == null || pick.stationIndex >= exercise.stations.length) {
      setState(() => _pickFor = null);
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.stationGone)),
      );
      return;
    }

    final picked = _mapController.camera.center;
    final updatedStations = [...exercise.stations];
    updatedStations[pick.stationIndex] = updatedStations[pick.stationIndex]
        .copyWith(position: picked);
    final updatedExercise = exercise.copyWith(stations: updatedStations);

    await _planService.saveExercise(localizations, updatedExercise);
    if (!mounted) return;
    setState(() => _pickFor = null);
    messenger.showSnackBar(
      SnackBar(
        showCloseIcon: true,
        dismissDirection: DismissDirection.endToStart,
        content: Text(localizations.positionSaved),
      ),
    );
  }

  void _cancelPick() {
    setState(() => _pickFor = null);
  }

  List<SearchResult> _buildSearchTargets(BuildContext context) {
    final exercises = _planService.loadExercises();
    final targets = <SearchResult>[];
    final stationNumberFormat =
        _planService.activePlan?.stationNumberFormat ??
        StationNumberFormat.dotted;

    for (final exercise in exercises) {
      // Hidden exercises drop out of the search list entirely (both the
      // exercise-level entry and every station underneath it). Keeping
      // them searchable while invisible on the map would let users tap
      // a result and pan to a marker that does not exist.
      if (_hiddenExercises.contains(exercise.uuid)) continue;
      // Exercise-level entry: searching by exercise name should fit the
      // camera to every station that has a position.
      final exercisePoints = exercise.stations
          .where((s) => s.position != null)
          .map((s) => s.position!)
          .toList(growable: false);
      final exerciseOverrides = _overridesFor(exercise);
      targets.add(
        SearchResult.points(
          resolveModelField(
                context,
                exercise.name,
                exercise: exercise,
                overrides: exerciseOverrides,
                selfScope: 'exercise',
              ) ??
              exercise.name,
          exercisePoints,
          kind: SearchResultKind.exercise,
        ),
      );

      // Per-station entries – present even when the station has no
      // position, so the user can find them by name. Row tap:
      // stations with a position fall back to the default
      // move-to-location behaviour; stations without a position open
      // the inline pick-mode banner. Chip tap (onTagTap) always
      // navigates to the station detail page, regardless of whether
      // the station has a position.
      for (final station in exercise.stations) {
        final hasPosition = station.position != null;
        final points = hasPosition
            ? <LatLng>[station.position!]
            : const <LatLng>[];
        final exerciseUuid = exercise.uuid;
        final stationIndex = station.index;
        final stationOverrides = _overridesFor(
          exercise,
          stationIndex: stationIndex,
        );
        final postLabel = station.numberAndName(
          stationNumberFormat,
          exerciseNumber: exercises.indexOf(exercise) + 1,
        );
        final label =
            '${resolveModelField(context, exercise.name, exercise: exercise, station: station, overrides: stationOverrides, selfScope: 'exercise') ?? exercise.name} '
            '| ${resolveModelField(context, postLabel, exercise: exercise, station: station, overrides: stationOverrides) ?? postLabel}';
        targets.add(
          SearchResult.points(
            label,
            points,
            kind: SearchResultKind.station,
            onSelect: hasPosition
                ? null
                : (_) {
                    _startPickPosition(
                      exerciseUuid: exerciseUuid,
                      stationIndex: stationIndex,
                      label: label,
                    );
                  },
            onTagTap: (_) {
              ContextSheet.of(context).show(
                context,
                StationSheetTarget(
                  exerciseUuid: exerciseUuid,
                  stationIndex: stationIndex,
                ),
              );
            },
          ),
        );
      }
    }

    return targets;
  }

  void _onStationTap((String, int) id) {
    final exercise = _planService.getExercise(id.$1);
    if (exercise != null) {
      final target = StationSheetTarget(
        exerciseUuid: exercise.uuid,
        stationIndex: id.$2,
      );
      if (_targetsEqual(_detailTarget.value, target)) {
        // Toggle: tap same station again → close the detail pane.
        final ctx = _scopeContext ?? context;
        ContextSheet.of(ctx).close();
        return;
      }
      // Use _scopeContext (below MasterDetailScope) in wide layout so
      // show() finds the scope and opens the inline detail pane instead
      // of a bottom sheet.
      final ctx = _scopeContext ?? context;
      ContextSheet.of(ctx).show(ctx, target);
    }
  }

  bool _targetsEqual(ContextSheetTarget? a, ContextSheetTarget b) {
    return switch ((a, b)) {
      (
        StationSheetTarget(
          exerciseUuid: final aExerciseUuid,
          stationIndex: final aStationIndex,
        ),
        StationSheetTarget(
          exerciseUuid: final bExerciseUuid,
          stationIndex: final bStationIndex,
        ),
      ) =>
        aExerciseUuid == bExerciseUuid && aStationIndex == bStationIndex,
      (
        RoleSheetTarget(rolePlayUuid: final aRolePlayUuid),
        RoleSheetTarget(rolePlayUuid: final bRolePlayUuid),
      ) =>
        aRolePlayUuid == bRolePlayUuid,
      _ => false,
    };
  }

  /// Routed through the shell's [DrillPlayerCoordinator] rather than pushing a
  /// bare [CoordinatorScreen]: the coordinator gives the player its own inline
  /// [ContextSheet], so the player's mini bar switches the player's own body.
  /// Pushed bare, it had no ContextSheet above it, so `ContextSheet.of` fell
  /// through to the shell's controller and the bar mutated the map's detail
  /// pane behind the player instead.
  void _openDrillPlayer(BuildContext context) {
    final coordinator =
        DrillPlayerScope.maybeOf(context) ?? DrillPlayerCoordinator();
    unawaited(coordinator.openDrillPlayer(context));
  }

  @override
  void dispose() {
    stationsTabReselectTick.removeListener(_recenter);
    stationsMapDetailClearTick.removeListener(_clearDetail);
    _detailTarget.dispose();
    _mapController.dispose();
    super.dispose();
  }
}

class StationsPageController extends ScreenController {
  const StationsPageController() : super();
  @override
  String title(BuildContext context) {
    return AppLocalizations.of(context)!.mapTab;
  }
}
