import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/page_widget.dart';

import '../models/exercise.dart' show Exercise, StationLocation;
import '../services/program_service.dart' show ProgramEvent, ProgramService;
import 'map_view.dart';

/// Bumped by MainScreen every time the Stations tab is activated, so the
/// already-mounted [StationsView] (kept alive by IndexedStack) can re-fit
/// the camera to the current set of stations.
final ValueNotifier<int> stationsTabReselectTick = ValueNotifier<int>(0);

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

class _StationsViewState extends State<StationsView> {
  final _mapController = MapController();
  final _programService = ProgramService();
  final _mapKey = GlobalKey<_StationsViewState>();
  StreamSubscription<ProgramEvent>? _programSubscription;

  bool _notified = false;
  _PendingPick? _pickFor;

  /// UUIDs of exercises the user has toggled off in the visibility sheet.
  /// View-state only — does not survive a process restart by design.
  final Set<String> _hiddenExercises = <String>{};

  @override
  void initState() {
    super.initState();
    // Rebuild when the active program or its stations change. The parent
    // MainScreen keeps tabs alive in an IndexedStack with identical widget
    // instances, so its own setState does not propagate here. See
    // active_plan_actions.dart and ProgramService.setActive/installFromFile.
    _programSubscription = _programService.events.listen((_) {
      if (mounted) {
        setState(() {
          _notified = false;
        });
      }
    });
    // Re-fit the camera whenever the Stations tab is (re)selected. Without
    // this hook, IndexedStack just toggles visibility and the map keeps
    // whatever pan/zoom the user last left it on.
    stationsTabReselectTick.addListener(_recenter);
  }

  void _recenter() {
    if (!mounted) return;
    final markers = _visibleLocations();
    if (markers.isEmpty) {
      _mapController.move(MapConfig.initialCenter, _mapController.camera.zoom);
      return;
    }
    // Prefer centroid-centred bounds so the camera lands on the geometric
    // mean of all stations, not on the bounding-box midpoint (which
    // drifts toward outliers). Padding matches the MapView overlays
    // (search field at top, FAB column at bottom) so the centroid sits
    // in the visible centre rather than under the FABs.
    final padding = MapConfig.fitPadding(
      withSearch: true,
      withZoom: true,
      withCenter: true,
    );
    final points = markers.map((m) => m.$3);
    final fit = points.centroidFit(padding) ?? markers.fit(padding);
    if (fit != null) {
      _mapController.fitCamera(fit);
    } else {
      _mapController.move(markers.average(), _mapController.camera.zoom);
    }
  }

  /// Markers that should currently be plotted — i.e. every station with a
  /// position whose owning exercise has not been hidden via the
  /// visibility sheet.
  List<StationLocation> _visibleLocations() {
    final all = _programService.getLocations();
    if (_hiddenExercises.isEmpty) return all;
    return all.where((m) => !_hiddenExercises.contains(m.$1.$1)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final markers = _visibleLocations();
    // Only nag about "no stations created" when the active program genuinely
    // has no stations anywhere. `markers.isEmpty` is not a safe proxy because
    // getLocations() filters by `position != null`, so exercises whose
    // stations exist but lack coordinates would otherwise trip this snackbar
    // incorrectly (e.g. when the user reactivates an exercise from the
    // program tab, which fires programActivated and rebuilds this view in
    // the background even though it is not visible).
    final hasAnyStation = _programService
        .loadExercises()
        .any((e) => e.stations.isNotEmpty);
    if (!hasAnyStation && !_notified) {
      _notified = true;
      scheduleMicrotask(() {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            showCloseIcon: true,
            dismissDirection: DismissDirection.endToStart,
            content: Text(AppLocalizations.of(context)!.notStationsCreated),
          ),
        );
      });
    }

    // Centre on the actual stations when present; only fall back to the
    // configured initial centre (Oslo) when nothing is plotted yet.
    final center = markers.isEmpty
        ? MapConfig.initialCenter
        : markers.average();

    final fitPadding = MapConfig.fitPadding(
      withSearch: true,
      withZoom: true,
      withCenter: true,
    );

    final allExercises = _programService.loadExercises();
    final localizations = AppLocalizations.of(context)!;

    final hiddenCount = _hiddenExercises.length;
    final hasFilterActive = hiddenCount > 0;

