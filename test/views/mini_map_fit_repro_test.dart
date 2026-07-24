import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/map_view.dart';

void main() {
  // Real-world repro: station placement at Eidene (Tjøme) plus two scenario
  // locations at Konnerud (Drammen), ~65 km apart — the exact data shape
  // from the user's broken "2000 km" station position card.
  final points = [
    const LatLng(59.12, 10.40), // Eidene, Tjøme (station position)
    const LatLng(59.72, 10.13), // Konnerud, Drammen (Bosted)
    const LatLng(59.71, 10.15), // Konnerud, Drammen (LKP)
  ];

  List<MapMarkerSpec<int>> markers() => [
    for (var i = 0; i < points.length; i++)
      MapMarkerSpec(
        id: i,
        label: 'Marker with a fairly long label $i',
        point: points[i],
        child: const Icon(Icons.place, size: 32),
      ),
  ];

  testWidgets('140px-tall mini-map fit lands at a sane zoom, not minZoom', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = MapController();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 100), // some content above, like a card
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: IgnorePointer(
                    child: MapView<int>(
                      controller: controller,
                      layers: MapConfig.layers,
                      withToggle: false,
                      withClustering: false,
                      initialZoom: 15,
                      initialCenter: points.first,
                      markers: markers(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final zoom = controller.camera.zoom;
    final size = controller.camera.nonRotatedSize;
    debugPrint(
      'repro 140px: zoom=$zoom canvas=${size.width}x${size.height} '
      'center=${controller.camera.center}',
    );

    // ~65 km N-S into a 140px-tall map should land somewhere around zoom
    // 5.5-7.5. Landing at/near minZoom (2) means the fit's padding consumed
    // the whole canvas.
    expect(zoom, greaterThan(4.0));
  });

  testWidgets('200px-tall mini-map with a ~700m spread (exercise card)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Six stations within ~700 m, like the Eidene exercise.
    final local = [
      for (var i = 0; i < 6; i++) LatLng(59.120 + i * 0.0012, 10.400),
    ];
    final controller = MapController();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                height: 200,
                width: double.infinity,
                child: IgnorePointer(
                  child: MapView<int>(
                    controller: controller,
                    layers: MapConfig.layers,
                    withToggle: false,
                    withClustering: false,
                    initialZoom: 15,
                    initialCenter: local.first,
                    markers: [
                      for (var i = 0; i < local.length; i++)
                        MapMarkerSpec(
                          id: i,
                          label: '2${String.fromCharCode(97 + i)}) Station $i',
                          point: local[i],
                          child: const Icon(Icons.place, size: 32),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final zoom = controller.camera.zoom;
    debugPrint(
      'repro 200px: zoom=$zoom canvas=${controller.camera.nonRotatedSize}',
    );
    // ~700 m into ~130 usable px is roughly zoom 13-15; well above 11 in
    // any healthy configuration.
    expect(zoom, greaterThan(11.0));
  });
}
