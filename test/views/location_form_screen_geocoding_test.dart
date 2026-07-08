import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/services/geocoding_service.dart';
import 'package:ringdrill/views/location_form_screen.dart';
import 'package:ringdrill/views/map_view.dart';

/// DESIGN-009 follow-up 3c — geocoding in `LocationFormScreen`: forward
/// (place → position via suggestions), reverse (position → place on an
/// empty field), non-clobber (position set with non-empty place shows
/// "Update from map" instead of overwriting), best-effort (throwing geocoder
/// leaves the form usable and never blocks save), and a small regression
/// check that `MapView` still routes search through the shared
/// `GeocodingService`.
///
/// No test touches the network: every case injects a [_FakeGeocodingService].

// ---------------------------------------------------------------------------
// Fake geocoder
// ---------------------------------------------------------------------------

class _FakeGeocodingService implements GeocodingService {
  _FakeGeocodingService({
    this.searchResults = const [],
    this.reverseLabel = 'Fake Reverse Place',
    this.shouldThrow = false,
  });

  final List<GeocodingHit> searchResults;
  final String reverseLabel;
  final bool shouldThrow;

  int searchCount = 0;
  int reverseCount = 0;

  @override
  Future<List<GeocodingHit>> search(String query, {LatLng? near}) async {
    searchCount++;
    if (shouldThrow) throw Exception('offline');
    return searchResults;
  }

