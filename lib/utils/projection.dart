import 'package:latlong2/latlong.dart';
import 'package:proj4dart/proj4dart.dart' as proj;

/// Projection utilities for converting geographic coordinates (latitude/longitude)
/// to projected coordinates in the Universal Transverse Mercator (UTM) or
/// Universal Polar Stereographic (UPS) systems.
///
/// This implementation:
///  - Handles **all valid lat/lon coordinates globally**.
///  - Uses **ETRS89 / UTM (EPSG:258xx)** for locations in Europe
///    (aligned with official mapping standards in Norway and EU).
///  - Uses **WGS84 / UTM (EPSG:326xx for northern hemisphere,
///    EPSG:327xx for southern hemisphere)** outside Europe.
///  - Applies **special UTM zone rules** for:
///      - Norway Zone 32V extension (3°E–12°E, 56°N–64°N)
///      - Svalbard zones 31X, 33X, 35X, and 37X (72°N–84°N)
///  - Uses **UPS** for polar areas beyond UTM coverage:
///      - EPSG:5041 (North UPS) for > 84°N
///      - EPSG:5042 (South UPS) for < −80°S
///  - Always returns a single [Utm] type:
///      - `zone` 1–60 for UTM
///      - `zone` 0 and `band` 'Z' for UPS (convention)
///      - `crs` holds the actual EPSG code used
///      - `isUps` getter to check for UPS
///
/// Coordinate transformation is performed using the [proj4dart] package.
///
/// Example:
/// ```dart
/// final bergen = projectGlobalUtm(60.39, 5.32);
/// print('${bergen.crs} zone=${bergen.zone}${bergen.band} E=${bergen.easting} N=${bergen.northing}');
///
/// final longyearbyen = projectGlobalUtm(78.22, 15.65);
/// print('${longyearbyen.crs} zone=${longyearbyen.zone}${longyearbyen.band}');
/// ```
///
/// References:
///  - ETRS89: https://epsg.io/25832
///  - WGS84 / UTM: https://epsg.io/32632
///  - UPS: https://epsg.io/5041
class Utm {
  final int zone; // 1–60 for UTM, 0 for UPS (convention)
  final String band; // C–X for UTM, 'Z' for UPS (convention)
  final double easting; // meters
  final double northing; // meters
  final String crs; // EPSG code used for projection
  final bool isETRS89; // CRS is ETRS89, UPS or WGS84 otherwise

  String toRefString() {
    if (isETRS89) return 'ETRS89';
    if (isUPS) return 'UPS';
    return 'WGS84';
  }

  const Utm({
    required this.crs,
    required this.zone,
    required this.band,
    required this.easting,
    required this.northing,
    required this.isETRS89,
  });

  bool get isUPS => zone == 0;
  bool get isWGS84 => !(isUPS || isETRS89);
}

Utm projectGlobalUtm(double lat, double lon, {bool useETRS89 = false}) {
  if (_isNorthPolar(lat)) return _upsAsUtm(lat, lon, north: true);
  if (_isSouthPolar(lat)) return _upsAsUtm(lat, lon, north: false);

  final zone = _utmZoneWithNorwaySvalbard(lat, lon);
  final band = _utmBandLetter(lat);

  final bool inEurope = _isInEtrsEurope(lat, lon);
  final bool north = lat >= 0;
  final isETRS89 = useETRS89 && inEurope;
  final crs = isETRS89
      ? 'EPSG:258${zone.toString().padLeft(2, "0")}'
      : 'EPSG:${north ? 326 : 327}${zone.toString().padLeft(2, "0")}';

  final src = proj.Projection.get('EPSG:4326')!;
  final dst =
      proj.Projection.get(crs) ??
      proj.Projection.add(crs, _proj4For(crs, zone, inEurope, north));

  final p = proj.Point(x: _normLon(lon), y: lat);
  final out = src.transform(dst, p);

  return Utm(
    crs: crs,
    zone: zone,
    band: band,
    easting: out.x,
    northing: out.y,
    isETRS89: isETRS89,
  );
}

double _normLon(double lon) => ((lon + 180) % 360) - 180;

