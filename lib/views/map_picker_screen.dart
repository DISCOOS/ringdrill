import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/views/map_view.dart';

class MapPickerScreen<K> extends StatefulWidget {
  const MapPickerScreen({
    super.key,
    this.withCross = true,
    this.withSearch = true,
    this.withCenter = true,
    this.withToggle = true,
    this.initialZoom = 13,
    this.markers = const [],
    this.initialCenter = MapConfig.initialCenter,
  });

  final bool withCross;
  final bool withSearch;
  final bool withCenter;
  final bool withToggle;
  final double initialZoom;
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
    final points = widget.markers.map((e) => e.$3).toList();
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
      ),
      body: SafeArea(
        child: MapView<K>(
          key: _mapKey,
          controller: _mapController,
          withCross: widget.withCross,
          withSearch: widget.withCross,
          withCenter: widget.withCenter,
          withToggle: widget.withToggle,
          initialZoom: widget.initialZoom,
          initialFit: points.fit(),
          initialCenter: points.average(widget.initialCenter),
          interactionFlags: MapConfig.interactive,
          layers: MapConfig.layers,
          markers: widget.markers,
        ),
      ),
    );
  }
}
