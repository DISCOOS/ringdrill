import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/views/widgets/collapse_chevron.dart';
import 'package:ringdrill/views/widgets/station_mini_map.dart';
import 'package:ringdrill/views/widgets/station_position_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// DESIGN-010's Spill/Post viewer card consistency prompt — the position card
// (`PositionCardShell`, via `StationPositionPanel`) is its own header-
// equivalent bar (a leading position icon + the uppercase "Position" title,
// docs/design/mockups/collapsible-position-card.html) whenever it is given a
// `sectionId`. Expanded, the collapse chevron floats bare over the map's
// top-right corner; collapsed, it replaces the bar's own trailing editor
// chevron so the two are never shown together. Every other
// `StationPositionPanel` test (e.g. `station_position_panel_test.dart`)
// omits `sectionId`, so this file is scoped to the collapsible variant.
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

  Future<void> pump(WidgetTester tester, {bool fillHeight = false}) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StationPositionPanel(
              exercise: exercise(),
              station: station(),
              asCard: true,
              sectionId: 'position',
              fillHeight: fillHeight,
            ),
          ),
        ),
      );

  testWidgets(
    'expanded by default: the bar is "POSITION" styled like a section '
    'header, the map thumbnail and its editor chevron are visible, plus a '
    'bare collapse chevron over the map',
    (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.byType(StationMiniMap), findsOneWidget);
      expect(find.byType(CollapseChevron), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      // The bar's own leading icon — distinct from the map's own pin
      // marker, which also uses `Icons.place` at a larger size.
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.place && w.size == 18,
        ),
        findsOneWidget,
      );

      final title = tester.widget<Text>(
        find.text(l.position.toUpperCase()),
      );
      expect(title.style?.fontWeight, FontWeight.bold);
      expect(title.style?.letterSpacing, 0.4);
    },
  );

  testWidgets(
    'tapping the collapse chevron hides the map, and the expand chevron '
    'replaces the editor chevron in the bar (never both at once)',
    (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CollapseChevron));
      await tester.pumpAndSettle();

      expect(find.byType(StationMiniMap), findsNothing);
      // The bar itself — title and UTM — stays; the editor chevron is gone,
      // replaced by the (now bar-trailing) expand chevron.
      expect(find.text(l.position.toUpperCase()), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byType(CollapseChevron), findsOneWidget);

      // Tapping the (now bar-trailing) expand chevron brings the map back,
      // and the editor chevron returns.
      await tester.tap(find.byType(CollapseChevron));
      await tester.pumpAndSettle();
      expect(find.byType(StationMiniMap), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
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
    'the bar still opens the position editor sheet while collapsed',
    (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CollapseChevron));
      await tester.pumpAndSettle();
      expect(find.byType(StationMiniMap), findsNothing);

      // Tap the bar's title — a separate tap target from the expand
      // chevron sharing the same row, unaffected by the collapsed state.
      await tester.tap(find.text(l.position.toUpperCase()));
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
      expect(find.text(l.position.toUpperCase()), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    },
  );

  testWidgets(
    'fillHeight always shows the map and never a collapse chevron, even '
    'with a collapsed sectionId already persisted',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        AppConfig.collapsibleSectionKey('position'): true,
      });

      await pump(tester, fillHeight: true);
      await tester.pumpAndSettle();

      expect(find.byType(StationMiniMap), findsOneWidget);
      expect(find.byType(CollapseChevron), findsNothing);
      // The title bar still reads as the shared card header, and the
      // editor chevron stays put — there is simply nothing to collapse.
      expect(find.text(l.position.toUpperCase()), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    },
  );
}
