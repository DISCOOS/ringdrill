import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/prefs.dart';
import 'package:ringdrill/views/widgets/collapse_chevron.dart';
import 'package:ringdrill/views/widgets/station_mini_map.dart';
import 'package:ringdrill/views/widgets/station_position_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// DESIGN-010's Spill/Post viewer card consistency prompt — the position card
// (`PositionCardShell`, via `StationPositionPanel`) renders the same plain
// "Position" bar label whenever it is given a `sectionId`, no special
// header-style treatment (bold/uppercase/leading icon) — PositionCardShell no
// longer builds one automatically. Expanded, the collapse chevron floats bare
// over the map's top-right corner; collapsed, it replaces the bar's own
// trailing slot (empty by default here, since StationPositionPanel passes no
// `barTrailing`) so the two are never shown together. Every other
// `StationPositionPanel` test (e.g. `station_position_panel_test.dart`)
// omits `sectionId`, so this file is scoped to the collapsible variant.
//
// The map folds via a vertical SizeTransition (shared with
// CollapsibleSectionCard): it stays in the tree and is clipped to zero height
// when collapsed, so it can slide rather than vanish. "Hidden" is therefore
// asserted as zero clipped height (its SizeTransition ancestor), not as an
// absent widget.
//
// StationPositionPanel passes no `onTap` in these tests, so the bar's own tap
// only ever toggles collapse (or is a no-op when not collapsible) — it never
// opens the interactive map sheet. Only the StationMiniMap thumbnail's own
// tap affordance does that (see station_position_panel_test.dart).
// ---------------------------------------------------------------------------

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Prefs reads are synchronous now, so a stored value is only visible to a
    // bound instance. Rebound per test, since setMockInitialValues builds a
    // fresh one and a stale binding would serve the previous test's values.
    Prefs.reset();
    Prefs.bind(await SharedPreferences.getInstance());
    addTearDown(Prefs.reset);
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

  Station station() =>
      Station(index: 0, name: 'Post 1', position: const LatLng(58.99, 10.43));

  /// The clipped height of the map section — the [SizeTransition] wrapping
  /// the [StationMiniMap]. Zero when collapsed, the map's full height when
  /// expanded.
  double mapHeight(WidgetTester tester) {
    final sizeTransition = find
        .ancestor(
          of: find.byType(StationMiniMap),
          matching: find.byType(SizeTransition),
        )
        .first;
    return tester.getSize(sizeTransition).height;
  }

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
    'expanded by default: the bar shows the plain "Position" label, the map '
    'thumbnail is visible with no default trailing icon, plus a bare '
    'collapse chevron over the map',
    (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.byType(StationMiniMap), findsOneWidget);
      expect(mapHeight(tester), greaterThan(0));
      expect(find.byType(CollapseChevron), findsOneWidget);
      // No default chevron_right (dropped from PositionCardShell's bar);
      // StationPositionPanel passes no barTrailing.
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.text(l.position), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the collapse chevron hides the map, and the expand chevron '
    'takes the bar\'s trailing slot while collapsed',
    (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CollapseChevron));
      await tester.pumpAndSettle();

      // Clipped to zero height, not removed.
      expect(mapHeight(tester), 0);
      // The bar itself — label and UTM — stays; the expand chevron now
      // occupies the (otherwise empty) trailing slot.
      expect(find.text(l.position), findsOneWidget);
      expect(find.byType(CollapseChevron), findsOneWidget);

      // Tapping the (now bar-trailing) expand chevron brings the map back.
      await tester.tap(find.byType(CollapseChevron));
      await tester.pumpAndSettle();
      expect(mapHeight(tester), greaterThan(0));
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
    'tapping the bar while collapsed re-expands it rather than opening the '
    'position editor sheet; tapping the thumbnail opens the sheet while '
    'expanded',
    (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CollapseChevron));
      await tester.pumpAndSettle();
      expect(mapHeight(tester), 0);

      // No `onTap` is passed to StationPositionPanel in this harness, so
      // the bar's own tap only ever toggles collapse — tapping the label
      // re-expands, it never opens the sheet.
      await tester.tap(find.text(l.position));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(mapHeight(tester), greaterThan(0));

      // The thumbnail is the one affordance that opens the interactive
      // map surface, regardless of the bar's collapse/onTap wiring. This
      // harness's default (non-fillHeight) 200px map height is below
      // MapConfig.minInteractiveHeight, so the map stays a static
      // tap-to-expand preview even at this (medium) test width —
      // flutter_test's default ~800x600 MediaQuery reads as
      // WindowSizeClass.medium (hasMasterDetail) — and its tap opens a
      // bottom sheet, not a dialog (see station_position_panel_test.dart's
      // "fillHeight + wide window" test for the genuinely interactive,
      // wide-and-tall case).
      await tester.tap(find.byType(StationMiniMap));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
    },
  );

  testWidgets('the collapsed state persists through SharedPreferences across a '
      'rebuild', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CollapseChevron));
    await tester.pumpAndSettle();
    expect(mapHeight(tester), 0);

    // Simulate a fresh mount (e.g. app restart) reading the same store.
    await tester.pumpWidget(const SizedBox.shrink());
    await pump(tester);
    await tester.pumpAndSettle();

    expect(mapHeight(tester), 0);
    expect(find.text(l.position), findsOneWidget);
  });

  testWidgets(
    'fillHeight always shows the map and never a collapse chevron, even '
    'with a collapsed sectionId already persisted',
    (tester) async {
      Prefs.reset();
      SharedPreferences.setMockInitialValues({
        AppConfig.collapsibleSectionKey('position'): true,
      });
      Prefs.bind(await SharedPreferences.getInstance());

      await pump(tester, fillHeight: true);
      await tester.pumpAndSettle();

      expect(find.byType(StationMiniMap), findsOneWidget);
      expect(find.byType(CollapseChevron), findsNothing);
      // The bar still shows its plain label; there is simply nothing to
      // collapse, and no default trailing icon either.
      expect(find.text(l.position), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    },
  );
}