    return Column(
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
            initialCenter: center,
            initialFit: markers.fit(fitPadding),
            controller: _mapController,
            interactionFlags: MapConfig.interactive,
            layers: MapConfig.layers,
            markers: markers,
            searchTargets: _buildSearchTargets(context),
            onMarkerTap: onMarkerTap,
            topRightCommands: [
              if (allExercises.isNotEmpty)
                _buildVisibilityFab(
                  context,
                  localizations,
                  allExercises,
                  hiddenCount,
                ),
            ],
          ),
        ),
        if (hasFilterActive)
          _buildFilterBanner(
            context,
            shown: allExercises.length - hiddenCount,
            total: allExercises.length,
          ),
      ],
    );
  }

  /// FAB with a Material [Badge] showing how many exercises are hidden.
  /// When the filter is inactive the FAB looks like every other map
  /// command so it does not visually shout for attention.
  Widget _buildVisibilityFab(
    BuildContext context,
    AppLocalizations localizations,
    List<Exercise> allExercises,
    int hiddenCount,
  ) {
    final fab = FloatingActionButton(
      heroTag: 'filterExercises',
      tooltip: localizations.showExercises,
      onPressed: () => _openVisibilitySheet(allExercises),
      child: const Icon(Icons.tune),
    );
    if (hiddenCount == 0) return fab;
    return Badge.count(count: hiddenCount, child: fab);
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
                  _recenter();
                },
                child: Text(localizations.showAll),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens a modal bottom sheet listing every exercise in the active
  /// program with a toggle per row. Hidden exercises drop out of both
  /// the marker layer and the search results. The sheet manages its own
  /// transient state and pushes the result back via [setState] when the
  /// user closes it.
  Future<void> _openVisibilitySheet(List<Exercise> exercises) async {
    final localizations = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void applyAndRefit() {
              setState(() {});
              _recenter();
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              // Same "shown of total" phrasing as the
                              // banner above the map and the
                              // import/export selector; rebuilt by
                              // StatefulBuilder so the count tracks
                              // toggles live.
                              localizations.exercisesShownOfTotal(
                                exercises.length - _hiddenExercises.length,
                                exercises.length,
                              ),
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .titleMedium,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                _hiddenExercises.clear();
                              });
                              applyAndRefit();
                            },
                            child: Text(localizations.showAll),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                _hiddenExercises
                                  ..clear()
                                  ..addAll(exercises.map((e) => e.uuid));
                              });
                              applyAndRefit();
                            },
                            child: Text(localizations.hideAll),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: exercises.length,
                        itemBuilder: (context, index) {
                          final ex = exercises[index];
                          final isVisible =
                              !_hiddenExercises.contains(ex.uuid);
                          return SwitchListTile(
                            value: isVisible,
                            title: Text(ex.name),
                            onChanged: (value) {
                              setSheetState(() {
                                if (value) {
                                  _hiddenExercises.remove(ex.uuid);
                                } else {
                                  _hiddenExercises.add(ex.uuid);
                                }
                              });
                              applyAndRefit();
                            },
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
      },
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
    final exercise = _programService.getExercise(exerciseUuid);
    if (exercise == null) return;
    final siblingPoints = exercise.stations
        .where((s) => s.position != null && s.index != stationIndex)
        .map((s) => s.position!)
        .toList(growable: false);
    if (siblingPoints.isEmpty) return;
    final padding = MapConfig.fitPadding(
      withSearch: true,
      withZoom: true,
      withCenter: true,
    );
    final fit = siblingPoints.centroidFit(padding);
    if (fit != null) {
      _mapController.fitCamera(fit);
    } else {
      _mapController.move(
        siblingPoints.first,
        _mapController.camera.zoom,
      );
    }
  }

  Future<void> _savePickedPosition() async {
    final pick = _pickFor;
    if (pick == null) return;
    final localizations = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final exercise = _programService.getExercise(pick.exerciseUuid);
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

    await _programService.saveExercise(localizations, updatedExercise);
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
    final exercises = _programService.loadExercises();
    final targets = <SearchResult>[];

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
      targets.add(
        SearchResult.points(
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
        final label = '${exercise.name} | ${station.name}';
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
              context.push('$routeStations/$exerciseUuid/$stationIndex');
            },
          ),
        );
      }
    }

    return targets;
  }

  void onMarkerTap(((String, int), String, LatLng) value) {
    final exercise = _programService.getExercise(value.$1.$1);
    if (exercise != null) {
      context.push('$routeStations/${exercise.uuid}/${value.$1.$2}');
    }
  }

  @override
  void dispose() {
    stationsTabReselectTick.removeListener(_recenter);
    _programSubscription?.cancel();
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
