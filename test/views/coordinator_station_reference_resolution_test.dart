import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/field_resolver.dart' show formatUtm;
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/coordinator_screen.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'support/save_roundtrip_harness.dart';

/// Regression: the exercise player's expanded post card used to render its
/// description with no ExerciseScope/StationScope, so `{{station.*}}` stayed
/// literal. `_buildStationDetail` now seeds each station's own scope (mirroring
/// station_list_view.dart), so the token resolves — rendered plain via
/// RingDrillText, like the browser tiles.
const _position = LatLng(59.91, 10.75);

Exercise _exercise() => Exercise(
  uuid: 'ex-coord-ref',
  name: 'Coord ref',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [
    Station(
      index: 0,
      name: 'Post 1',
      description: 'IPP {{station.position.utm}}',
      position: _position,
    ),
  ],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 0),
      SimpleTimeOfDay(hour: 8, minute: 10),
      SimpleTimeOfDay(hour: 8, minute: 15),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
);

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    // Stop the visibility_detector debounce timer (the expanded card embeds a
    // mini-map) so pumpAndSettle does not hang on a pending timer.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() async {
    await initActivePlan('Coord ref plan');
    await ProgramService().saveExercise(l10n, _exercise());
  });

  tearDown(() => ProgramService().clearAllForTest());

  testWidgets(
    'expanding a post resolves {{station.position.utm}} in its description',
    (tester) async {
      useCompactWindow(tester);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PlanScope(
            variables: [],
            child: Scaffold(body: CoordinatorScreen(uuid: 'ex-coord-ref')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expand Post 1 via its chevron (the tile's only IconButton).
      final tile = find.ancestor(
        of: find.text('Post 1'),
        matching: find.byType(ExpandableTile),
      );
      await tester.tap(
        find.descendant(of: tile, matching: find.byType(IconButton)),
      );
      await tester.pumpAndSettle();

      final expectedUtm = formatUtm(_position);
      expect(find.textContaining('{{station.position.utm}}'), findsNothing);
      // The description renders via RingDrillText.rich, so the coordinate is a
      // copy chip (its own Text inside a WidgetSpan). The position panel also
      // shows the UTM (as an EditableText), so match the chip's Text widget.
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == expectedUtm),
        findsWidgets,
      );
    },
  );
}
