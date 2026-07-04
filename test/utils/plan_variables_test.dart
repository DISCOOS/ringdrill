import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/utils/plan_variables.dart';

void main() {
  group('planVariableTokenPattern', () {
    test('matches a declared token and captures the name', () {
      final match = planVariableTokenPattern.firstMatch('Kanal {{var.frekvens}}');
      expect(match, isNotNull);
      expect(match!.group(1), 'frekvens');
    });

    test('tolerates inner whitespace around the name', () {
      final match = planVariableTokenPattern.firstMatch('{{ var.frekvens }}');
      expect(match, isNotNull);
      expect(match!.group(1), 'frekvens');
    });

    test('does not match a non-var expression', () {
      expect(planVariableTokenPattern.hasMatch('{{exercise.name}}'), isFalse);
    });
  });

  group('planVariableTokenPatternFor', () {
    test('matches only the named variable, not a prefix collision', () {
      final pattern = planVariableTokenPatternFor('kanal');
      expect(pattern.allMatches('{{var.kanal}} {{var.kanal2}}').length, 1);
    });

    test('tolerates inner whitespace around the name', () {
      final pattern = planVariableTokenPatternFor('kanal');
      expect(pattern.hasMatch('{{ var.kanal }}'), isTrue);
    });
  });

  group('substitutePlanVariables', () {
    test('replaces a declared variable with its value', () {
      final result = substitutePlanVariables('Kanal {{var.frekvens}}', {
        'frekvens': 'Kanal 6',
      });
      expect(result, 'Kanal Kanal 6');
    });

    test('a declared-but-empty value substitutes the empty string', () {
      final result = substitutePlanVariables('Verdi:[{{var.tom}}]', {
        'tom': '',
      });
      expect(result, 'Verdi:[]');
    });

    test('an undeclared name is left as literal text without onUnknown', () {
      final result = substitutePlanVariables('Kanal {{var.mangler}}', {});
      expect(result, 'Kanal {{var.mangler}}');
    });

    test('an undeclared name calls onUnknown with the name', () {
      final result = substitutePlanVariables(
        'Kanal {{var.mangler}}',
        {},
        onUnknown: (name) => '[ukjent: $name]',
      );
      expect(result, 'Kanal [ukjent: mangler]');
    });

    test('tolerates inner whitespace around the name', () {
      final result = substitutePlanVariables('{{ var.frekvens }}', {
        'frekvens': 'Kanal 6',
      });
      expect(result, 'Kanal 6');
    });

    test('leaves non-var mustache expressions untouched', () {
      final result = substitutePlanVariables('{{exercise.name}} {{var.x}}', {
        'x': 'y',
      });
      expect(result, '{{exercise.name}} y');
    });
  });
}
