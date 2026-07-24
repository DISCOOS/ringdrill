import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/map_view.dart';

/// Regression guard for the button-size-mismatch bug `withFullscreen`
/// fixed: before this, the expand command was a caller-supplied
/// `topRightCommands` entry with no explicit `size:`, so it resolved via
/// `MapCommandSize.of(context)` (full-window `MediaQuery`) instead of the
/// local `commandSize` every *internal* command (the layer toggle
/// included) derives from `MapView`'s own `LayoutBuilder` constraints —
/// visibly mismatched on any embedding narrower than the full window.
/// Building the expand command internally means it shares the exact same
/// `commandSize` variable as the toggle, so the two can never disagree.
void main() {
  testWidgets(
    'the fullscreen command renders at the local-viewport-derived compact '
    'size, matching the layer-toggle command, even though the full window '
    'is wide enough to read as regular',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            // The full window (MediaQuery) is flutter_test's default
            // ~800px wide — comfortably "regular" by MapCommandSize.of's
            // own full-window read. Embedding MapView in a narrower
            // SizedBox is exactly the "dialog/split-pane narrower than
            // the full window" scenario the bug reproduced under.
            body: Center(
              child: SizedBox(
                width: 300,
                height: 300,
                child: MapView<int>(
                  layers: MapConfig.layers,
                  markers: const [],
                  withFullscreen: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final toggle = tester.widget<FloatingActionButton>(
        find.ancestor(
          of: find.byIcon(Icons.layers),
          matching: find.byType(FloatingActionButton),
        ),
      );
      final fullscreen = tester.widget<FloatingActionButton>(
        find.ancestor(
          of: find.byIcon(Icons.open_in_full),
          matching: find.byType(FloatingActionButton),
        ),
      );

      // Both must be the same (compact, "small") variant — the local
      // 300px viewport reads as WindowSizeClass.compact regardless of the
      // full window being wider.
      expect(toggle.mini, isTrue);
      expect(fullscreen.mini, isTrue);
      expect(
        tester.getSize(find.byWidget(fullscreen)),
        tester.getSize(find.byWidget(toggle)),
      );
      // 48, not 40: MaterialTapTargetSize.padded keeps the compact FAB's
      // hit box at the Material minimum even though its visible circle is
      // only 40dp (MapCommandSize.compact.tapTarget) — still distinct from
      // regular's 56dp, so this still pins the size class, not just
      // equality between the two commands.
      expect(tester.getSize(find.byWidget(fullscreen)).width, 48);
    },
  );

  testWidgets(
    'tapping the fullscreen command carries the embed\'s own command size '
    'into the pushed route, instead of the route recomputing a larger one '
    'from its own (usually wider) full-window constraints',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            // Same narrow-embed-in-a-wide-window shape as above: the embed
            // itself reads as compact (300px local width), but the pushed
            // fullscreen route's own Scaffold spans the full ~800px test
            // window — which would read as regular if it recomputed its
            // own command size from scratch, rendering visibly bigger
            // buttons than the embed the user just tapped "expand" from.
            body: Center(
              child: SizedBox(
                width: 300,
                height: 300,
                child: MapView<int>(
                  layers: MapConfig.layers,
                  markers: const [],
                  withFullscreen: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.open_in_full));
      await tester.pumpAndSettle();

      // Now inside the pushed fullscreen route — its own layer-toggle
      // command must still be the compact ("small") variant, matching the
      // embed it was launched from, not the regular size its own (wide)
      // constraints would otherwise produce.
      final pushedToggle = tester.widget<FloatingActionButton>(
        find.ancestor(
          of: find.byIcon(Icons.layers),
          matching: find.byType(FloatingActionButton),
        ),
      );
      expect(pushedToggle.mini, isTrue);
      expect(tester.getSize(find.byWidget(pushedToggle)).width, 48);
    },
  );
}
