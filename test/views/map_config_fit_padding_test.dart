import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/map_view.dart';

/// MapConfig.fitPadding's marker-footprint, command-stack and
/// viewport-proportional awareness: a fit must reserve enough padding that
/// a marker's own rendered box (label above its icon, anchored bottom-centre
/// at the geographic point — see MapView._buildMarker) never clips at the
/// viewport edge or slides under the FAB overlays, while the *aesthetic*
/// breathing-room components shrink proportionally on a small viewport
/// instead of consuming a large, fixed fraction of it regardless of size
/// (ADR-0053) — the narrow/mobile "zoomed out far more than the data
/// warrants" bug.
void main() {
  // A generously large viewport where the aesthetic-padding cap never binds
  // (min(flat, cap) == flat), so these assertions describe the same flat
  // values the pre-ADR-0053 defaults used, unaffected by capping.
  const roomyViewport = Size(1200, 900);

  testWidgets('omitting labels keeps the original flat left/right padding on a '
      'roomy viewport (the icon-only footprint floor sits under the 64px '
      'side floor there), plus half the icon-only height on top of the '
      'search-field reserve — the icon itself still renders and still '
      'needs edge clearance even with no label to protect', (tester) async {
    final padding = MapConfig.fitPadding(
      withSearch: true,
      viewport: roomyViewport,
    );
    expect(padding.left, 64);
    expect(padding.right, 64);
    // 112 (search reserve) + half of the icon-only height (32px at the
    // expanded 1.35x marker scale, split top/bottom per the centring
    // rule below) = 112 + 21.6.
    expect(padding.top, 112 + 32 * 1.35 / 2);
  });

  testWidgets('a wide label widens left/right padding beyond the flat 64px', (
    tester,
  ) async {
    final short = MapConfig.fitPadding(
      labels: const ['A'],
      viewport: roomyViewport,
    );
    final long = MapConfig.fitPadding(
      labels: const ['This is a very long marker label for testing'],
      viewport: roomyViewport,
    );

    expect(short.left, 64); // short label's half-width stays under the floor
    expect(long.left, greaterThan(short.left));
    expect(long.right, greaterThan(short.right));
  });

  testWidgets(
    'a marker label adds its fixed box height to the top clearance, on top '
    'of the search-field reserve',
    (tester) async {
      final noLabels = MapConfig.fitPadding(
        withSearch: true,
        viewport: roomyViewport,
      );
      final withLabels = MapConfig.fitPadding(
        withSearch: true,
        labels: const ['Role'],
        viewport: roomyViewport,
      );

      expect(withLabels.top, greaterThan(noLabels.top));
    },
  );

  testWidgets(
    'a marker label adds half its fixed box height to the bottom clearance '
    'too, so a fit with labels but no search field or FAB stack to '
    'counterbalance it does not bias the fitted centroid toward the '
    'bottom half of the viewport (every static mini-map preview) — without '
    'adding a second full copy that would force extra zoom-out',
    (tester) async {
      final noLabels = MapConfig.fitPadding(viewport: roomyViewport);
      final withLabels = MapConfig.fitPadding(
        labels: const ['Role'],
        viewport: roomyViewport,
      );

      expect(withLabels.bottom, greaterThan(noLabels.bottom));
      // With neither a search field nor any FAB command active, top and
      // bottom share the same base (both the aesthetic no-overlay
      // constant) plus the same markerHeight/2 term, so they land exactly
      // equal — the centroid stays dead-centre instead of skewed down.
      expect(withLabels.top, withLabels.bottom);
      // The full label footprint is split across both sides, not doubled:
      // each side's added share is exactly half of what a single-sided
      // reserve would have been, so the combined total (and thus the
      // resulting zoom level) doesn't grow just because it's now balanced.
      final singleSidedShare = withLabels.top - noLabels.top;
      expect(withLabels.bottom - noLabels.bottom, singleSidedShare);
    },
  );

  testWidgets(
    'the label footprint is capped against the viewport, so one long label '
    'cannot starve a compact mini-map fit — labels are zoom-gated invisible '
    'at the overview zooms such a fit lands on, so reserving their full '
    'flat width on a 360px-wide preview squeezed the fit into a ~70px '
    'strip and forced a massive zoom-out for nothing visible',
    (tester) async {
      const miniMap = Size(360, 200);
      const longLabels = ['2d) Økt selvmordsfare', '2a) Fisker (Angler)'];
      final padding = MapConfig.fitPadding(
        viewport: miniMap,
        labels: longLabels,
      );

      // Both sides together never eat more than 30% of the width, and
      // top+bottom stay under half the height, however long the label.
      expect(padding.horizontal, lessThanOrEqualTo(miniMap.width * 0.3));
      expect(padding.vertical, lessThanOrEqualTo(miniMap.height * 0.5));

      // A roomy viewport still reserves the label's real (larger)
      // footprint — the cap only ever binds when the viewport is small.
      final roomy = MapConfig.fitPadding(
        viewport: roomyViewport,
        labels: longLabels,
      );
      expect(roomy.left, greaterThan(padding.left));
    },
  );

  testWidgets(
    'marker footprint scales up with viewport width, matching MapView\'s '
    'own per-window-size marker scale',
    (tester) async {
      const label = ['Hanne Thorsen'];
      // Same height for both so any difference in `top` reflects the
      // marker-scale change alone, not the (height-driven) aesthetic cap.
      final compact = MapConfig.fitPadding(
        labels: label,
        viewport: const Size(360, 900),
      );
      final expanded = MapConfig.fitPadding(
        labels: label,
        viewport: const Size(1000, 900),
      );

      expect(expanded.top, greaterThan(compact.top));
      expect(expanded.left, greaterThanOrEqualTo(compact.left));
    },
  );

  testWidgets(
    'bottom padding mirrors the actual command-column composition, not a '
    'flat guess — more active commands reserve more room',
    (tester) async {
      const viewport = Size(390, 800);
      final none = MapConfig.fitPadding(viewport: viewport);
      final centerOnly = MapConfig.fitPadding(
        withCenter: true,
        viewport: viewport,
      );
      final zoomOnly = MapConfig.fitPadding(withZoom: true, viewport: viewport);
      final allThree = MapConfig.fitPadding(
        withLocate: true,
        withZoom: true,
        withCenter: true,
        viewport: viewport,
      );

      // 48 (aesthetic no-commands base) + half the icon-only height (32px
      // at compact 1.0x scale) reserved even with no labels — the marker
      // icon itself still renders and needs edge clearance.
      expect(none.bottom, 48 + 32 * 1.0 / 2);
      // One command (centre) reserves more than none.
      expect(centerOnly.bottom, greaterThan(none.bottom));
      // The zoom pair (two buttons) reserves more than a single command.
      expect(zoomOnly.bottom, greaterThan(centerOnly.bottom));
      // All three stacked reserves more than any subset.
      expect(allThree.bottom, greaterThan(zoomOnly.bottom));
    },
  );

  testWidgets('the command-column reserve scales with MapCommandSize at wider '
      'viewport widths, matching the larger FAB diameter MapView itself '
      'renders there', (tester) async {
    final compact = MapConfig.fitPadding(
      withCenter: true,
      withZoom: true,
      withLocate: true,
      viewport: const Size(360, 800),
    );
    final expanded = MapConfig.fitPadding(
      withCenter: true,
      withZoom: true,
      withLocate: true,
      viewport: const Size(1000, 800),
    );

    expect(expanded.bottom, greaterThan(compact.bottom));
  });

  testWidgets(
    'aesthetic padding shrinks in absolute terms on a small viewport, not '
    'just as a fraction — the narrow/mobile over-zoom-out bug this ADR '
    'fixes (flat pixels consumed a much bigger fraction of a small '
    'viewport, forcing far more zoom-out than the data warranted)',
    (tester) async {
      // No labels/search/commands — every component here is the "aesthetic"
      // kind, so a small viewport should get a smaller absolute reserve
      // than a large one, not the same flat pixel amount regardless of
      // size.
      final small = MapConfig.fitPadding(viewport: const Size(300, 300));
      final large = MapConfig.fitPadding(viewport: roomyViewport);

      expect(small.left, lessThan(large.left));
      expect(small.top, lessThan(large.top));
      expect(small.bottom, lessThan(large.bottom));
      // Never collapses below half the flat value, even on a tiny viewport.
      expect(small.left, greaterThanOrEqualTo(32));
      expect(small.top, greaterThanOrEqualTo(24));
    },
  );

  testWidgets('a marker\'s icon still reserves its own footprint with an empty '
      'labels list — it renders regardless of whether its label does (the '
      'showLabels: false case passes an empty list on purpose), so reserving '
      'zero footprint let the topmost marker\'s icon clip at the viewport '
      'edge (reported: a static preview\'s top marker sitting right at the '
      'border, with "250 m" of scale bar to spare)', (tester) async {
    const miniMap = Size(360, 200);
    final padding = MapConfig.fitPadding(viewport: miniMap);
    // compact scale (1.0): 24px aesthetic no-overlay base (capped for
    // this short a viewport) + half the 32px icon-only height = 40px —
    // the reverted (bugged) behaviour would land exactly on the 24px
    // aesthetic base alone, with nothing reserved for the icon.
    expect(padding.top, 40);
  });

  group('MapView self-computed default fit', () {
    List<MapMarkerSpec<int>> markers() => [
      MapMarkerSpec(
        id: 0,
        label: 'A',
        point: const LatLng(59.0, 10.0),
        child: const SizedBox.shrink(),
      ),
      MapMarkerSpec(
        id: 1,
        label: 'B',
        point: const LatLng(59.9, 10.9),
        child: const SizedBox.shrink(),
      ),
    ];

    testWidgets(
      'a rebuild with an unchanged-but-new-instance markers list does not '
      're-fit the camera, so it never fights the user\'s own pan/zoom',
      (tester) async {
        final controller = MapController();

        Widget build() => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: MapView<int>(
                controller: controller,
                layers: MapConfig.layers,
                // A fresh List instance each build, same underlying data —
                // this is what every real caller's rebuild looks like.
                markers: markers(),
              ),
            ),
          ),
        );

        await tester.pumpWidget(build());
        await tester.pump();

        // Simulate the user having since panned/zoomed away from whatever
        // the initial fit landed on.
        controller.move(const LatLng(0, 0), 3);
        await tester.pump();

        await tester.pumpWidget(build());
        await tester.pump();

        expect(controller.camera.center.latitude, closeTo(0, 1e-9));
        expect(controller.camera.center.longitude, closeTo(0, 1e-9));
        expect(controller.camera.zoom, 3);
      },
    );

    testWidgets(
      'a rebuild whose markers actually moved does re-fit the camera',
      (tester) async {
        final controller = MapController();
        var moved = false;

        Widget build() => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: MapView<int>(
                controller: controller,
                layers: MapConfig.layers,
                markers: moved
                    ? [
                        MapMarkerSpec(
                          id: 0,
                          label: 'A',
                          point: const LatLng(10.0, 10.0),
                          child: const SizedBox.shrink(),
                        ),
                        MapMarkerSpec(
                          id: 1,
                          label: 'B',
                          point: const LatLng(10.9, 10.9),
                          child: const SizedBox.shrink(),
                        ),
                      ]
                    : markers(),
              ),
            ),
          ),
        );

        await tester.pumpWidget(build());
        await tester.pump();

        controller.move(const LatLng(0, 0), 3);
        await tester.pump();
        expect(controller.camera.zoom, 3);

        moved = true;
        await tester.pumpWidget(build());
        await tester.pump();

        // The point set changed, so the camera should have moved away from
        // the manually-set (0, 0) / zoom 3 to fit the new markers.
        expect(
          controller.camera.center.latitude == 0 &&
              controller.camera.center.longitude == 0 &&
              controller.camera.zoom == 3,
          isFalse,
        );
      },
    );
  });
}
