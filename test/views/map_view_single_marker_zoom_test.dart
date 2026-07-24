import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/map_view.dart';

/// With no [MapView.initialFit] (fewer than two markers, so the internal
/// default fit doesn't apply) and no explicit [MapView.initialZoom], zero
/// or one markers both default to [MapConfig.defaultAutoFitMaxZoom] — the
/// same "surrounding geographic context" zoom the multi-marker fit caps
/// at, rather than a lone marker zooming in as tight as the full-label
/// threshold allows (reported: a single station previewed at "25 m",
/// tighter than wanted).
void main() {
  Future<MapController> pumpWith(
    WidgetTester tester,
    List<MapMarkerSpec<int>> markers, {
    Size viewport = const Size(360, 400),
  }) async {
    final controller = MapController();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: MapView<int>(
              controller: controller,
              layers: MapConfig.layers,
              withToggle: false,
              withClustering: false,
              initialCenter: const LatLng(59.0, 10.0),
              markers: markers,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return controller;
  }

  MapMarkerSpec<int> marker(int id, LatLng point) => MapMarkerSpec(
    id: id,
    label: 'Marker $id',
    point: point,
    child: const Icon(Icons.place),
  );

  testWidgets(
    'exactly one marker zooms to defaultAutoFitMaxZoom, not the '
    '(unrelated) full-label detail threshold',
    (tester) async {
      final controller = await pumpWith(tester, [
        marker(0, const LatLng(59.0, 10.0)),
      ]);
      expect(controller.camera.zoom, MapConfig.defaultAutoFitMaxZoom);
    },
  );

  testWidgets('zero markers also uses defaultAutoFitMaxZoom', (tester) async {
    final controller = await pumpWith(tester, []);
    expect(controller.camera.zoom, MapConfig.defaultAutoFitMaxZoom);
    // Exactly on initialCenter, with no spurious shift: the zero-marker
    // fit must not reserve a marker-footprint/markerAnchorHeight
    // correction for an icon that does not exist — a regression this
    // exact test caught once already, when fitFor's "no labels" fallback
    // (meant for markers with hidden labels) also fired for truly zero
    // markers and nudged the camera north by a few tenths of a metre.
    expect(controller.camera.center.latitude, 59.0);
    expect(controller.camera.center.longitude, 10.0);
  });

  testWidgets(
    'two or more markers are unaffected by the single-marker default — '
    'the computed (and separately capped) fit zoom wins',
    (tester) async {
      final controller = await pumpWith(tester, [
        marker(0, const LatLng(59.0, 10.0)),
        marker(1, const LatLng(60.5, 11.5)), // ~150 km apart
      ]);
      // A ~150 km spread needs to zoom out well past the cap either way —
      // this just confirms the multi-marker path computed its own zoom
      // rather than reusing the single-marker default verbatim.
      expect(controller.camera.zoom, lessThan(MapConfig.defaultAutoFitMaxZoom));
    },
  );

  testWidgets(
    'an explicit initialZoom always overrides the single-marker default',
    (tester) async {
      final controller = MapController();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 400,
              child: MapView<int>(
                controller: controller,
                layers: MapConfig.layers,
                withToggle: false,
                withClustering: false,
                initialZoom: 9.0,
                initialCenter: const LatLng(59.0, 10.0),
                markers: [marker(0, const LatLng(59.0, 10.0))],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.camera.zoom, 9.0);
    },
  );

  testWidgets(
    'dropping from two markers to one recentres on the survivor at the '
    'single-marker zoom, instead of leaving the camera at the old fit',
    (tester) async {
      var showBoth = true;
      final controller = MapController();
      Widget build() => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 400,
            child: MapView<int>(
              controller: controller,
              layers: MapConfig.layers,
              withToggle: false,
              withClustering: false,
              initialCenter: const LatLng(59.0, 10.0),
              markers: showBoth
                  ? [
                      marker(0, const LatLng(59.0, 10.0)),
                      marker(1, const LatLng(59.5, 10.5)),
                    ]
                  : [marker(0, const LatLng(59.0, 10.0))],
            ),
          ),
        ),
      );

      await tester.pumpWidget(build());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      showBoth = false;
      await tester.pumpWidget(build());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The recentre now goes through the same _defaultFitFor a fresh
      // single-marker MapView uses — including the marker-anchor
      // visual-centroid correction (ADR-0053) that shifts the camera
      // slightly *north* of the marker's raw point, matching what
      // centring on 2+ markers already does. A prior version of this test
      // asserted an exact 1e-9 match to the raw point; that only passed
      // because the old code path used a separate, uncorrected `move()`
      // just for the single-marker case — an inconsistency this
      // consolidation removed, not a behaviour worth preserving.
      expect(controller.camera.center.latitude, greaterThan(59.0));
      expect(controller.camera.center.latitude, closeTo(59.0, 0.001));
      expect(controller.camera.center.longitude, closeTo(10.0, 1e-9));
      expect(controller.camera.zoom, MapConfig.defaultAutoFitMaxZoom);
    },
  );
}
