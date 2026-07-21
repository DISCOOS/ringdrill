import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/map_view.dart';

/// docs/prompts/map-picker-redesign.md — bottomOverlayInset lets a caller
/// (MapPickerScreen's confirm bar) reserve bottom clearance for MapView's
/// own bottom-anchored chrome without MapView knowing what that caller is.
///
/// Anchored on the "locate me" command (Icons.my_location, gated only by
/// withLocate) rather than zoom (Icons.add), which is also gated by the
/// user's persisted MapSettings.showZoomControls toggle.
void main() {
  testWidgets(
    'bottomOverlayInset pushes both the command column and the scale bar '
    'up by the same amount',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MapView<int>(
              layers: MapConfig.layers,
              withLocate: true,
              bottomOverlayInset: 50,
            ),
          ),
        ),
      );
      await tester.pump();

      final commandPaddings = tester
          .widgetList<Padding>(
            find.ancestor(
              of: find.byIcon(Icons.my_location),
              matching: find.byType(Padding),
            ),
          )
          .map((p) => p.padding)
          .whereType<EdgeInsets>();
      expect(
        commandPaddings,
        contains(const EdgeInsets.fromLTRB(16, 16, 16, 66)),
      );

      final scalebar = tester.widget<Scalebar>(find.byType(Scalebar));
      expect(scalebar.padding, const EdgeInsets.fromLTRB(10, 10, 10, 60));
    },
  );

  testWidgets('bottomOverlayInset defaults to 0 (no extra clearance)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MapView<int>(layers: MapConfig.layers, withLocate: true),
        ),
      ),
    );
    await tester.pump();

    final commandPaddings = tester
        .widgetList<Padding>(
          find.ancestor(
            of: find.byIcon(Icons.my_location),
            matching: find.byType(Padding),
          ),
        )
        .map((p) => p.padding)
        .whereType<EdgeInsets>();
    expect(commandPaddings, contains(const EdgeInsets.all(16)));

    final scalebar = tester.widget<Scalebar>(find.byType(Scalebar));
    expect(scalebar.padding, const EdgeInsets.all(10));
  });

  testWidgets(
    'two MapViews in the same subtree (e.g. a master/detail split) do not '
    'collide on a shared MapCommand hero tag when a route is pushed',
    (tester) async {
      // Hero collision detection only runs while Navigator resolves a route
      // transition (HeroController scans the outgoing route's subtree for
      // heroes to fly) — a static pump with no navigation never exercises
      // it, so this drives a real push, matching the reported crash
      // ("[GoRouter] pushing .../brief" while a master/detail split with
      // two maps was on screen).
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: MapView<int>(
                      layers: MapConfig.layers,
                      withToggle: true,
                    ),
                  ),
                  SizedBox(
                    height: 200,
                    child: MapView<int>(
                      layers: MapConfig.layers,
                      withToggle: true,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const Scaffold(body: Text('next')),
                      ),
                    ),
                    child: const Text('push'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.layers), findsNWidgets(2));

      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('next'), findsOneWidget);
    },
  );

  testWidgets('withCross renders one fixed centre pin, not the old red X', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MapView<int>(layers: MapConfig.layers, withCross: true),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.location_on), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