  @override
  Future<String> reverse(LatLng point) async {
    reverseCount++;
    if (shouldThrow) throw Exception('offline');
    return reverseLabel;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _Captured {
  Location? value;
}

Future<void> _open(
  WidgetTester tester,
  _Captured captured, {
  Location? initial,
  Set<String> existingSlugs = const {},
  required _FakeGeocodingService geocoder,
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
                  geocodingService: geocoder,
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const placeSearchDebounce = Duration(milliseconds: 400);

  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  // -------------------------------------------------------------------------
  // Forward geocoding: typing a query shows suggestions; picking one sets
  // both place (canonical label) and position.
  // -------------------------------------------------------------------------

  testWidgets(
    'forward: typing shows suggestions; picking one sets place and position',
    (tester) async {
      final hit = GeocodingHit('Oslo Sentrum', LatLng(59.9139, 10.7522));
      final geocoder = _FakeGeocodingService(searchResults: [hit]);
      final captured = _Captured();

      await _open(tester, captured, geocoder: geocoder);

      // Give the form a label so save is valid.
      await tester.enterText(
        find.widgetWithText(TextFormField, l.locationsSectionLabelLabel),
        'Meeting point',
      );

      // Find the place field and type into it.
      final placeField = find.widgetWithText(
        TextFormField,
        l.locationsSectionPlaceLabel,
      );
      await tester.ensureVisible(placeField);
      await tester.enterText(placeField, 'oslo');

      // Wait out the debounce and let the async search complete.
      await tester.pump(placeSearchDebounce);
      await tester.pumpAndSettle();

      // The suggestion from the fake should be visible below the field.
      expect(find.text(hit.label), findsOneWidget);

      // Scroll the suggestion into the hittable viewport, then tap it.
      await tester.ensureVisible(find.text(hit.label));
      await tester.tap(find.text(hit.label));
      await tester.pumpAndSettle();

      // The field text updates to the canonical label; suggestions go away.
      expect(
        tester.widget<TextField>(
          find.descendant(
            of: placeField,
            matching: find.byType(TextField),
          ),
        ).controller!.text,
        hit.label,
      );
      expect(find.text(hit.label), findsOneWidget);

      // Save and verify both place and position made it through.
      await tester.tap(find.widgetWithText(FilledButton, l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.place, hit.label);
      expect(captured.value!.position, isNotNull);
      expect(captured.value!.position!.latitude, closeTo(hit.position.latitude, 0.001));
      expect(captured.value!.position!.longitude, closeTo(hit.position.longitude, 0.001));
    },
  );

  // -------------------------------------------------------------------------
  // Reverse geocoding: setting position with an empty place fills place.
  // -------------------------------------------------------------------------

  testWidgets(
    'reverse: empty place is filled when position is set via map picker',
    (tester) async {
      final geocoder = _FakeGeocodingService(reverseLabel: 'Reverse Street 1');
      final captured = _Captured();

      await _open(tester, captured, geocoder: geocoder);

      await tester.enterText(
        find.widgetWithText(TextFormField, l.locationsSectionLabelLabel),
        'Drop pin',
      );

      // Open the map picker, drag, confirm — same pattern as the existing test.
      await tester.ensureVisible(find.byIcon(Icons.map));
      await tester.tap(find.byIcon(Icons.map));
      await tester.pumpAndSettle();
      expect(find.byType(FlutterMap), findsOneWidget);

      await tester.drag(find.byType(FlutterMap), const Offset(-200, -150));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byIcon(Icons.check));

      // pumpAndSettle lets the async reverse geocode complete before we check.
      await tester.pumpAndSettle();

      // The reverse geocoder should have been called exactly once.
      expect(geocoder.reverseCount, 1);

      // The place field should now hold the reverse result.
      final placeField = find.widgetWithText(
        TextFormField,
        l.locationsSectionPlaceLabel,
      );
      expect(
        tester.widget<TextField>(
          find.descendant(of: placeField, matching: find.byType(TextField)),
        ).controller!.text,
        geocoder.reverseLabel,
      );
    },
  );

  // -------------------------------------------------------------------------
  // Non-clobber: a non-empty place is never auto-overwritten; the explicit
  // "Update from map" action overwrites it.
  // -------------------------------------------------------------------------

  testWidgets(
    'reverse: non-empty place is not auto-overwritten on position change; '
    '"Update from map" does overwrite',
    (tester) async {
      final geocoder = _FakeGeocodingService(reverseLabel: 'New Reverse Place');
      final captured = _Captured();

      await _open(tester, captured, geocoder: geocoder);

      // Pre-fill the place field so it is non-empty before picking a position.
      final placeField = find.widgetWithText(
        TextFormField,
        l.locationsSectionPlaceLabel,
      );
      await tester.ensureVisible(placeField);
      await tester.enterText(placeField, 'My typed place');

      await tester.enterText(
        find.widgetWithText(TextFormField, l.locationsSectionLabelLabel),
        'LKP',
      );

      // Let the debounce fire and the (empty) search complete so the form
      // is stable before we navigate to the map picker.
      await tester.pump(placeSearchDebounce);
      await tester.pumpAndSettle();

      // Set a position via the map picker.
      await tester.ensureVisible(find.byIcon(Icons.map));
      await tester.tap(find.byIcon(Icons.map));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(FlutterMap), const Offset(100, 50));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      // Place must still be the author's typed value — never auto-overwritten.
      expect(
        tester.widget<TextField>(
          find.descendant(of: placeField, matching: find.byType(TextField)),
        ).controller!.text,
        'My typed place',
      );

      // The explicit "Update from map" button should be visible.
      final updateBtn = find.text(l.locationsSectionUpdatePlaceFromMapAction);
      await tester.ensureVisible(updateBtn);
      expect(updateBtn, findsOneWidget);

      // Tapping it triggers a reverse geocode and replaces the place text.
      await tester.tap(updateBtn);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(
          find.descendant(of: placeField, matching: find.byType(TextField)),
        ).controller!.text,
        geocoder.reverseLabel,
      );
    },
  );

  // -------------------------------------------------------------------------
  // Best-effort: a throwing geocoder never crashes the form or blocks save.
  // -------------------------------------------------------------------------

  testWidgets(
    'best-effort: a throwing geocoder does not crash the form or block save',
    (tester) async {
      final geocoder = _FakeGeocodingService(shouldThrow: true);
      final captured = _Captured();

      await _open(tester, captured, geocoder: geocoder);

      await tester.enterText(
        find.widgetWithText(TextFormField, l.locationsSectionLabelLabel),
        'Rescue point',
      );

      // Type in the place field — the search will throw but must not crash.
      final placeField = find.widgetWithText(
        TextFormField,
        l.locationsSectionPlaceLabel,
      );
      await tester.ensureVisible(placeField);
      await tester.enterText(placeField, 'anywhere');
      await tester.pump(placeSearchDebounce);
      await tester.pumpAndSettle();

      // No crash, no error surfaced in the form (no error widget visible).
      expect(find.byType(LocationFormScreen), findsOneWidget);

      // Set a position — the reverse geocode will throw but must not crash.
      await tester.ensureVisible(find.byIcon(Icons.map));
      await tester.tap(find.byIcon(Icons.map));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(FlutterMap), const Offset(50, 50));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      // Form is still alive and save must succeed.
      await tester.tap(find.widgetWithText(FilledButton, l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.label, 'Rescue point');
    },
  );

  // -------------------------------------------------------------------------
  // Map regression: MapView routes search through the injected GeocodingService.
  // -------------------------------------------------------------------------

  testWidgets(
    'MapView uses the injected geocodingService for search (regression)',
    (tester) async {
      final geocoder = _FakeGeocodingService();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MapView<int>(
              layers: MapConfig.layers,
              withSearch: true,
              geocodingService: geocoder,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Type a non-coordinate, non-UTM query to drive the geocoder branch.
      await tester.enterText(find.byType(TextField), 'oslo');
      // 50 ms throttle + buffer to fire _searchLocationWithThrottle.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // The search must have gone through the injected fake, not a new
      // NominatimGeocodingService instance.
      expect(geocoder.searchCount, greaterThan(0),
          reason: 'MapView must use the injected geocodingService');
    },
  );
}
