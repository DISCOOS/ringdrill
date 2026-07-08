import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/utm_widget.dart';

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
  final List<MapMarkerSpec<K>> markers;

  @override
  State<MapPickerScreen<K>> createState() => _MapPickerScreenState<K>();
}

class _MapPickerScreenState<K> extends State<MapPickerScreen<K>> {
  late LatLng _selected;
  late MapController _mapController;

  late StreamSubscription _subscription;

  final _mapKey = GlobalKey<_MapPickerScreenState>();

  // Measured so MapView's own zoom/locate/centre column (bottom-right)
  // clears the confirm bar instead of sitting underneath it. Read after
  // every layout rather than hardcoded, since the bar's height depends on
  // locale text length and text-scale factor.
  final _barKey = GlobalKey();
  double _bottomOverlayInset = 0;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialCenter;
    _mapController = MapController();
    // setState (not just assigning _selected) is new: the bottom bar's
    // live coordinate reads _selected on every camera move, so the pan
    // must actually rebuild the widget for that readout to update.
    _subscription = _mapController.mapEventStream.listen((e) {
      setState(() => _selected = e.camera.center);
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void _measureBar() {
    final box = _barKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    // The gap above the bar's own top edge, on top of the column's
    // existing 16 px base inset.
    final inset = box.size.height + 16;
    if (inset != _bottomOverlayInset) {
      setState(() => _bottomOverlayInset = inset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureBar());
    return Scaffold(
      appBar: AppBar(title: Text(localizations.pickALocation)),
      body: SafeArea(
        child: Stack(
          children: [
            MapView<K>(
              key: _mapKey,
              controller: _mapController,
              withZoom: widget.withZoom,
              withCross: widget.withCross,
              withSearch: widget.withSearch,
              withCenter: widget.withCenter,
              withToggle: widget.withToggle,
              withLocate: widget.withLocate,
              initialZoom: widget.initialZoom,
              initialCenter: widget.initialCenter,
              interactionFlags: MapConfig.interactive,
              layers: MapConfig.layers,
              markers: widget.markers,
              bottomOverlayInset: _bottomOverlayInset,
            ),
            // Confirm within thumb reach instead of a small AppBar check.
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _ConfirmBar(
                  key: _barKey,
                  position: _selected,
                  onSelect: () => Navigator.pop(context, _selected),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-anchored bar: the live camera-centre coordinate (the point that
/// gets confirmed) above a primary "select here" action. Replaces the old
/// AppBar check button, which sat out of one-handed reach.
class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    super.key,
    required this.position,
    required this.onSelect,
  });

  final LatLng position;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.gps_fixed,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(child: UtmWidget(position: position, wrapped: false)),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onSelect,
              icon: const Icon(Icons.check),
              label: Text(localizations.selectHere),
            ),
          ],
        ),
      ),
    );
  }
}
