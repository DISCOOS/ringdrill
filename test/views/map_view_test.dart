import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/map_settings.dart';
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

  group('short-viewport command layout', () {
    // A landscape phone: the top-right (layers/fullscreen) and bottom-right
    // (locate/zoom/centre) columns each grow toward the vertical centre and
    // collided there (reported: commands "too close"). On a short viewport
    // they merge into one top-anchored column so they never overlap.
    Future<void> pumpMap(WidgetTester tester, {required Size size}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MapView<int>(
              layers: MapConfig.layers,
              withToggle: true,
              withFullscreen: true,
              withCenter: true,
              withLocate: true,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets(
      'on a short landscape viewport all commands stack in one top-anchored '
      'column (bottom-group centre is not glued to the map bottom, and sits '
      'below the top-group fullscreen with no overlap)',
      (tester) async {
        await pumpMap(tester, size: const Size(800, 360));

        final map = tester.getRect(find.byType(FlutterMap));
        final fullscreen = tester.getRect(find.byIcon(Icons.open_in_full));
        final center = tester.getRect(
          find.byIcon(Icons.center_focus_strong_rounded),
        );

        // Merged: the centre command follows (below) the fullscreen command
        // rather than being anchored to the opposite (bottom) edge.
        expect(center.top, greaterThanOrEqualTo(fullscreen.bottom - 0.5));
        expect(center.bottom, lessThan(map.top + map.height * 0.7));
      },
    );

    testWidgets(
      'a full command set on a very short map wraps into a second column '
      'instead of overflowing (or clipping) — every command stays visible',
      (tester) async {
        MapSettings.instance.showZoomControls.value = true;
        addTearDown(() => MapSettings.instance.showZoomControls.value = false);
        // 260px tall leaves only ~228px of content height for the column,
        // while layers + fullscreen + the zoom pair + centre + locate need
        // ~280px — the case that overflowed by ~92px as a single column.
        tester.view.physicalSize = const Size(800, 260);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MapView<int>(
                layers: MapConfig.layers,
                withToggle: true,
                withFullscreen: true,
                withCenter: true,
                withZoom: true,
                withLocate: true,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        // Every command is still built and laid out (none dropped or
        // clipped off the bottom).
        final icons = [
          Icons.layers,
          Icons.open_in_full,
          Icons.my_location,
          Icons.add,
          Icons.remove,
          Icons.center_focus_strong_rounded,
        ];
        for (final icon in icons) {
          expect(find.byIcon(icon), findsOneWidget, reason: '$icon missing');
        }

        // Proof the stack wrapped: the six commands occupy at least two
        // distinct horizontal columns (the primary at the right edge and a
        // second grown to its left) rather than a single clipped column.
        final columnXs = icons
            .map((i) => tester.getRect(find.byIcon(i)).left.roundToDouble())
            .toSet();
        expect(columnXs.length, greaterThanOrEqualTo(2));

        // And all commands sit within the map's vertical bounds — nothing
        // pushed past the bottom edge.
        final map = tester.getRect(find.byType(FlutterMap));
        for (final icon in icons) {
          expect(tester.getRect(find.byIcon(icon)).bottom, lessThan(map.bottom));
        }
      },
    );

    testWidgets(
      'on a tall viewport the conventional split is kept — centre stays '
      'anchored at the bottom-right, well below the top-right layers command',
      (tester) async {
        await pumpMap(tester, size: const Size(800, 900));

        final map = tester.getRect(find.byType(FlutterMap));
        final layers = tester.getRect(find.byIcon(Icons.layers));
        final center = tester.getRect(
          find.byIcon(Icons.center_focus_strong_rounded),
        );

        // Split: layers hugs the top, centre hugs the bottom.
        expect(layers.top, lessThan(map.top + 120));
        expect(center.bottom, greaterThan(map.bottom - 120));
      },
    );
  });

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
