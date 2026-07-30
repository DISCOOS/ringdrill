// The generated JSON Schema must describe the format `build` actually accepts.
//
// It has two jobs, and the second is why this matters: it is the tool schema a
// generating agent calls against. A field the schema omits is a field the agent
// never writes; one it invents is a build failure the agent cannot diagnose from
// its own contract. So the test that counts is not "is this valid JSON Schema"
// but "does it agree with the field table" — the same table build validates
// against.
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/source/source_field.dart';
import 'package:ringdrill/data/source/source_fields.dart';
import 'package:ringdrill/data/source/source_schema.dart';

Map<String, dynamic> _defs(Map<String, dynamic> schema) =>
    schema[r'$defs'] as Map<String, dynamic>;

Map<String, dynamic> _props(Map<String, dynamic> def) =>
    def['properties'] as Map<String, dynamic>;

void main() {
  late Map<String, dynamic> schema;

  setUpAll(() => schema = SourceSchema.generate());

  test('declares the draft and a versioned id', () {
    expect(schema[r'$schema'], contains('2020-12'));
    expect(schema[r'$id'], contains(sourceFormatVersion));
    // The version pins to the *source format*, not the .drill schema — the two
    // are decoupled deliberately (DESIGN-014 settled decision 3).
    expect(schema[r'$id'], isNot(contains('1.2')));
  });

  test('every scope has a definition', () {
    for (final scope in SourceScopes.all) {
      expect(
        _defs(schema).containsKey(scope.name),
        isTrue,
        reason: 'no definition for scope "${scope.name}"',
      );
    }
  });

  test('every writable field is a property, and no derived one is', () {
    for (final scope in SourceScopes.all) {
      final properties = _props(_defs(schema)[scope.name]);
      for (final field in scope.fields) {
        if (field.isDerived) {
          expect(
            properties.containsKey(field.sourceKey),
            isFalse,
            reason:
                '${scope.name}.${field.sourceKey} is derived but offered as a '
                'property; with additionalProperties false that would make a '
                'document setting it valid against the schema while build '
                'ignores it',
          );
        } else {
          expect(
            properties.containsKey(field.sourceKey),
            isTrue,
            reason: '${scope.name}.${field.sourceKey} is missing',
          );
        }
      }
      for (final child in scope.children) {
        expect(
          properties.containsKey(child.sourceKey),
          isTrue,
          reason: '${scope.name}.${child.sourceKey} is missing',
        );
      }
    }
  });

  test('derived fields are named in the description instead', () {
    // Not offered, but not invisible either: an agent that sees `endTime` in an
    // archive needs to be told it is derived rather than left to guess.
    final exercise = _defs(schema)['exercise'] as Map<String, dynamic>;
    expect(exercise['description'], contains('endTime'));
    expect(exercise['description'], contains('schedule'));
  });

  test('rejects unknown keys at every level', () {
    expect(schema['additionalProperties'], isFalse);
    for (final scope in SourceScopes.all) {
      expect(
        (_defs(schema)[scope.name] as Map)['additionalProperties'],
        isFalse,
        reason: '${scope.name} would silently accept a misspelled key',
      );
    }
  });

  test('a coordinate is range-checked, shared by reference', () {
    final position = _defs(schema)['position'] as Map<String, dynamic>;
    expect(_props(position)['lat'], containsPair('maximum', 90));
    expect(_props(position)['lng'], containsPair('maximum', 180));
    // Every position field points at the one definition rather than restating it,
    // so the range check cannot be right in one place and missing in another.
    for (final scope in SourceScopes.all) {
      for (final field in scope.fields) {
        if (field.shape != SourceShape.position) continue;
        expect(
          _props(_defs(schema)[scope.name])[field.sourceKey],
          containsPair(r'$ref', r'#/$defs/position'),
        );
      }
    }
  });

  test(
    'a time carries a pattern that accepts the format and rejects prose',
    () {
      final startTime = _props(_defs(schema)['exercise'])['startTime'] as Map;
      final pattern = RegExp(startTime['pattern'] as String);
      expect(pattern.hasMatch('09:45'), isTrue);
      expect(pattern.hasMatch('9:45'), isTrue);
      expect(pattern.hasMatch('23:59'), isTrue);
      expect(pattern.hasMatch('24:00'), isFalse);
      expect(pattern.hasMatch('09:60'), isFalse);
      expect(pattern.hasMatch('quarter to ten'), isFalse);
    },
  );

  test('enumerations list their tokens', () {
    final kind = _props(_defs(schema)['location'])['kind'] as Map;
    expect(kind['enum'], contains('lkp'));
    expect(kind['enum'], contains('commandPost'));
    expect(
      (kind['enum'] as List).length,
      SourceScopes.location.field('kind')!.enumValues.length,
    );
  });

  test('markdown fields say where they are stored and that tokens are raw', () {
    final situation = _props(_defs(schema)['station'])['situation'] as Map;
    expect(situation['type'], 'string');
    expect(situation['description'], contains('situation.md'));
    expect(situation['description'], contains('block scalar'));
    // The single most useful thing to tell a generating agent: a token is content,
    // not something to resolve while writing.
    expect(situation['description'], contains('resolve at render'));
  });

  test('uuid explains that it is optional in and always out', () {
    final uuid = _props(_defs(schema)['exercise'])['uuid'] as Map;
    expect(uuid['description'], contains('mints one'));
    expect(uuid['description'], contains('same entity'));
  });

  test('variables are a keyed mapping, exercises an ordered array', () {
    final variables = _props(_defs(schema)['plan'])['variables'] as Map;
    expect(variables['type'], 'object');
    expect(
      variables['additionalProperties'],
      containsPair(r'$ref', r'#/$defs/variable'),
    );
    final exercises = _props(schema)['exercises'] as Map;
    expect(exercises['type'], 'array');
    // Says out loud that order is what numbering comes from — the rule an agent
    // is most likely to violate by writing "#2 " into a name instead.
    expect(exercises['description'], contains('Position determines'));
  });

  test('roleplays are nested under a station', () {
    final roleplays = _props(_defs(schema)['station'])['roleplays'] as Map;
    expect(roleplays['type'], 'array');
    expect(roleplays['items'], containsPair(r'$ref', r'#/$defs/roleplay'));
    expect(roleplays['description'], contains('plan level'));
  });

  test('only plan is required at the document root', () {
    expect(schema['required'], ['plan']);
  });
}