int _utmZoneWithNorwaySvalbard(double lat, double lonRaw) {
  final lon = _normLon(lonRaw);
  int zone = ((lon + 180) / 6).floor() + 1;

  if (lat >= 56.0 && lat < 64.0 && lon >= 3.0 && lon < 12.0) {
    zone = 32;
  }
  if (lat >= 72.0 && lat < 84.0) {
    if (lon >= 0.0 && lon < 9.0) {
      zone = 31;
    } else if (lon >= 9.0 && lon < 21.0) {
      zone = 33;
    } else if (lon >= 21.0 && lon < 33.0) {
      zone = 35;
    } else if (lon >= 33.0 && lon < 42.0) {
      zone = 37;
    }
  }
  return zone;
}

String _utmBandLetter(double lat) {
  if (lat < -80 || lat > 84) return 'Z';
  const letters = 'CDEFGHJKLMNPQRSTUVWX';
  if (lat >= 72) return 'X';
  final i = ((lat + 80) / 8).floor();
  return letters[i];
}

bool _isInEtrsEurope(double lat, double lonRaw) {
  final lon = _normLon(lonRaw);
  const minLat = 34.0, maxLat = 84.0;
  const minLon = -25.0, maxLon = 45.0;
  return (lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon);
}

bool _isNorthPolar(double lat) => lat > 84.0;
bool _isSouthPolar(double lat) => lat < -80.0;

String _proj4For(String crs, int zone, bool isEurope, bool north) {
  if (crs.startsWith('EPSG:258')) {
    return '+proj=utm +zone=$zone +ellps=GRS80 +units=m +no_defs';
  }
  if (crs.startsWith('EPSG:326')) {
    // WGS84 / UTM north
    return '+proj=utm +zone=$zone +datum=WGS84 +units=m +no_defs';
  }
  if (crs.startsWith('EPSG:327')) {
    // WGS84 / UTM south  <-- needs +south
    return '+proj=utm +zone=$zone +datum=WGS84 +units=m +south +no_defs';
  }
  if (crs == 'EPSG:5041') {
    return '+proj=stere +lat_0=90 +lat_ts=90 +lon_0=0 +k=0.994 '
        '+x_0=2000000 +y_0=2000000 +datum=WGS84 +units=m +no_defs';
  }
  if (crs == 'EPSG:5042') {
    return '+proj=stere +lat_0=-90 +lat_ts=-90 +lon_0=0 +k=0.994 '
        '+x_0=2000000 +y_0=2000000 +datum=WGS84 +units=m +no_defs';
  }
  throw ArgumentError('Unsupported CRS: $crs');
}

Utm _upsAsUtm(double lat, double lonRaw, {required bool north}) {
  final lon = _normLon(lonRaw);
  final crs = north ? 'EPSG:5041' : 'EPSG:5042';

  final src = proj.Projection.get('EPSG:4326')!;
  final dst =
      proj.Projection.get(crs) ??
      proj.Projection.add(crs, _proj4For(crs, 0, false, north));

  final p = proj.Point(x: lon, y: lat);
  final out = src.transform(dst, p);

  return Utm(
    crs: crs,
    zone: 0,
    band: 'Z',
    easting: out.x,
    northing: out.y,
    isETRS89: false,
  );
}

extension StringProjection on String {
  /// Parses this string as UTM.
  ///
  /// Examples accepted:
  ///  - "32V 500000 6640000"
  ///  - "32 V 500000 6640000"
  ///  - "32V,500000,6640000"
  ///  - "ZONE 32N 450123.4 4645123.9"
  ///
  /// Behavior:
  /// - If [useETRS89] is **false** (default), returns a UTM with CRS = EPSG:326/327xx
  ///   based on the band/hemisphere (no Europe detection), which is fast and
  ///   sufficient when you only need a numeric UTM container.
  /// - If [useETRS89] is **true**, we first invert to WGS84 (lat/lon) using
  ///   `proj4dart`, then call `projectGlobalUtm(lat, lon)` so Europe maps to
  ///   **ETRS89/UTM (EPSG:258xx)** and the rest of the world to **WGS84/UTM
  ///   (EPSG:326/327xx)**. This costs one extra transform, but gives you the
  ///   same CRS policy as the rest of the app.
  Utm? toUtm({bool assumeNorthernHemisphere = true, bool useETRS89 = false}) {
    final cleaned = trim().toUpperCase();
    final re = RegExp(
      r'^(?:ZONE\s*)?'
      r'(?<!\d)(\d{1,2})(?!\d)\s*' // zone 1–60
      r'([C-HJ-NP-X])?\s*[, ]+\s*' // optional band
      r'([0-9]+(?:\.[0-9]+)?)\s*[, ]+\s*' // easting
      r'([0-9]+(?:\.[0-9]+)?)\s*$', // northing
    );
    final m = re.firstMatch(cleaned);
    if (m == null) return null;

    final zone = int.tryParse(m.group(1)!);
    if (zone == null || zone < 1 || zone > 60) return null;

    final band = m.group(2); // may be null
    final easting = double.tryParse(m.group(3)!);
    final northing = double.tryParse(m.group(4)!);
    if (easting == null || northing == null) return null;

    final isSouthern = band != null
        ? band.codeUnitAt(0) < 'N'.codeUnitAt(0)
        : !assumeNorthernHemisphere;

    // Fast path: return a generic WGS84/UTM container (EPSG:326/327xx)
    final wgs84Crs =
        'EPSG:${isSouthern ? 327 : 326}${zone.toString().padLeft(2, '0')}';
    if (!useETRS89) {
      return Utm(
        crs: wgs84Crs,
        zone: zone,
        band: band ?? (isSouthern ? 'M' : 'N'),
        easting: easting,
        northing: northing,
        isETRS89: false,
      );
    }

    // Full path: invert -> LatLng -> global reproject (ETRS89-in-Europe policy)
    final src = _projForUtm(wgs84Crs);
    final dst = proj.Projection.get('EPSG:4326')!; // WGS84 lon/lat
    final inv = src.transform(dst, proj.Point(x: easting, y: northing));
    final lat = inv.y, lon = inv.x;

    return projectGlobalUtm(lat, lon);
  }

