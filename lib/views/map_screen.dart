import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/map_view.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.title,
    this.withCross = false,
    this.withSearch = false,
    this.initialZoom = 15,
    this.interactionFlags = MapConfig.static,
    this.initialCenter = MapConfig.initialCenter,
  });

  final bool withCross;
  final bool withSearch;
  final double initialZoom;
  final int interactionFlags;
  final LatLng initialCenter;
  final String title;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool useTopoLayer = true;
  final _mapController = MapController();

  final _mapKey = GlobalKey<_MapScreenState>();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(useTopoLayer ? Icons.map : Icons.terrain),
            tooltip:
                useTopoLayer
                    ? localizations.switchToOSM
                    : localizations.switchToTopo,
            onPressed: () => setState(() => useTopoLayer = !useTopoLayer),
          ),
        ],
      ),
      body: MapView(
        key: _mapKey,
        controller: _mapController,
        withCross: widget.withCross,
        withSearch: widget.withSearch,
        initialZoom: widget.initialZoom,
        initialCenter: widget.initialCenter,
        interactionFlags: MapConfig.interactive,
        layer: useTopoLayer ? MapConfig.topoLayer : MapConfig.osmLayer,
      ),
      floatingActionButton: IconButton(
        onPressed: () {
          _mapController.move(widget.initialCenter, widget.initialZoom);
        },
        icon: Icon(Icons.center_focus_strong_rounded),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _mapController.dispose();
  }
}
