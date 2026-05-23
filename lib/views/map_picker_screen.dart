import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/map_view.dart';

class MapPickerScreen<K> extends StatefulWidget {
  const MapPickerScreen({
    super.key,
    this.withCross = true,
    this.withSearch = true,
    this.withCenter = true,
    this.withToggle = true,
    this.withZoom = true,
    this.withLocate = true,
    this.initialZoom = 16,
    this.markers = const [],
    this.initialCenter = MapConfig.initialCenter,
    this.initialFit,
  });

  final bool withZoom;
  final bool withCross;
  final bool withSearch;
  final bool withCenter;
  final bool withToggle;
  final bool withLocate;
  final double initialZoom;
  final CameraFit? initialFit;
  final LatLng initialCenter;
  final List<(K, String, LatLng)> markers;

  @override
  State<MapPickerScreen<K>> createState() => _MapPickerScreenState<K>();
}

class _MapPickerScreenState<K> extends State<MapPickerScreen<K>> {
  late LatLng _selected;
  late MapController _mapController;

  late StreamSubscription _subscription;

  final _mapKey = GlobalKey<_MapPickerScreenState>();

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCenter;
    _mapController = MapController();
    _subscription = _mapController.mapEventStream.listen((e) {
      _selected = e.camera.center;
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.pickALocation),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            tooltip: localizations.select,
            onPressed: () => Navigator.pop(context, _selected),
          ),
        ],
        actionsPadding: EdgeInsets.only(right: 16.0),
      ),
      body: SafeArea(
        child: MapView<K>(
          key: _mapKey,
          controller: _mapController,
          withZoom: widget.withZoom,
          withCross: widget.withCross,
          withSearch: widget.withCross,
          withCenter: widget.withCenter,
          withToggle: widget.withToggle,
          withLocate: widget.withLocate,
          initialZoom: widget.initialZoom,
          initialCenter: widget.initialCenter,
          interactionFlags: MapConfig.interactive,
          layers: MapConfig.layers,
          markers: widget.markers,
        ),
      ),
    );
  }
}
