import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/views/widgets/exercise_mini_map.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';

void main() {
  // Six station placements a few hundred metres apart — the Eidene shape.
  final markers = <StationLocation>[
    (('u', 0), '2a) Fisker (Angler)', const LatLng(59.1200, 10.4000), null),
    (('u', 1), '2b) Bilcamping', const LatLng(59.1208, 10.4012), null),
    (('u', 2), '2c) Løper', const LatLng(59.1216, 10.3995), null),
    (('u', 3), '2d) Økt selvmordsfare', const LatLng(59.1224, 10.4005), null),
    (('u', 4), '2e) Mental sykdom', const LatLng(59.1232, 10.4015), null),
    (('u', 5), '2f) Barn 4-6 år', const LatLng(59.1240, 10.4008), null),
  ];
  final centroid = markers.average();
  final exercise = Exercise(
    uuid: 'ex-1',
    name: 'Førsteinnsats søk',
    startTime: const SimpleTimeOfDay(hour: 17, minute: 0),
    endTime: const SimpleTimeOfDay(hour: 20, minute: 0),
    numberOfTeams: 4,
    numberOfRounds: 6,
    executionTime: 15,
    evaluationTime: 10,
    rotationTime: 5,
    stations: const [],
    schedule: const [],
  );

  testWidgets('diag: what fit does ExerciseMiniMap actually produce?', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListView(
            children: [
              ExpandableTile(
                title: const Text('Førsteinnsats søk'),
                expanded: true,
                onOpen: () {},
                onToggle: () {},
                body: ExerciseMiniMap(
                  exercise: exercise,
                  markers: markers,
                  mapKey: const ValueKey('exercise-card-map-x'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The real render size of the embedded map, and the MapController
    // MapView created internally (no controller was passed in).
    final mapSize = tester.getSize(find.byType(FlutterMap));
    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    debugPrint(
      'diag: map renders at $mapSize, camera=${controller.camera.center} '
      'zoom=${controller.camera.zoom}',
    );

    // The fit must have centred near the true centroid (regardless of the
    // local render size vs. window fallback question this test used to
    // probe via CameraFit internals — _UnbiasedBoundsFit no longer
    // exposes a padding field to introspect). A loose tolerance, not an
    // exact match: centroidFit's markerAnchorHeight correction now
    // deliberately shifts the centre slightly north of the raw centroid
    // (ExerciseMiniMap shows labels again, so there is a real marker
    // footprint to correct for) — see marker_anchor_centering_test.dart
    // for the precise, direct test of that behaviour.
    expect(controller.camera.center.latitude, closeTo(centroid.latitude, 0.01));
    expect(
      controller.camera.center.longitude,
      closeTo(centroid.longitude, 0.01),
    );
  });

  testWidgets('diag: tap-to-expand path — fit created mid-animation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var expanded = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ListView(
              children: [
                ExpandableTile(
                  title: const Text('Førsteinnsats søk'),
                  expanded: expanded,
                  onOpen: () {},
                  onToggle: () => setState(() => expanded = !expanded),
                  body: ExerciseMiniMap(
                    exercise: exercise,
                    markers: markers,
                    mapKey: const ValueKey('exercise-card-map-x'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Tap the chevron to expand, then pump only a couple of frames so we
    // observe the map's very first build, mid AnimatedSize animation.
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final earlySize = tester.getSize(find.byType(FlutterMap));
    final earlyController = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    debugPrint(
      'diag(tap): first-frames map size=$earlySize '
      'camera=${earlyController.camera.center} zoom=${earlyController.camera.zoom}',
    );

    await tester.pumpAndSettle();
    final settledSize = tester.getSize(find.byType(FlutterMap));
    debugPrint('diag(tap): settled map size=$settledSize');

    // Correctly centred near the true centroid even on the very first,
    // mid-animation build — not just once the AnimatedSize settles. Loose
    // tolerance for the same reason as the test above (markerAnchorHeight
    // deliberately shifts the centre a little north of the raw centroid).
    expect(
      earlyController.camera.center.latitude,
      closeTo(centroid.latitude, 0.01),
    );
    expect(
      earlyController.camera.center.longitude,
      closeTo(centroid.longitude, 0.01),
    );
  });
}
