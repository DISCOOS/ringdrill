import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/geocoding_service.dart';
import 'package:ringdrill/views/map_view.dart';

/// docs/prompts/map-search-coordinate-parse-reuse.md — the map search field
/// resolves coordinate input through the shared `parseCoordinateInput`
/// (utils/variable_values.dart), the same parser behind the DESIGN-008
/// location variable field. Covers the decimal lat,lng regression, the bug
/// being fixed (a UTM string in the app's own `…E …N` display format), the
/// bare-number UTM form, and the fall-through to the geocoder on input that
/// reads as neither.
///
/// No test touches the network: every case injects a [_FakeGeocodingService].

class _FakeGeocodingService implements GeocodingService {
  int searchCount = 0;

  @override
  Future<List<GeocodingHit>> search(String query, {LatLng? near}) async {
    searchCount++;
    return const [];
  }

  @override
  Future<String> reverse(LatLng point) async => 'Fake Reverse Place';
}

/// `32V 580414 6552008` and `59.09978, 10.403795` are the same point in the
/// two notations `parseCoordinateInput` accepts.
const _utmAsLatLng = LatLng(59.09978, 10.403795);

Future<({MapController map, _FakeGeocodingService geocoder})> _pumpMap(
  WidgetTester tester,
) async {
  final map = MapController();
  final geocoder = _FakeGeocodingService();
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MapView<int>(
          layers: MapConfig.layers,
          controller: map,
          withSearch: true,
          geocodingService: geocoder,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (map: map, geocoder: geocoder);
}

/// Types [input] into the search field and waits out the 50 ms throttle and
/// the async search.
Future<void> _search(WidgetTester tester, String input) async {
  await tester.enterText(find.byType(TextField), input);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

void _expectCenteredOn(MapController map, LatLng expected) {
  expect(map.camera.center.latitude, closeTo(expected.latitude, 0.0001));
  expect(map.camera.center.longitude, closeTo(expected.longitude, 0.0001));
}

void main() {
  testWidgets('a decimal lat,lng recenters the map on that point', (
    tester,
  ) async {
    final h = await _pumpMap(tester);

    await _search(tester, '59.7445, 10.2045');

    _expectCenteredOn(h.map, const LatLng(59.7445, 10.2045));
    expect(
      h.geocoder.searchCount,
      0,
      reason: 'a resolved coordinate must not reach the geocoder',
    );
  });

  testWidgets(
    'a UTM string in the app\'s own E/N display format recenters the map '
    'on the same point as the equivalent decimal pair',
    (tester) async {
      final h = await _pumpMap(tester);

      await _search(tester, '32V 0580414E 6552008N');

      _expectCenteredOn(h.map, _utmAsLatLng);
      expect(h.geocoder.searchCount, 0);
    },
  );

  testWidgets('a bare-number UTM string also resolves', (tester) async {
    final h = await _pumpMap(tester);

    await _search(tester, '32V 580414 6552008');

    _expectCenteredOn(h.map, _utmAsLatLng);
    expect(h.geocoder.searchCount, 0);
  });

  testWidgets(
    'out-of-range and garbage input does not move the map and falls '
    'through to the geocoder',
    (tester) async {
      final h = await _pumpMap(tester);

      await _search(tester, '123,456');
      _expectCenteredOn(h.map, MapConfig.initialCenter);
      expect(
        h.geocoder.searchCount,
        1,
        reason: 'an out-of-range pair must fall through to the geocoder',
      );

      await _search(tester, 'not a coordinate');
      _expectCenteredOn(h.map, MapConfig.initialCenter);
      expect(h.geocoder.searchCount, 2);
    },
  );
}