  /// Convenience: parse UTM text and convert to [LatLng] (WGS84).
  LatLng? toLatLngFromUtm({bool assumeNorthernHemisphere = true}) {
    final u = toUtm(
      assumeNorthernHemisphere: assumeNorthernHemisphere,
      useETRS89: false,
    );
    if (u == null) return null;
    final src = _projForUtm(u.crs);
    final dst = proj.Projection.get('EPSG:4326')!;
    final out = src.transform(dst, proj.Point(x: u.easting, y: u.northing));
    return LatLng(out.y, out.x);
  }

  // ---- tiny PROJ helpers ----

  proj.Projection _projForUtm(String crs) {
    final cached = proj.Projection.get(crs);
    if (cached != null) return cached;

    if (crs.startsWith('EPSG:258')) {
      final zone = int.parse(crs.substring(8, 10));
      return proj.Projection.add(
        crs,
        '+proj=utm +zone=$zone +ellps=GRS80 +units=m +no_defs',
      );
    }
    if (crs.startsWith('EPSG:326')) {
      final zone = int.parse(crs.substring(8, 10));
      return proj.Projection.add(
        crs,
        '+proj=utm +zone=$zone +datum=WGS84 +units=m +no_defs',
      );
    }
    if (crs.startsWith('EPSG:327')) {
      final zone = int.parse(crs.substring(8, 10));
      // south hemisphere needs +south
      return proj.Projection.add(
        crs,
        '+proj=utm +zone=$zone +datum=WGS84 +south +units=m +no_defs',
      );
    }
    throw ArgumentError('Unsupported UTM CRS: $crs');
  }
}

extension LatLngX on LatLng {
  /// Converts this [LatLng] (WGS84, EPSG:4326) to a projected UTM/UPS coordinate
  /// using the global strategy in `projection.dart`.
  ///
  /// Behavior:
  /// - Selects **ETRS89 / UTM (EPSG:258xx)** for locations in Europe if
  ///   [useETRS89] is true (default is [false]), otherwise **WGS84** is used.
  /// - Selects **WGS84 / UTM (EPSG:326xx for N, 327xx for S)** outside Europe.
  /// - Applies UTM special cases:
  ///   - **Norway 32V extension** (3°E–12°E, 56°N–64°N)
  ///   - **Svalbard zones** 31X/33X/35X/37X (72°N–84°N)
  /// - Uses **UPS** beyond UTM coverage:
  ///   - EPSG:5041 (>84°N) or EPSG:5042 (<−80°S)
  ///   - Still returns a unified [Utm]; for UPS we use `zone = 0` and `band = 'Z'`
  ///     by convention. Check `result.isUps` to detect polar stereographic results.
  ///
  /// Returns:
  /// - A [projx.Utm] with `crs`, `zone`, `band`, `easting`, `northing`.
  Utm utm({bool useETRS89 = false}) {
    return projectGlobalUtm(latitude, longitude, useETRS89: useETRS89);
  }
}
