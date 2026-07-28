import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/drill_variable.dart';

void main() {
  test('DrillVariable round-trips unchanged', () {
    const variable = DrillVariable(
      name: 'frekvens',
      value: 'Kanal 6',
      hint: 'Sambandskanal',
    );
    final decoded = DrillVariable.fromJson(variable.toJson());
    expect(decoded, variable);
  });

  test('DrillVariable with only name deserializes with defaults', () {
    final decoded = DrillVariable.fromJson({'name': 'frekvens'});
    expect(decoded.name, 'frekvens');
    expect(decoded.value, '');
    expect(decoded.hint, isNull);
  });

  test('a legacy variable with no type loads as string (DESIGN-008 f11)', () {
    final decoded = DrillVariable.fromJson({
      'name': 'frekvens',
      'value': 'Kanal 6',
    });
    expect(decoded.type, VariableType.string);
    expect(decoded.location, isNull);
  });

  test('every VariableType persists and reloads', () {
    const values = {
      VariableType.string: 'Kanal 6',
      VariableType.number: '3.14',
      VariableType.time: '12:00',
      VariableType.date: '2026-05-17',
      VariableType.duration: '90',
      VariableType.location: '',
    };
    for (final type in VariableType.values) {
      final variable = DrillVariable(
        name: 'x',
        value: values[type]!,
        type: type,
      );
      final decoded = DrillVariable.fromJson(variable.toJson());
      expect(decoded, variable, reason: 'round-trip for $type');
    }
  });

  test('an unknown type slug decodes to string (forward compatibility)', () {
    final decoded = DrillVariable.fromJson({'name': 'x', 'type': 'hologram'});
    expect(decoded.type, VariableType.string);
  });

  test('the location value round-trips place + coordinate', () {
    const variable = DrillVariable(
      name: 'oppmote',
      type: VariableType.location,
      location: VariableLocation(
        place: 'Meiselen 14, Drammen',
        position: LatLng(59.7445, 10.2045),
      ),
    );
    // Through a JSON string, matching the real persistence path
    // (program.json in the .drill archive): jsonEncode invokes the nested
    // VariableLocation's toJson, which an in-memory toJson map does not
    // (the duck-typing caveat lat_lng_converter.dart documents).
    final decoded = DrillVariable.fromJson(
      jsonDecode(jsonEncode(variable.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.location!.place, 'Meiselen 14, Drammen');
    expect(decoded.location!.position!.latitude, closeTo(59.7445, 1e-9));
    expect(decoded.location!.position!.longitude, closeTo(10.2045, 1e-9));
    expect(decoded, variable);
  });
}
