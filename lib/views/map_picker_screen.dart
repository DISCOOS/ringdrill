import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/views/map_view.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng initial;
  const MapPickerScreen({super.key, required this.initial});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  bool useTopoLayer = true;

  late LatLng _selected;
  late MapController _mapController;

  late StreamSubscription _subscription;

  final _mapKey = GlobalKey<_MapPickerScreenState>();

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pick a Location"),
        actions: [
          IconButton(
            icon: Icon(useTopoLayer ? Icons.map : Icons.terrain),
            tooltip: useTopoLayer ? 'Switch to OSM' : 'Switch to Topo',
            onPressed: () => setState(() => useTopoLayer = !useTopoLayer),
          ),
        ],
      ),
      body: MapView(
        key: _mapKey,
        initialZoom: 13,
        withCross: true,
        withSearch: true,
        controller: _mapController,
        initialCenter: widget.initial,
        interactionFlags: MapConfig.interactive,
        layer: useTopoLayer ? MapConfig.topoLayer : MapConfig.osmLayer,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'select',
        onPressed: () => Navigator.pop(context, _selected),
        icon: const Icon(Icons.check),
        label: const Text("Select"),
      ),
    );
  }
}
