import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/views/map_view.dart';

/// A marker is rendered `Alignment.topCenter` with its *bottom* edge
/// pinned to its geographic point (`_MapViewState._buildMarker`), so its
/// icon/label box only ever extends upward from the point — never
/// symmetrically around it. Centring the camera on the raw point centroid
/// (even with zero padding bias) still leaves the rendered marker
/// *graphics* looking shifted up, since each marker's own visual centre
/// sits half its rendered height above its point. `centroidFit`'s
/// `markerAnchorHeight` param corrects for this independently of the
/// padding-bias fix (ADR-0053).
void main() {
  final points = [const LatLng(59.0, 10.0), const LatLng(59.01, 10.01)];
  final centroid = points.average();

  Future<MapController> pumpWithAnchorHeight(
    WidgetTester tester,
    double markerAnchorHeight,
  ) async {
    final controller = MapController();
    final fit = points.centroidFit(
      const EdgeInsets.all(20),
      null,
      markerAnchorHeight,
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: MapView<int>(
              controller: controller,
              layers: MapConfig.layers,
              withToggle: false,
              initialFit: fit,
              markers: const [],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return controller;
  }

  testWidgets(
    'zero markerAnchorHeight (the default) centres exactly on the raw '
    'point centroid, unchanged from before this correction existed',
    (tester) async {
      final controller = await pumpWithAnchorHeight(tester, 0);
      expect(controller.camera.center.latitude, closeTo(centroid.latitude, 1e-9));
      expect(
        controller.camera.center.longitude,
        closeTo(centroid.longitude, 1e-9),
      );
    },
  );

  testWidgets(
    'a positive markerAnchorHeight shifts the camera centre north of the '
    'raw point centroid — so the rendered marker graphics (which only '
    'ever extend upward from their points) end up visually centred '
    'instead of the bare, invisible anchor points',
    (tester) async {
      final controller = await pumpWithAnchorHeight(tester, 64);
      // North = higher latitude. The shifted centre must sit strictly
      // north of the untouched point centroid.
      expect(controller.camera.center.latitude, greaterThan(centroid.latitude));
    },
  );

  double? smallShift;

  testWidgets(
    'a taller markerAnchorHeight shifts the centre further north than a '
    'shorter one, proportionally (paired with the next test)',
    (tester) async {
      final small = await pumpWithAnchorHeight(tester, 32);
      smallShift = small.camera.center.latitude - centroid.latitude;
    },
  );

  testWidgets('the larger of the paired anchor heights shifts further', (
    tester,
  ) async {
    final large = await pumpWithAnchorHeight(tester, 128);
    final largeShift = large.camera.center.latitude - centroid.latitude;
    expect(smallShift, isNotNull);
    expect(largeShift, greaterThan(smallShift!));
  });
}
