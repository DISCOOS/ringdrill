import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/views/map_view.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.title,
    this.withCross = false,
    this.withSearch = false,
    this.initialZoom = 15,
    this.markers = const [],
    this.onMarkerTap,
    this.interactionFlags = MapConfig.static,
    this.initialCenter = MapConfig.initialCenter,
  });

  final String title;
  final bool withCross;
  final bool withSearch;
  final double initialZoom;
  final int interactionFlags;
  final LatLng initialCenter;
  final List<(int, String, LatLng)> markers;

  final ValueSetter<(int, String, LatLng)>? onMarkerTap;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  final _mapKey = GlobalKey<_MapScreenState>();

  int _currentCenterIndex = -1;

  @override
  void initState() {
    super.initState();
    _initCurrentIndex();
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    if (widget.initialCenter != oldWidget.initialCenter) {
      _initCurrentIndex();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: MapView(
        key: _mapKey,
        controller: _mapController,
        withCross: widget.withCross,
        withSearch: widget.withSearch,
        initialZoom: widget.initialZoom,
        initialCenter: widget.initialCenter,
        interactionFlags: MapConfig.interactive,
        layers: MapConfig.layers,
        markers: widget.markers
            .map(
              (e) => (
                e.$2,
                Marker(
                  height: 52,
                  width: 100,
                  point: e.$3,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    behavior: HitTestBehavior.deferToChild,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Material(
                          elevation: 2,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(1.0),
                            child: Text(e.$2, style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        Icon(Icons.place, color: Colors.green, size: 32),
                      ],
                    ),
                    onTap: () => widget.onMarkerTap?.call(e),
                  ),
                ),
              ),
            )
            .toList(),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'center',
        onPressed: () {
          if (widget.markers.isEmpty) {
            _mapController.move(
              widget.initialCenter,
              _mapController.camera.zoom,
            );
            return;
          }

          // Do not toggle to same initial center if exists in markers
          final unique = !widget.markers.any(
            (e) => e.$3 == widget.initialCenter,
          );

          _currentCenterIndex =
              (_currentCenterIndex + 1) %
              (widget.markers.length + (unique ? 1 : 0));

          final point = _currentCenterIndex == 0
              ? widget.initialCenter
              : widget.markers[_currentCenterIndex + (unique ? 1 : 0)].$3;

          _mapController.move(point, _mapController.camera.zoom);
        },
        child: Icon(Icons.center_focus_strong_rounded),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _mapController.dispose();
  }

  void _initCurrentIndex() {
    int i = 0;
    _currentCenterIndex = 0;
    for (final it in widget.markers) {
      if (it.$3 == widget.initialCenter) {
        _currentCenterIndex = i;
        return;
      }
      i++;
    }
  }
}
