import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/widgets/collapse_chevron.dart';
import 'package:ringdrill/views/widgets/station_mini_map.dart';
import 'package:ringdrill/views/widgets/station_position_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// DESIGN-010 follow-up: collapsible-section-cards, commit 3 — the position
// card (`PositionCardShell`, via `StationPositionPanel`) collapses to just
// its coordinate bar when given a `sectionId`, via a leading `CollapseChevron`
// on the bar — a separate tap target from the bar's own `onTap` (opens the
// interactive map sheet). Every other `StationPositionPanel` test (e.g.
// `station_position_panel_test.dart`) omits `sectionId`, so this file is
// scoped to the collapse behaviour specifically.
// ---------------------------------------------------------------------------

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Exercise exercise() => Exercise(
    uuid: 'ex-1',
    name: 'Exercise',
    startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
    endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
    numberOfTeams: 1,
    numberOfRounds: 1,
    executionTime: 10,
    evaluationTime: 5,
    rotationTime: 5,
    stations: const [],
    schedule: const [],
  );

  Station station() => Station(
    index: 0,
    name: 'Post 1',
    position: const LatLng(58.99, 10.43),
  );

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: StationPositionPanel(
          exercise: exercise(),
          station: station(),
          asCard: true,
          sectionId: 'position',
        ),
      ),
    ),
  );

  testWidgets(
    'expanded by default: map thumbnail, coordinate bar and its editor '
    'chevron are all visible, plus the collapse chevron',
    (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.byType(StationMiniMap), findsOneWidget);
      expect(find.byType(CollapseChevron), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.text(l.position), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the collapse chevron hides the map, keeping only the '
    'coordinate bar (label, UTM and the editor chevron)',
    (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CollapseChevron));
      await tester.pumpAndSettle();

      expect(find.byType(StationMiniMap), findsNothing);
      // The bar itself — label, UTM row and its own editor chevron — stays.
      expect(find.text(l.position), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Tapping the collapse chevron again brings the map back.
      await tester.tap(find.byType(CollapseChevron));
      await tester.pumpAndSettle();
      expect(find.byType(StationMiniMap), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the collapse chevron does not open the position editor sheet',
    (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CollapseChevron));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
    },
  );

  testWidgets(
    'the coordinate bar still opens the position editor sheet while '
    'collapsed',
    (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CollapseChevron));
      await tester.pumpAndSettle();
      expect(find.byType(StationMiniMap), findsNothing);

      // Tap the bar's own editor chevron — separate tap target from the
      // collapse chevron, unaffected by the collapsed state.
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
    },
  );

  testWidgets(
    'the collapsed state persists through SharedPreferences across a '
    'rebuild',
    (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CollapseChevron));
      await tester.pumpAndSettle();
      expect(find.byType(StationMiniMap), findsNothing);

      // Simulate a fresh mount (e.g. app restart) reading the same store.
      await tester.pumpWidget(const SizedBox.shrink());
      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.byType(StationMiniMap), findsNothing);
      expect(find.text(l.position), findsOneWidget);
    },
  );
}
