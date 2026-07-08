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
}
