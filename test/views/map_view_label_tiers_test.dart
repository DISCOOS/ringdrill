import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';

/// A marker's on-map text is zoom-tiered when it carries a
/// [MapMarkerSpec.shortLabel]: the short chip (a station's plan number) at
/// overview zooms, the full label once there is room for it
/// (docs: MapConfig.labelMinZoomFor/labelDetailZoomFor doc comments).
void main() {
  final markers = [
    MapMarkerSpec(
      id: 0,
      label: '1.1 Førsteinnsats',
      shortLabel: '1.1',
      point: const LatLng(59.0, 10.0),
      child: const Icon(Icons.place),
    ),
    MapMarkerSpec(
      id: 1,
      label: 'Bosted',
      point: const LatLng(59.001, 10.001),
      child: const Icon(Icons.home),
    ),
  ];

  Future<void> pumpAt(WidgetTester tester, double zoom) async {
    final controller = MapController();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: 600,
            width: 800,
            child: MapView<int>(
              controller: controller,
              layers: MapConfig.layers,
              withToggle: false,
              withClustering: false,
              initialCenter: const LatLng(59.0, 10.0),
              initialZoom: zoom,
              markers: markers,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // MapView computes its own default fit for >=2 markers (ADR-0053),
    // which overrides initialZoom on first layout — force the exact zoom
    // this test wants to observe the label tiering at, bypassing that fit.
    controller.move(const LatLng(59.0, 10.0), zoom);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'below labelMinZoomFor, every label is present but fully transparent '
    '(reserved-space-but-invisible, not removed — see _ZoomGatedLabel doc)',
    (tester) async {
      await pumpAt(tester, 8.0);
      for (final opacity in tester.widgetList<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      )) {
        expect(opacity.opacity, 0.0);
      }
    },
  );

  testWidgets(
    'between labelMinZoomFor and labelDetailZoomFor, a shortLabel marker '
    'shows its short chip; a marker without one shows its full label',
    (tester) async {
      // WindowSizeClass at 800px width is medium (labelMinZoomFor 11.5,
      // labelDetailZoomFor 16.5) — 13.0 sits inside that window.
      await pumpAt(tester, 13.0);
      expect(find.text('1.1'), findsOneWidget);
      expect(find.text('1.1 Førsteinnsats'), findsNothing);
      expect(find.text('Bosted'), findsOneWidget);
    },
  );

  testWidgets(
    'at/above labelDetailZoomFor, the shortLabel marker switches to its '
    'full label',
    (tester) async {
      await pumpAt(tester, 17.0);
      expect(find.text('1.1'), findsNothing);
      expect(find.text('1.1 Førsteinnsats'), findsOneWidget);
      expect(find.text('Bosted'), findsOneWidget);
    },
  );

  test('labelMinZoomFor sits fully below the Scalebar "500 m" bucket', () {
    // flutter_map's Scalebar (length: m, value -1) rounds
    // index = zoom - (-1) to pick _metricScale; "500 m" is index 15, which
    // covers zoom in [13.5, 14.5). Labels must already be at full opacity
    // by the start of that range so they don't read as "still fading" —
    // this pins the calibration this session's fix relied on.
    expect(MapConfig.labelMinZoom, lessThanOrEqualTo(13.5));
  });

  test(
    'labelDetailZoomFor(compact) is capped at defaultAutoFitMaxZoom, not '
    'left unreachable above it',
    () {
      // Previously labelMinZoomFor(compact) + 5 = 18, uncapped — above
      // defaultAutoFitMaxZoom (16.5), so no auto-fit could ever reach it
      // and compact-window markers only ever showed the short chip.
      // Capping at defaultAutoFitMaxZoom keeps compact's threshold
      // reachable, exactly like medium's (which already sat at 16.5).
      expect(
        MapConfig.labelDetailZoomFor(WindowSizeClass.compact),
        MapConfig.defaultAutoFitMaxZoom,
      );
    },
  );
}
