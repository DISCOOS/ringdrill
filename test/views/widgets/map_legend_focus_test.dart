import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/widgets/map_camera_link.dart';
import 'package:ringdrill/views/widgets/map_legend.dart';

/// The legend strip under a map card names each marker, which makes it the one
/// place a reader already looks to ask "which pin is the LKP?" — so it is also
/// where they reach to ask "and where is it?". An entry that carries a position
/// is therefore tappable and moves the map onto that marker.
///
/// The coupling is deliberately loose in both directions, since the legend and
/// the map are siblings under `PositionCardShell` and neither can reach the
/// other: no scope (or no position on the entry) leaves the plain static strip,
/// and a map with no scope above it is unaffected.
void main() {
  const oslo = LatLng(59.913, 10.752);
  const bergen = LatLng(60.39, 5.32);

  Widget app(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  Finder inkWellAround(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(InkWell));

  group('wiring', () {
    testWidgets('an entry with a position drives the ambient link', (
      tester,
    ) async {
      final link = MapCameraLink();
      List<LatLng>? focused;
      link.attach((points) => focused = points);

      await tester.pumpWidget(
        app(
          MapCameraScope(
            link: link,
            child: const MapLegend(
              entries: [
                MapLegendEntry(color: Colors.red, label: 'LKP', points: [oslo]),
                MapLegendEntry(color: Colors.brown, label: 'Legend only'),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('LKP'));
      expect(focused, [oslo]);

      // An entry with no position is not a way to get anywhere, so it must not
      // offer the affordance — a dead tap target reads as a broken one.
      expect(inkWellAround('Legend only'), findsNothing);
      expect(inkWellAround('LKP'), findsOneWidget);
    });

    testWidgets('outside a scope the strip stays static', (tester) async {
      await tester.pumpWidget(
        app(
          const MapLegend(
            entries: [
              MapLegendEntry(color: Colors.red, label: 'LKP', points: [oslo]),
            ],
          ),
        ),
      );

      expect(find.text('LKP'), findsOneWidget);
      expect(inkWellAround('LKP'), findsNothing);
    });

    // The legend and the map are built in the same frame, and the legend goes
    // first — so a legend that decided tappability from "is a map attached yet"
    // would render inert on every first build. It asks whether a scope exists,
    // which is knowable at build time, and lets the focus call no-op instead.
    testWidgets('an entry is tappable before any map has attached', (
      tester,
    ) async {
      final link = MapCameraLink();
      await tester.pumpWidget(
        app(
          MapCameraScope(
            link: link,
            child: const MapLegend(
              entries: [
                MapLegendEntry(color: Colors.red, label: 'LKP', points: [oslo]),
              ],
            ),
          ),
        ),
      );

      expect(link.isAttached, isFalse);
      expect(inkWellAround('LKP'), findsOneWidget);
      await tester.tap(find.text('LKP'));
      // Nothing to assert but the absence of a throw: focusOn on an unattached
      // link is a no-op by design.
    });
  });

  group('with a real map under the same scope', () {
    MapMarkerSpec<int> marker(int id, String label, LatLng point) =>
        MapMarkerSpec(
          id: id,
          label: label,
          point: point,
          child: const Icon(Icons.place),
        );

    Future<MapController> pump(
      WidgetTester tester,
      List<MapLegendEntry> entries,
    ) async {
      final controller = MapController();
      await tester.pumpWidget(
        app(
          MapCameraScope(
            link: MapCameraLink(),
            child: Column(
              children: [
                SizedBox(
                  width: 360,
                  height: 300,
                  child: MapView<int>(
                    controller: controller,
                    layers: MapConfig.layers,
                    withToggle: false,
                    withClustering: false,
                    initialCenter: const LatLng(59.0, 10.0),
                    markers: [
                      marker(0, 'Post', oslo),
                      marker(1, 'LKP', bergen),
                    ],
                  ),
                ),
                MapLegend(entries: entries),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      return controller;
    }

    // Scoped to the legend: the map draws its own label for the same marker, so
    // a bare text finder matches twice under this group.
    Future<void> tapLegend(WidgetTester tester, String label) => tester.tap(
      find.descendant(of: find.byType(MapLegend), matching: find.text(label)),
    );

    testWidgets('a single-position entry zooms in on it', (tester) async {
      final controller = await pump(tester, const [
        MapLegendEntry(color: Colors.red, label: 'LKP', points: [bergen]),
      ]);
      final zoomBefore = controller.camera.zoom;

      await tapLegend(tester, 'LKP');
      await tester.pump();

      expect(controller.camera.center.latitude, closeTo(bergen.latitude, 1e-6));
      expect(
        controller.camera.center.longitude,
        closeTo(bergen.longitude, 1e-6),
      );
      // Panning at the card's opening zoom would leave the reader on a dot among
      // dots. The detail zoom is where a marker's chip expands to its full
      // label, so arriving at a marker is exactly when its name shows.
      expect(
        controller.camera.zoom,
        MapConfig.labelDetailZoomFor(WindowSizeClass.fromWidth(360)),
      );
      expect(controller.camera.zoom, greaterThan(zoomBefore));
    });

    // A reader already closer in than the detail threshold asked to go
    // somewhere, not to give up their zoom level.
    testWidgets('a single-position entry never zooms out', (tester) async {
      final controller = await pump(tester, const [
        MapLegendEntry(color: Colors.red, label: 'LKP', points: [bergen]),
      ]);
      controller.move(const LatLng(63.4, 10.4), 18);
      await tester.pump();

      await tapLegend(tester, 'LKP');
      await tester.pump();

      expect(controller.camera.center.latitude, closeTo(bergen.latitude, 1e-6));
      expect(controller.camera.zoom, 18);
    });

    // A legend entry can stand for several markers — the Post viewer has one
    // entry per LocationKind, and a station can hold two locations of the same
    // kind. Framing all of them is the honest answer; picking the first would
    // silently hide the rest.
    testWidgets('a multi-position entry frames all of them', (tester) async {
      final controller = await pump(tester, const [
        MapLegendEntry(
          color: Colors.red,
          label: 'Locations',
          points: [oslo, bergen],
        ),
      ]);
      // Start somewhere neither point is visible, so the fit has to do work.
      controller.move(const LatLng(63.4, 10.4), 12);
      await tester.pump();

      await tapLegend(tester, 'Locations');
      await tester.pump();

      expect(controller.camera.visibleBounds.contains(oslo), isTrue);
      expect(controller.camera.visibleBounds.contains(bergen), isTrue);
    });
  });
}
