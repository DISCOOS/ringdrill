import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/station_screen.dart';

import '../services/program_service.dart' show ProgramService;
import 'map_view.dart';

class StationsView extends StatefulWidget {
  const StationsView({super.key});

  @override
  State<StationsView> createState() => _StationsViewState();
}

class _StationsViewState extends State<StationsView> {
  final _mapController = MapController();
  final _programService = ProgramService();
  final _mapKey = GlobalKey<_StationsViewState>();

  bool _notified = false;

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

    final fit = markers.fit();
    final center = fit == null ? markers.average() : MapConfig.initialCenter;

    return MapView<(String, int)>(
      key: _mapKey,
      withCross: true,
      withSearch: true,
      withCenter: true,
      withToggle: true,
      initialCenter: center,
      initialFit: markers.fit(EdgeInsets.all(72).copyWith(top: 150)),
      controller: _mapController,
      interactionFlags: MapConfig.interactive,
      layers: MapConfig.layers,
      markers: markers,
      onMarkerTap: onMarkerTap,
    );
  }

  void onMarkerTap(((String, int), String, LatLng) value) {
    final exercise = _programService.getExercise(value.$1.$1);
    if (exercise != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StationExerciseScreen(
            stationIndex: value.$1.$2,
            uuid: exercise.uuid,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}

class StationsPageController extends ScreenController {
  @override
  String title(BuildContext context) {
    return AppLocalizations.of(context)!.station(2);
  }
}
