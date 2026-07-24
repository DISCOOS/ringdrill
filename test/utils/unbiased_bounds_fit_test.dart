import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/views/map_view.dart';

/// centroidFit's fit must land the true centroid at the exact centre of
/// the full viewport, regardless of how asymmetric its padding is — the
/// bug this session kept rediscovering under different padding sources
/// (marker labels, then the FAB command column): flutter_map's own
/// CameraFit.bounds/.coordinates shift the *rendered* centre by the
/// padding's own left/right and top/bottom difference, which is the
/// wrong behaviour when the caller already knows the exact point it wants
/// centred (as centroidFit always does).
void main() {
  final points = [
    const LatLng(59.0, 10.0),
    const LatLng(59.01, 10.01),
  ];
  final centroid = points.average();

  Future<MapController> pumpWithBottomPadding(
    WidgetTester tester,
    EdgeInsets padding,
  ) async {
    final controller = MapController();
    final fit = points.centroidFit(padding);
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
    'symmetric padding centres exactly on the centroid (sanity check)',
    (tester) async {
      final controller = await pumpWithBottomPadding(
        tester,
        const EdgeInsets.all(50),
      );
      expect(controller.camera.center.latitude, closeTo(centroid.latitude, 1e-9));
      expect(
        controller.camera.center.longitude,
        closeTo(centroid.longitude, 1e-9),
      );
    },
  );

  testWidgets(
    'a large bottom-only reserve (simulating the FAB command column) does '
    'NOT shift the centre away from the centroid — the actual bug report',
    (tester) async {
      final controller = await pumpWithBottomPadding(
        tester,
        const EdgeInsets.fromLTRB(50, 50, 50, 300),
      );
      expect(controller.camera.center.latitude, closeTo(centroid.latitude, 1e-9));
      expect(
        controller.camera.center.longitude,
        closeTo(centroid.longitude, 1e-9),
      );
    },
  );

  testWidgets(
    'a large top-only reserve (simulating a search field) also does not '
    'shift the centre',
    (tester) async {
      final controller = await pumpWithBottomPadding(
        tester,
        const EdgeInsets.fromLTRB(50, 300, 50, 50),
      );
      expect(controller.camera.center.latitude, closeTo(centroid.latitude, 1e-9));
      expect(
        controller.camera.center.longitude,
        closeTo(centroid.longitude, 1e-9),
      );
    },
  );

  testWidgets(
    'asymmetric left/right padding does not shift the centre either',
    (tester) async {
      final controller = await pumpWithBottomPadding(
        tester,
        const EdgeInsets.fromLTRB(20, 50, 200, 50),
      );
      expect(controller.camera.center.latitude, closeTo(centroid.latitude, 1e-9));
      expect(
        controller.camera.center.longitude,
        closeTo(centroid.longitude, 1e-9),
      );
    },
  );

  double? tightZoom;

  testWidgets(
    'zoom still reflects a tight padding baseline (paired with the next '
    'test — the fit still protects real overlay clearance via zoom, only '
    'centring is unbiased)',
    (tester) async {
      final tight = await pumpWithBottomPadding(
        tester,
        const EdgeInsets.all(20),
      );
      tightZoom = tight.camera.zoom;
    },
  );

  testWidgets(
    'more bottom padding than the previous test still forces more '
    'zoom-out to fit the same bounds',
    (tester) async {
      final roomy = await pumpWithBottomPadding(
        tester,
        const EdgeInsets.fromLTRB(20, 20, 20, 300),
      );
      expect(tightZoom, isNotNull);
      expect(roomy.camera.zoom, lessThan(tightZoom!));
    },
  );
}
