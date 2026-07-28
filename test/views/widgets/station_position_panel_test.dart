import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/widgets/position_card.dart';
import 'package:ringdrill/views/widgets/station_mini_map.dart';
import 'package:ringdrill/views/widgets/station_position_panel.dart';

/// docs/prompts/position-panel-read-alignment.md — StationPositionPanel on
/// the shared PositionCardShell: a bordered card (mini-map + coordinate bar
/// + chevron) when the station has a position, and the plain `noLocation`
/// fallback (no card, no map) when it does not.
void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
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

  Future<void> pump(WidgetTester tester, Station station) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: StationPositionPanel(exercise: exercise(), station: station),
      ),
    ),
  );

  testWidgets('a positioned station renders the shared card shell with the UTM '
      'coordinate, and tapping the thumbnail opens the interactive map sheet', (
    tester,
  ) async {
    final station = Station(
      index: 0,
      name: 'Post 1',
      position: const LatLng(58.99, 10.43),
    );
    await pump(tester, station);

    expect(find.byType(PositionCardShell), findsOneWidget);
    expect(find.text(l.noLocation), findsNothing);

    // No default chevron_right (dropped from PositionCardShell's bar);
    // no onTap is passed here, so the bar itself is a no-op — only the
    // StationMiniMap thumbnail's own tap opens the sheet.
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.byType(StationMiniMap));
    await tester.pumpAndSettle();

    // The default (non-fillHeight) 200px map height is below
    // MapConfig.minInteractiveHeight, so StationMiniMap stays a static
    // tap-to-expand preview even at this (medium) test width —
    // flutter_test's default ~800x600 MediaQuery reads as
    // WindowSizeClass.medium (hasMasterDetail), but there isn't room
    // here for the interactive command stack. openStationMapSheet is
    // reachable only from that static preview now, so it always opens a
    // bottom sheet (see the "fillHeight + wide window" test below for
    // the genuinely interactive, wide-and-tall case).
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);

    // The header mirrors StationScreen's own AppBar exactly:
    // MasterDetailLeading always renders a close-X in `leading` (there is
    // no MasterDetailScope reachable from a sheet's Overlay, so it never
    // shows the sidebar-toggle branch instead).
    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets(
    'interactive: true renders a directly interactive map with its own FAB '
    'stack (no tap needed), whose built-in expand command opens a genuine '
    'full-screen route — not a dialog, not a bottom sheet',
    (tester) async {
      final station = Station(
        index: 0,
        name: 'Post 1',
        position: const LatLng(58.99, 10.43),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            // interactive is decoupled from fillHeight now — pass it
            // explicitly; fillHeight here just gives the map room to fill.
            body: StationPositionPanel(
              exercise: exercise(),
              station: station,
              fillHeight: true,
              interactive: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Directly interactive — the GestureDetector+IgnorePointer wrapper
      // from the static path is gone; the FAB stack is already on screen,
      // no tap needed to reach it.
      expect(find.byIcon(Icons.center_focus_strong_rounded), findsOneWidget);
      expect(find.byIcon(Icons.open_in_full), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);

      await tester.tap(find.byIcon(Icons.open_in_full));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close), findsNothing);
    },
  );

  testWidgets(
    'compact width opens the map as a bottom sheet, header still has the '
    'same close-X as the dialog',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final station = Station(
        index: 0,
        name: 'Post 1',
        position: const LatLng(58.99, 10.43),
      );
      await pump(tester, station);

      await tester.tap(find.byType(StationMiniMap));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    },
  );

  testWidgets(
    'a station without a position shows the noLocation fallback and no card',
    (tester) async {
      final station = Station(index: 0, name: 'Post 1');
      await pump(tester, station);

      expect(find.text(l.noLocation), findsOneWidget);
      expect(find.byType(PositionCardShell), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    },
  );

  testWidgets(
    'asCard defaults to false (no nested Card when already inside one, e.g. '
    'an ExpandableTile body) and opts into its own Card when set',
    (tester) async {
      final station = Station(
        index: 0,
        name: 'Post 1',
        position: const LatLng(58.99, 10.43),
      );

      // Default (false): embedding inside an ambient Card must not add a
      // second, nested Card around the panel.
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Card(
              child: StationPositionPanel(
                exercise: exercise(),
                station: station,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(Card), findsOneWidget);

      // asCard: true — a bare page with no ambient card, so the panel
      // must draw its own.
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StationPositionPanel(
              exercise: exercise(),
              station: station,
              asCard: true,
            ),
          ),
        ),
      );
      expect(find.byType(Card), findsOneWidget);
    },
  );

  testWidgets(
    'the embedded StationMiniMap has square bottom corners so it sits flush '
    'against the coordinate bar instead of cutting a notch at the seam',
    (tester) async {
      final station = Station(
        index: 0,
        name: 'Post 1',
        position: const LatLng(58.99, 10.43),
      );
      await pump(tester, station);

      final clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(StationMiniMap),
          matching: find.byType(ClipRRect),
        ),
      );
      final radius = clip.borderRadius.resolve(TextDirection.ltr);
      expect(radius.topLeft, const Radius.circular(8));
      expect(radius.topRight, const Radius.circular(8));
      expect(radius.bottomLeft, Radius.zero);
      expect(radius.bottomRight, Radius.zero);
    },
  );
}
