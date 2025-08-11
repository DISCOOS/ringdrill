import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/utils/projection.dart';

void main() {
  group('projectGlobalUtm - CRS & zone selection', () {
    test('Europe uses ETRS89 / UTM (EPSG:258xx): Bergen', () {
      final u = projectGlobalUtm(60.39, 5.32); // Bergen
      expect(u.crs, 'EPSG:25832'); // 32V exception area
      expect(u.zone, 32);
      expect(u.band, isNot('Z'));
      expect(_isPlausibleEasting(u.easting), isTrue);
      expect(_isPlausibleNorthing(u.northing), isTrue);
    });

    test('Europe uses ETRS89 / UTM (EPSG:258xx): Oslo', () {
      final u = projectGlobalUtm(59.9139, 10.7522); // Oslo
      // Oslo is in UTM zone 32 as well (10.75E)
      expect(u.crs, 'EPSG:25832');
      expect(u.zone, 32);
      expect(u.band, isNot('Z'));
      expect(_isPlausibleEasting(u.easting), isTrue);
      expect(_isPlausibleNorthing(u.northing), isTrue);
    });

    test(
      'Outside Europe uses WGS84 / UTM (EPSG:326/327xx): Sydney (south)',
      () {
        final u = projectGlobalUtm(-33.8688, 151.2093); // Sydney
        // Zone calc: ((151.2093 + 180)/6).floor()+1 = 56
        expect(u.crs, 'EPSG:32756'); // WGS84 south hemisphere
        expect(u.zone, 56);
        expect(u.band, isNot('Z'));
        expect(_isPlausibleEasting(u.easting), isTrue);
        expect(_isPlausibleNorthing(u.northing), isTrue);
      },
    );

    test(
      'Outside Europe uses WGS84 / UTM (EPSG:326/327xx): New York (north)',
      () {
        final u = projectGlobalUtm(40.7128, -74.0060); // NYC
        // Zone calc: ((-74.006 + 180)/6).floor()+1 = 18
        expect(u.crs, 'EPSG:32618'); // WGS84 north hemisphere
        expect(u.zone, 18);
        expect(u.band, isNot('Z'));
        expect(_isPlausibleEasting(u.easting), isTrue);
        expect(_isPlausibleNorthing(u.northing), isTrue);
      },
    );
  });

  group('Norway 32V and Svalbard exceptions', () {
    test('Norway 32V extension triggers (56–64N, 3–12E)', () {
      final u = projectGlobalUtm(60.0, 5.0); // west coast
      expect(u.zone, 32);
      expect(u.crs, startsWith('EPSG:258')); // Europe -> ETRS89
    });

    test('Adjacent longitude outside 32V falls back to normal zone (33)', () {
      final u = projectGlobalUtm(60.0, 13.0);
      expect(u.zone, 33);
      expect(u.crs, 'EPSG:25833');
    });

    test('Svalbard 31X band region (0–9E)', () {
      final u = projectGlobalUtm(78.0, 8.0);
      expect(u.zone, 31);
      expect(u.band, anyOf('W', 'X')); // 72–84N => X; sharing tolerant check
      expect(u.crs, 'EPSG:25831');
    });

    test('Svalbard 33X band region (9–21E): Longyearbyen', () {
      final u = projectGlobalUtm(78.22, 15.65); // Longyearbyen
      expect(u.zone, 33);
      expect(u.crs, 'EPSG:25833');
      expect(u.band, anyOf('W', 'X')); // typically 'X'
    });

    test('Svalbard 35X band region (21–33E)', () {
      final u = projectGlobalUtm(78.0, 22.0);
      expect(u.zone, 35);
      expect(u.crs, 'EPSG:25835');
    });

    test('Svalbard 37X band region (33–42E)', () {
      final u = projectGlobalUtm(78.0, 34.0);
      expect(u.zone, 37);
      expect(u.crs, 'EPSG:25837');
    });
  });

  group('UPS handling (polar regions)', () {
    test('North polar (> 84N) returns UPS north as Utm (zone=0, band=Z)', () {
      final u = projectGlobalUtm(85.0, 0.0);
      expect(u.crs, 'EPSG:5041'); // UPS North
      expect(u.zone, 0);
      expect(u.band, 'Z');
      expect(_isPlausibleUpsEasting(u.easting), isTrue);
      expect(_isPlausibleUpsNorthing(u.northing), isTrue);
    });

    test('South polar (< -80S) returns UPS south as Utm (zone=0, band=Z)', () {
      final u = projectGlobalUtm(-85.0, 0.0);
      expect(u.crs, 'EPSG:5042'); // UPS South
      expect(u.zone, 0);
      expect(u.band, 'Z');
      expect(_isPlausibleUpsEasting(u.easting), isTrue);
      expect(_isPlausibleUpsNorthing(u.northing), isTrue);
    });
  });

  group('LatLng extension consistency', () {
    test('LatLng.utm() matches projectGlobalUtm result', () {
      final lat = 60.39, lon = 5.32; // Bergen
      final fromFn = projectGlobalUtm(lat, lon);
      final fromExt = LatLng(lat, lon).utm();
      expect(fromExt.crs, fromFn.crs);
      expect(fromExt.zone, fromFn.zone);
      expect(fromExt.band, fromFn.band);
      expect(fromExt.easting, closeTo(fromFn.easting, 0.001));
      expect(fromExt.northing, closeTo(fromFn.northing, 0.001));
    });
  });
}

/// --- helpers for plausibility checks ---

bool _isPlausibleEasting(double e) => e > 10000 && e < 1_000_000;
bool _isPlausibleNorthing(double n) => n >= 0 && n <= 10_000_000;

/// UPS has a large false origin; keep checks loose but sane.
bool _isPlausibleUpsEasting(double e) => e > 0 && e < 4_000_000;
bool _isPlausibleUpsNorthing(double n) => n > 0 && n < 4_000_000;
