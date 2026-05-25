import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/views/map_view.dart';

class MapScreen<K> extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.title,
    this.withCross = false,
    this.withSearch = false,
    this.withCenter = true,
    this.withZoom = true,
    this.withLocate = false,
    this.initialZoom = 15,
    this.markers = const [],
    this.interactionFlags = MapConfig.static,
    this.initialCenter = MapConfig.initialCenter,
  });

  final String title;
  final bool withZoom;
  final bool withCross;
  final bool withSearch;
  final bool withCenter;
  final bool withLocate;
  final double initialZoom;
  final int interactionFlags;
  final LatLng initialCenter;
  final List<MapMarkerSpec<K>> markers;

  @override
  State<MapScreen<K>> createState() => _MapScreenState();
}

class _MapScreenState<K> extends State<MapScreen<K>> {
  final _mapController = MapController();
  final _mapKey = GlobalKey<_MapScreenState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: MapView<K>(
          key: _mapKey,
          withCross: widget.withCross,
          withZoom: widget.withZoom,
          withSearch: widget.withSearch,
          withCenter: widget.withCenter,
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

  @override
  void dispose() {
    super.dispose();
    _mapController.dispose();
  }
}
