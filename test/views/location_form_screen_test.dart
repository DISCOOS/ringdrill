import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/views/location_form_screen.dart';

/// DESIGN-009 follow-up 3b — `LocationFormScreen` in isolation: the inline
/// map-pick affordance, the category grid, and its show-more/less toggle.
/// Hosted directly (no `StationFormScreen`/`LocationsSection` around it),
/// mirroring `position_form_field_test.dart`'s own "this is about the
/// widget's own wiring, not layout" rationale.

class _Captured {
  Location? value;
}

Future<void> _open(
  WidgetTester tester,
  _Captured captured, {
  Location? initial,
  Set<String> existingSlugs = const {},
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async {
            captured.value = await Navigator.push<Location>(
              ctx,
              MaterialPageRoute(
                builder: (_) => LocationFormScreen(
                  existingSlugs: existingSlugs,
                  initial: initial,
                ),
              ),
            );
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets(
    'setting position inline via the map picker persists on save, '
    'without leaving the form',
    (tester) async {
      final captured = _Captured();
      await _open(tester, captured);

      await tester.enterText(
        find.widgetWithText(TextFormField, l.locationsSectionLabelLabel),
        'LKP',
      );

      // Open the real map picker (real FlutterMap, real pan gesture, real
      // "confirm" tap) -- same drive as position_form_field_test.dart.
      // Scroll the icon into view first: unlike that test's minimal host,
      // this form has fields above the position section that push it
      // below the fold on the default test surface.
      await tester.ensureVisible(find.byIcon(Icons.map));
      await tester.tap(find.byIcon(Icons.map));
      await tester.pumpAndSettle();
      expect(find.byType(FlutterMap), findsOneWidget);

      await tester.drag(find.byType(FlutterMap), const Offset(-200, -150));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      // The picker returns to the Location form itself -- not out of the
      // whole add flow -- so the author can keep filling other fields.
      expect(find.widgetWithText(TextFormField, 'LKP'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.position, isNotNull);
    },
  );

  testWidgets('the category grid sets kind', (tester) async {
    final captured = _Captured();
    await _open(tester, captured);

    await tester.enterText(
      find.widgetWithText(TextFormField, l.locationsSectionLabelLabel),
      'Bosted',
    );
    // LocationKind.home is one of the default-visible (collapsed) cards.
    await tester.tap(find.text(l.locationKindHomeLabel));
    await tester.tap(find.widgetWithText(FilledButton, l.save));
    await tester.pumpAndSettle();

    expect(captured.value, isNotNull);
    expect(captured.value!.kind, LocationKind.home);
  });

  testWidgets(
    'the show-more/less toggle expands to all kinds and collapses back',
    (tester) async {
      await _open(tester, _Captured());

      // LocationKind.obstacle is not one of the default-collapsed cards.
      expect(find.text(l.locationKindObstacleLabel), findsNothing);

      final showAll = find.text(
        l.locationsSectionShowAllKinds(LocationKind.values.length),
      );
      await tester.ensureVisible(showAll);
      await tester.tap(showAll);
      await tester.pumpAndSettle();
      expect(find.text(l.locationKindObstacleLabel), findsOneWidget);

      final showFewer = find.text(l.locationsSectionShowFewerKinds);
      await tester.ensureVisible(showFewer);
      await tester.tap(showFewer);
      await tester.pumpAndSettle();
      expect(find.text(l.locationKindObstacleLabel), findsNothing);
    },
  );
}
