import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/utils/variable_values.dart';

/// DESIGN-008 follow-up 11 — typed variable values: canonicalization and
/// validation per type, the canonical location string encoding, coordinate
/// input parsing (decimal lat,lng and UTM through the same DESIGN-009
/// parse), override application, and canonical → formatted display.

const _nb = VariableFormat(localeName: 'nb', hourUnit: 't');
const _en = VariableFormat(localeName: 'en', hourUnit: 'h');

void main() {
  setUpAll(() async {
    // DateFormat needs the locale's date symbols in a bare test context;
    // in the app flutter_localizations loads them.
    await initializeDateFormatting('nb');
    await initializeDateFormatting('en');
  });

  group('canonicalizeVariableValue', () {
    test('the empty string is valid for every type and stays empty', () {
      for (final type in VariableType.values) {
        expect(canonicalizeVariableValue(type, ''), '');
        expect(canonicalizeVariableValue(type, '  '), '');
        expect(isVariableValueValid(type, ''), isTrue);
      }
    });

    test('string passes through trimmed', () {
      expect(
        canonicalizeVariableValue(VariableType.string, ' Kanal 6 '),
        'Kanal 6',
      );
    });

    test('number accepts integers, decimals and a decimal comma', () {
      expect(canonicalizeVariableValue(VariableType.number, '2026'), '2026');
      expect(canonicalizeVariableValue(VariableType.number, '3.14'), '3.14');
      expect(canonicalizeVariableValue(VariableType.number, '3,14'), '3.14');
      expect(canonicalizeVariableValue(VariableType.number, '-7'), '-7');
    });

    test('a non-numeric number is invalid', () {
      expect(canonicalizeVariableValue(VariableType.number, 'Kanal 6'), isNull);
      expect(isVariableValueValid(VariableType.number, 'Kanal 6'), isFalse);
    });

    test('time normalizes to zero-padded 24-hour HH:MM', () {
      expect(canonicalizeVariableValue(VariableType.time, '9:05'), '09:05');
      expect(canonicalizeVariableValue(VariableType.time, '12.30'), '12:30');
      expect(canonicalizeVariableValue(VariableType.time, '23:59'), '23:59');
    });

    test('a malformed time is invalid', () {
      expect(canonicalizeVariableValue(VariableType.time, '24:00'), isNull);
      expect(canonicalizeVariableValue(VariableType.time, '12:60'), isNull);
      expect(canonicalizeVariableValue(VariableType.time, 'noon'), isNull);
    });

    test('date accepts ISO and rejects malformed or impossible dates', () {
      expect(
        canonicalizeVariableValue(VariableType.date, '2026-05-17'),
        '2026-05-17',
      );
      expect(canonicalizeVariableValue(VariableType.date, '17.05.2026'), isNull);
      // DateTime.parse would roll 2026-02-30 over to March — rejected, not
      // silently accepted as a different date.
      expect(canonicalizeVariableValue(VariableType.date, '2026-02-30'), isNull);
    });

    test('duration is whole non-negative minutes', () {
      expect(canonicalizeVariableValue(VariableType.duration, '45'), '45');
      expect(canonicalizeVariableValue(VariableType.duration, '0'), '0');
      expect(canonicalizeVariableValue(VariableType.duration, '-5'), isNull);
      expect(canonicalizeVariableValue(VariableType.duration, '1.5'), isNull);
    });
  });

  group('location value encoding', () {
    const position = LatLng(59.7445, 10.2045);

    test('encodes place + coordinate and decodes back', () {
      const location = VariableLocation(
        place: 'Meiselen 14, Drammen',
        position: position,
      );
      final encoded = encodeLocationValue(location);
      expect(encoded, '59.744500,10.204500 Meiselen 14, Drammen');
      final decoded = decodeLocationValue(encoded);
      expect(decoded.place, 'Meiselen 14, Drammen');
      expect(decoded.position!.latitude, closeTo(59.7445, 1e-9));
      expect(decoded.position!.longitude, closeTo(10.2045, 1e-9));
    });

    test('a coordinate-only value round-trips with an empty place', () {
      const location = VariableLocation(position: position);
      final decoded = decodeLocationValue(encodeLocationValue(location));
      expect(decoded.place, isEmpty);
      expect(decoded.position, isNotNull);
    });

    test('a place-only value round-trips with no position', () {
      const location = VariableLocation(place: 'Drammen stasjon');
      expect(encodeLocationValue(location), 'Drammen stasjon');
      final decoded = decodeLocationValue('Drammen stasjon');
      expect(decoded.place, 'Drammen stasjon');
      expect(decoded.position, isNull);
    });

    test('an out-of-range leading pair reads as place text, not a position', () {
      final decoded = decodeLocationValue('123,456 not a coordinate');
      expect(decoded.position, isNull);
      expect(decoded.place, '123,456 not a coordinate');
    });
  });

  group('parseCoordinateInput', () {
    test('parses a decimal lat,lng pair', () {
      final parsed = parseCoordinateInput('59.7445, 10.2045');
      expect(parsed, isNotNull);
      expect(parsed!.latitude, closeTo(59.7445, 1e-9));
      expect(parsed.longitude, closeTo(10.2045, 1e-9));
    });

    test('a decimal pair and its UTM string parse to the same LatLng', () {
      const original = LatLng(59.7445, 10.2045);
      final utm = projectUtmString(original);
      final fromUtm = parseCoordinateInput(utm);
      final fromDecimal = parseCoordinateInput('59.7445,10.2045');
      expect(fromUtm, isNotNull, reason: 'UTM string $utm should parse');
      expect(fromUtm!.latitude, closeTo(fromDecimal!.latitude, 1e-4));
      expect(fromUtm.longitude, closeTo(fromDecimal.longitude, 1e-4));
    });

    test('rejects garbage and out-of-range pairs', () {
      expect(parseCoordinateInput('not a coordinate'), isNull);
      expect(parseCoordinateInput('123,456'), isNull);
      expect(parseCoordinateInput(''), isNull);
    });
  });

  group('applyVariableOverride', () {
    test('a scalar override replaces the value', () {
      const declared = DrillVariable(name: 'frekvens', value: 'Kanal 6');
      expect(applyVariableOverride(declared, 'Kanal 9').value, 'Kanal 9');
      expect(applyVariableOverride(declared, null), declared);
    });

    test('a location override decodes into the structured value', () {
      const declared = DrillVariable(
        name: 'oppmote',
        type: VariableType.location,
        location: VariableLocation(place: 'Standard'),
      );
      final overridden = applyVariableOverride(
        declared,
        '59.744500,10.204500 Lokalt oppmøte',
      );
      expect(overridden.location!.place, 'Lokalt oppmøte');
      expect(overridden.location!.position, isNotNull);
    });
  });

  group('formatVariableValue', () {
    test('a number formats with the locale decimal separator, no grouping', () {
      const pi = DrillVariable(
        name: 'x',
        type: VariableType.number,
        value: '3.14',
      );
      const year = DrillVariable(
        name: 'y',
        type: VariableType.number,
        value: '2026',
      );
      expect(formatVariableValue(pi, _nb), '3,14');
      expect(formatVariableValue(pi, _en), '3.14');
      expect(
        formatVariableValue(year, _nb),
        '2026',
        reason: 'grouping is off — a year must not read "2 026"',
      );
    });

    test('a time renders HH:MM', () {
      const v = DrillVariable(name: 'x', type: VariableType.time, value: '12:00');
      expect(formatVariableValue(v, _nb), '12:00');
    });

    test('a date renders as a localized long date', () {
      const v = DrillVariable(
        name: 'x',
        type: VariableType.date,
        value: '2026-05-17',
      );
      expect(formatVariableValue(v, _nb), '17. mai 2026');
      expect(formatVariableValue(v, _en), 'May 17, 2026');
    });

    test('a duration renders "45 min" / "1 t 30 min" / "2 t"', () {
      DrillVariable minutes(String m) =>
          DrillVariable(name: 'x', type: VariableType.duration, value: m);
      expect(formatVariableValue(minutes('45'), _nb), '45 min');
      expect(formatVariableValue(minutes('90'), _nb), '1 t 30 min');
      expect(formatVariableValue(minutes('120'), _nb), '2 t');
      expect(formatVariableValue(minutes('90'), _en), '1 h 30 min');
    });

    test('a location renders place + UTM', () {
      const v = DrillVariable(
        name: 'oppmote',
        type: VariableType.location,
        location: VariableLocation(
          place: 'Meiselen 14',
          position: LatLng(59.7445, 10.2045),
        ),
      );
      final formatted = formatVariableValue(v, _nb);
      expect(formatted, startsWith('Meiselen 14 ('));
      expect(formatted, contains('32V'));
    });

    test('an incompatible value renders raw rather than being dropped', () {
      const v = DrillVariable(
        name: 'x',
        type: VariableType.number,
        value: 'Kanal 6',
      );
      expect(formatVariableValue(v, _nb), 'Kanal 6');
    });
  });
}

/// The UTM display string for [position], through the same public
/// formatting the app uses ("32V 0580414E 6552008N") — built via
/// `variableLocationAsLocation` + the shared facet default so this test
/// exercises the real pipeline rather than a private helper.
String projectUtmString(LatLng position) {
  final formatted = formatVariableValue(
    DrillVariable(
      name: 'x',
      type: VariableType.location,
      location: VariableLocation(position: position),
    ),
    _nb,
  );
  return formatted;
}
