import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/utils/variable_values.dart';

Program _emptyProgram() {
  final now = DateTime(2026);
  return Program(
    uuid: 'prog-1',
    name: 'Test Program',
    description: '',
    metadata: ProgramMetadata(created: now, updated: now, version: '1.0'),
    teams: const [],
    sessions: const [],
    exercises: const [],
    rolePlays: const [],
    actors: const [],
  );
}

Exercise _exercise({Map<String, String> variableOverrides = const {}}) =>
    Exercise(
      uuid: 'ex-1',
      name: 'Exercise',
      startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
      endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
      numberOfTeams: 1,
      numberOfRounds: 1,
      executionTime: 10,
      evaluationTime: 5,
      rotationTime: 5,
      stations: const [],
      schedule: const [],
      variableOverrides: variableOverrides,
    );

void main() {
  group('planVariableTokenPattern', () {
    test('matches a declared token and captures the name', () {
      final match = planVariableTokenPattern.firstMatch(
        'Kanal {{var.frekvens}}',
      );
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

  group('effectivePlanVariables', () {
    test('program scope returns the declared defaults', () {
      final program = _emptyProgram().copyWith(
        variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
      );
      expect(effectivePlanVariables(program), {'frekvens': 'Kanal 6'});
    });

    test('an exercise override shadows the program default', () {
      final program = _emptyProgram().copyWith(
        variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
      );
      final exercise = _exercise(
        variableOverrides: const {'frekvens': 'Kanal 8'},
      );
      expect(effectivePlanVariables(program, exercise: exercise), {
        'frekvens': 'Kanal 8',
      });
    });

    test(
      'a station override shadows both the exercise and program default',
      () {
        final program = _emptyProgram().copyWith(
          variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
        );
        final exercise = _exercise(
          variableOverrides: const {'frekvens': 'Kanal 8'},
        );
        const station = Station(
          index: 0,
          name: 'Post',
          variableOverrides: {'frekvens': 'Kanal 9'},
        );
        expect(
          effectivePlanVariables(program, exercise: exercise, station: station),
          {'frekvens': 'Kanal 9'},
        );
      },
    );

    test('an override keyed on an undeclared variable name is ignored', () {
      final program = _emptyProgram().copyWith(
        variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
      );
      final exercise = _exercise(
        variableOverrides: const {'ukjent': 'Skal ikke vises'},
      );
      expect(effectivePlanVariables(program, exercise: exercise), {
        'frekvens': 'Kanal 6',
      });
    });

    test('a plan with no declared variables returns an empty map', () {
      expect(effectivePlanVariables(_emptyProgram()), <String, String>{});
    });

    test(
      'a location-typed variable renders its bare place + UTM display, '
      'not the raw structured value (DESIGN-008 follow-up 11)',
      () {
        final program = _emptyProgram().copyWith(
          variables: const [
            DrillVariable(
              name: 'oppmote',
              type: VariableType.location,
              location: VariableLocation(
                place: 'Meiselen 14',
                position: LatLng(59.7445, 10.2045),
              ),
            ),
          ],
        );
        final value = effectivePlanVariables(program)['oppmote']!;
        expect(value, startsWith('Meiselen 14 ('));
        expect(value, contains('32V'));
      },
    );
  });

  group('facet-aware token pattern (DESIGN-008 follow-up 11)', () {
    test('captures the name and the facet path', () {
      final match = planVariableTokenPattern.firstMatch(
        'Møt på {{var.oppmote.utm}}',
      )!;
      expect(match.group(1), 'oppmote');
      expect(planVariableTokenFacets(match), ['utm']);
    });

    test('the bare token has an empty facet list', () {
      final match = planVariableTokenPattern.firstMatch('{{var.oppmote}}')!;
      expect(planVariableTokenFacets(match), isEmpty);
    });

    test('planVariableTokenPatternFor matches a faceted token too', () {
      final pattern = planVariableTokenPatternFor('oppmote');
      expect(pattern.hasMatch('{{var.oppmote.utm}}'), isTrue);
      expect(pattern.hasMatch('{{var.oppmote}}'), isTrue);
      expect(pattern.hasMatch('{{var.oppmote2}}'), isFalse);
    });
  });

  group('effectiveTypedPlanVariables', () {
    test('a location override string decodes into the structured value', () {
      final program = _emptyProgram().copyWith(
        variables: const [
          DrillVariable(
            name: 'oppmote',
            type: VariableType.location,
            location: VariableLocation(place: 'Standard sted'),
          ),
        ],
      );
      final exercise = _exercise(
        variableOverrides: const {
          'oppmote': '59.744500,10.204500 Lokalt sted',
        },
      );
      final effective = effectiveTypedPlanVariables(
        program,
        exercise: exercise,
      )['oppmote']!;
      expect(effective.type, VariableType.location);
      expect(effective.location!.place, 'Lokalt sted');
      expect(effective.location!.position, isNotNull);
    });

    test('a scalar override keeps the declared type', () {
      final program = _emptyProgram().copyWith(
        variables: const [
          DrillVariable(name: 'tid', type: VariableType.time, value: '00:00'),
        ],
      );
      final exercise = _exercise(variableOverrides: const {'tid': '12:00'});
      final effective = effectiveTypedPlanVariables(
        program,
        exercise: exercise,
      )['tid']!;
      expect(effective.type, VariableType.time);
      expect(effective.value, '12:00');
    });
  });

  group('resolveTypedPlanVariables', () {
    const format = VariableFormat(localeName: 'nb', hourUnit: 't');
    const oppmote = DrillVariable(
      name: 'oppmote',
      type: VariableType.location,
      location: VariableLocation(
        place: 'Meiselen 14',
        position: LatLng(59.7445, 10.2045),
      ),
    );

    test('formats a scalar for display (duration)', () {
      const vars = {
        'varighet': DrillVariable(
          name: 'varighet',
          type: VariableType.duration,
          value: '90',
        ),
      };
      expect(
        resolveTypedPlanVariables('Tar {{var.varighet}}', vars, format: format),
        'Tar 1 t 30 min',
      );
    });

    test('a facet on a scalar renders the bare formatted value', () {
      const vars = {
        'tid': DrillVariable(
          name: 'tid',
          type: VariableType.time,
          value: '12:00',
        ),
      };
      expect(
        resolveTypedPlanVariables('Kl {{var.tid.utm}}', vars, format: format),
        'Kl 12:00',
      );
    });

    test('resolves location facets .place/.utm/.latlng and bare', () {
      const vars = {'oppmote': oppmote};
      expect(
        resolveTypedPlanVariables(
          '{{var.oppmote.place}}',
          vars,
          format: format,
        ),
        'Meiselen 14',
      );
      final utm = resolveTypedPlanVariables(
        '{{var.oppmote.utm}}',
        vars,
        format: format,
      );
      expect(utm, contains('32V'));
      expect(
        resolveTypedPlanVariables(
          '{{var.oppmote.latlng}}',
          vars,
          format: format,
        ),
        '59.744500,10.204500',
      );
      final bare = resolveTypedPlanVariables(
        '{{var.oppmote}}',
        vars,
        format: format,
      );
      expect(bare, startsWith('Meiselen 14 ('));
      expect(bare, contains('32V'));
    });

    test('an unknown name goes through onUnknown, or stays literal', () {
      expect(
        resolveTypedPlanVariables(
          '{{var.ukjent}}',
          const {},
          format: format,
          onUnknown: (name) => '<$name?>',
        ),
        '<ukjent?>',
      );
      expect(
        resolveTypedPlanVariables('{{var.ukjent}}', const {}, format: format),
        '{{var.ukjent}}',
      );
    });
  });
}
