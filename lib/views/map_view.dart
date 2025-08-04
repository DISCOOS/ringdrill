import 'dart:math' as math;

import 'package:coordinate_converter/coordinate_converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:osm_nominatim/osm_nominatim.dart';
import 'package:ringdrill/l10n/app_localizations.dart';

class MapConfig {
  static const int static = InteractiveFlag.none;
  static const int interactive =
      InteractiveFlag.drag |
      InteractiveFlag.flingAnimation |
      InteractiveFlag.pinchMove |
      InteractiveFlag.pinchZoom |
      InteractiveFlag.doubleTapZoom |
      InteractiveFlag.doubleTapDragZoom |
      InteractiveFlag.scrollWheelZoom;

  static const LatLng initialCenter = LatLng(59.91, 10.75);
  static TileLayer get osmLayer => TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'discoos.org/ringdrill',
    subdomains: [],
  );
  static TileLayer get topoLayer => TileLayer(
    urlTemplate:
        'https://cache.kartverket.no/v1/wmts/1.0.0/topo/default/webmercator/{z}/{y}/{x}.png',
    subdomains: [],
    userAgentPackageName: 'discoos.org/ringdrill',
  );
}

class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.layer,
    this.controller,
    this.withCross = false,
    this.withSearch = false,
    this.initialZoom = 15,
    this.interactionFlags = MapConfig.static,
    this.initialCenter = MapConfig.initialCenter,
    this.onTap,
  });

  final TileLayer layer;
  final bool withCross;
  final bool withSearch;
  final double initialZoom;
  final int interactionFlags;
  final LatLng initialCenter;
  final MapController? controller;
  final TapCallback? onTap;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  late MapController _mapController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mapController = widget.controller ?? MapController();
  }

  @override
  void didUpdateWidget(covariant MapView oldWidget) {
    if (oldWidget != widget) {
      if (widget.controller != null && _mapController != widget.controller) {
        //_mapController.dispose();
        _mapController = widget.controller!;
      }
      _mapController.move(widget.initialCenter, widget.initialZoom);
    }
    super.didUpdateWidget(oldWidget);
  }

  Future<void> _searchLocation() async {
    final input = _searchController.text.trim();
    if (input.isEmpty) return;

    try {
      // Try parsing LatLng
      if (input.contains(",")) {
        final parts = input.split(",");
        final lat = double.tryParse(parts[0]);
        final lon = double.tryParse(parts[1]);
        if (lat != null && lon != null) {
          final result = LatLng(lat, lon);
          _mapController.move(result, widget.initialZoom);
          return;
        }
      }

      // Try parsing UTM using coordinate_converter
      final tokens = input.split(RegExp(r'[ ,]+'));
      if (tokens.length == 4) {
        final zone = int.tryParse(tokens[0].replaceAll(RegExp(r'[^0-9]'), ''));
        final band = tokens[0].replaceAll(RegExp(r'[^A-Z]'), '');
        final x = double.tryParse(tokens[2]);
        final y = double.tryParse(tokens[3]);
        if (zone != null && x != null && y != null) {
          final isSouthern = band.codeUnitAt(0) < 'N'.codeUnitAt(0);
          final utm = UTMCoordinates(
            x: x,
            y: y,
            zoneNumber: zone,
            isSouthernHemisphere: isSouthern,
          );
          final dd = utm.toDD();
          final result = LatLng(dd.latitude, dd.longitude);
          _mapController.move(result, widget.initialZoom);
          return;
        }
      }

      // Try geocoding via osm_nominatim
      final nominatim = Nominatim(userAgent: 'discoos.org/ringdrill');
      final results = await nominatim.searchByName(
        query: input,
        limit: 1,
        addressDetails: true,
        extraTags: true,
        nameDetails: true,
      );

      if (results.isNotEmpty) {
        final loc = results.first;
        final result = LatLng(loc.lat, loc.lon);
        _mapController.move(result, widget.initialZoom);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.searchFailed(e)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchHint = AppLocalizations.of(context)!.searchForPlaceOrLocation;
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialZoom: widget.initialZoom,
            initialCenter: widget.initialCenter,
            interactionOptions: InteractionOptions(
              flags: widget.interactionFlags,
            ),
            onTap: (tapPosition, point) {
              if (widget.interactionFlags != InteractiveFlag.none) {
                _mapController.move(point, _mapController.camera.zoom);
              }
              if (widget.onTap != null) {
                widget.onTap!(tapPosition, point);
              }
            },
          ),
          children: [widget.layer],
        ),
        if (widget.withCross)
          IgnorePointer(
            child: Center(
              child: Transform.rotate(
                angle: 45 * math.pi / 180,
                child: Icon(
                  Icons.close,
                  size: 40,
                  color: Colors.red.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),
        if (widget.withSearch)
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              height: 78,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0).copyWith(left: 16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: searchHint,
                      border: InputBorder.none,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _searchLocation,
                      ),
                    ),
                    onSubmitted: (_) => _searchLocation(),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
