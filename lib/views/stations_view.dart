import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/page_widget.dart';

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
    final markers = _programService.getLocations();
    if (markers.isEmpty) {
      _mapController.move(MapConfig.initialCenter, _mapController.camera.zoom);
      return;
    }
    // Prefer centroid-centred bounds so the camera lands on the geometric
    // mean of all stations, not on the bounding-box midpoint (which
    // drifts toward outliers).
    final padding = EdgeInsets.all(72).copyWith(top: 150);
    final points = markers.map((m) => m.$3);
    final fit = points.centroidFit(padding) ?? markers.fit(padding);
    if (fit != null) {
      _mapController.fitCamera(fit);
    } else {
      _mapController.move(markers.average(), _mapController.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = _programService.getLocations();
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
            initialFit: markers.fit(EdgeInsets.all(72).copyWith(top: 150)),
            controller: _mapController,
            interactionFlags: MapConfig.interactive,
            layers: MapConfig.layers,
            markers: markers,
            searchTargets: _buildSearchTargets(context),
            onMarkerTap: onMarkerTap,
          ),
        ),
      ],
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
    final fit = siblingPoints.centroidFit();
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
    return AppLocalizations.of(context)!.station(2);
  }
}
