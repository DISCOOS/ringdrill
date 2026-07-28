import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';

/// Empirical, not just formula-level: pumps a real [MapView] with a
/// [MapMarkerSpec.shortLabel] marker inside a genuinely phone-sized test
/// window (both the full window *and* the local map pane are compact —
/// an earlier version of this test left the window at flutter_test's
/// ~800px default, which is `medium`/`expanded`, not `compact`, and so
/// never actually exercised the compact tier despite claiming to), drives
/// the camera to exact zoom levels via the real [MapController], and
/// asserts exactly which text is rendered at each.
void main() {
  final markers = [
    MapMarkerSpec(
      id: 0,
      label: '1.1 Førsteinnsats søk',
      shortLabel: '1.1',
      point: const LatLng(59.12, 10.40),
      child: const Icon(Icons.place),
    ),
    MapMarkerSpec(
      id: 1,
      label: '1.2 Bilcamping',
      shortLabel: '1.2',
      point: const LatLng(59.1208, 10.4012),
      child: const Icon(Icons.place),
    ),
  ];

  Future<MapController> pumpAt(
    WidgetTester tester,
    double zoom, {
    required Size windowSize,
  }) async {
    tester.view.physicalSize = windowSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = MapController();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MapView<int>(
            controller: controller,
            layers: MapConfig.layers,
            withZoom: true,
            withCenter: true,
            withToggle: true,
            initialCenter: const LatLng(59.12, 10.40),
            initialZoom: zoom,
            markers: markers,
          ),
        ),
      ),
    );
    await tester.pump();
    // MapView computes its own default fit for >=2 markers (ADR-0053),
    // overriding initialZoom on first layout — force the exact zoom this
    // test wants to observe the label tiering at.
    controller.move(const LatLng(59.12, 10.40), zoom);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return controller;
  }

  const phoneSize = Size(390, 844); // genuinely compact: width < 600
  final compactDetailZoom = MapConfig.labelDetailZoomFor(
    WindowSizeClass.compact,
  );

  testWidgets(
    'true phone window: just below labelDetailZoomFor(compact), shows the '
    'short chip',
    (tester) async {
      await pumpAt(tester, compactDetailZoom - 0.1, windowSize: phoneSize);
      expect(find.text('1.1'), findsOneWidget);
      expect(find.text('1.1 Førsteinnsats søk'), findsNothing);
    },
  );

  testWidgets(
    'true phone window: at exactly labelDetailZoomFor(compact), switches '
    'to the full label',
    (tester) async {
      await pumpAt(tester, compactDetailZoom, windowSize: phoneSize);
      expect(find.text('1.1 Førsteinnsats søk'), findsOneWidget);
      expect(find.text('1.1'), findsNothing);
    },
  );

  const tabletSize = Size(820, 1180); // genuinely medium: 600 <= width < 840
  final mediumDetailZoom = MapConfig.labelDetailZoomFor(WindowSizeClass.medium);

  testWidgets(
    'true medium window: just below labelDetailZoomFor(medium), shows '
    'the short chip',
    (tester) async {
      await pumpAt(tester, mediumDetailZoom - 0.1, windowSize: tabletSize);
      expect(find.text('1.1'), findsOneWidget);
      expect(find.text('1.1 Førsteinnsats søk'), findsNothing);
    },
  );

  testWidgets(
    'true medium window: at exactly labelDetailZoomFor(medium), switches '
    'to the full label',
    (tester) async {
      await pumpAt(tester, mediumDetailZoom, windowSize: tabletSize);
      expect(find.text('1.1 Førsteinnsats søk'), findsOneWidget);
      expect(find.text('1.1'), findsNothing);
    },
  );
}
