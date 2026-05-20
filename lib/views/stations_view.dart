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

class _StationsViewState extends State<StationsView> {
  final _mapController = MapController();
  final _programService = ProgramService();
  final _mapKey = GlobalKey<_StationsViewState>();
  StreamSubscription<ProgramEvent>? _programSubscription;

  bool _notified = false;

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
    if (markers.isEmpty && !_notified) {
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

    return MapView<(String, int)>(
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
    );
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
      // position, so the user can find them by name.
      for (final station in exercise.stations) {
        final points = station.position == null
            ? const <LatLng>[]
            : <LatLng>[station.position!];
        final exerciseUuid = exercise.uuid;
        final stationIndex = station.index;
        targets.add(
          SearchResult.points(
            '${exercise.name} | ${station.name}',
            points,
            kind: SearchResultKind.station,
            onSelect: (_) {
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
