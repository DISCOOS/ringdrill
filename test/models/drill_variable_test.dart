import 'package:flutter_test/flutter_test.dart';
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
}
