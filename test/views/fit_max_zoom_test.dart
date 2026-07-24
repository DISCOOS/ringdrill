import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/map_view.dart';

/// MapConfig.fitFor's default max-zoom cap: a handful of markers only a
/// few hundred metres apart should still show some surrounding geographic
/// context, not zoom in only as tight as the bare marker spread requires
/// (reported: 6 stations ~700 m apart landed at a "50 m" scale reading,
/// wanted closer to "100 m").
void main() {
  // A ~100 m north-south spread — tight enough that the uncapped fit would
  // naturally want to zoom in well past defaultAutoFitMaxZoom.
  final tightCluster = [
    for (var i = 0; i < 6; i++)
      MapMarkerSpec(
        id: i,
        label: 'Station $i',
        point: LatLng(59.1200 + i * 0.00016, 10.400),
        child: const Icon(Icons.place),
      ),
  ];

  Future<double> pumpAndGetZoom(
    WidgetTester tester,
    List<MapMarkerSpec<int>> markers,
  ) async {
    final controller = MapController();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 600,
            child: MapView<int>(
              controller: controller,
              layers: MapConfig.layers,
              withToggle: false,
              withClustering: false,
              markers: markers,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return controller.camera.zoom;
  }

  testWidgets(
    'a tight cluster (6 markers ~100 m apart) is capped at '
    'defaultAutoFitMaxZoom, not zoomed in tighter',
    (tester) async {
      final zoom = await pumpAndGetZoom(tester, tightCluster);
      expect(zoom, MapConfig.defaultAutoFitMaxZoom);
    },
  );

  testWidgets(
    'a widely-spread cluster (needs to zoom OUT further than the cap) is '
    'unaffected — the cap only ever binds when it would zoom in tighter',
    (tester) async {
      final wideSpread = [
        MapMarkerSpec(
          id: 0,
          label: 'A',
          point: const LatLng(59.0, 10.0),
          child: const Icon(Icons.place),
        ),
        MapMarkerSpec(
          id: 1,
          label: 'B',
          point: const LatLng(60.5, 11.5), // ~150 km away
          child: const Icon(Icons.place),
        ),
      ];
      final zoom = await pumpAndGetZoom(tester, wideSpread);
      expect(zoom, lessThan(MapConfig.defaultAutoFitMaxZoom));
    },
  );
}
