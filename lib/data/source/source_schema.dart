/// Generates the source format's JSON Schema from the field table.
///
/// The schema is not documentation that happens to match the implementation — it
/// is produced from the same table `build` validates against, so the two cannot
/// disagree. That matters most for its second job: it is the tool schema a
/// generating agent calls against (DESIGN-014's MCP surface), so a field the
/// schema omits is a field the agent will never write, and one it invents is a
/// build failure the agent cannot diagnose.
///
/// Draft 2020-12, because that is what current tool-calling stacks expect.
///
/// Free of `package:flutter/*` (AGENTS.md rule 7).
library;

import 'package:ringdrill/data/source/source_field.dart';
import 'package:ringdrill/data/source/source_fields.dart';

/// Renders the JSON Schema.
class SourceSchema {
  const SourceSchema._();

  /// The schema as a JSON-encodable map.
  static Map<String, dynamic> generate() => {
    r'$schema': 'https://json-schema.org/draft/2020-12/schema',
    r'$id': 'https://ringdrill.app/schema/source/$sourceFormatVersion',
    'title': 'RingDrill source format $sourceFormatVersion',
    'description':
        'One human- and agent-writable document describing a drill plan. '
        'Compiled to a .drill archive by `ringdrill build`, which fills in '
        'everything derived (the rotation schedule, indices, uuids, the '
        'content hash). Authored fields only: if a value can be computed from '
        'another, it does not belong here.',
    'type': 'object',
    'required': ['plan'],
    'additionalProperties': false,
    'properties': {
      SourceDocumentKeys.sourceFormat: {
        'type': 'string',
        'const': sourceFormatVersion,
        'description':
            'Format version. Optional — an absent version means "whatever '
            'this build reads".',
      },
      SourceDocumentKeys.plan: {r'$ref': '#/\$defs/plan'},
      SourceDocumentKeys.exercises: {
        'type': 'array',
        'description':
            'Exercises in order. Position determines the derived number '
            '("#2") and every index; nothing is read from a name.',
        'items': {r'$ref': '#/\$defs/exercise'},
      },
      SourceDocumentKeys.teams: {
        'type': 'array',
        'description':
            'Optional. When absent, as many teams as the largest '
            'numberOfTeams across the exercises are generated with default '
            'names.',
        'items': {r'$ref': '#/\$defs/team'},
      },
    },
    r'$defs': {
      for (final scope in SourceScopes.all) scope.name: _scope(scope),
      'position': {
        'description':
            'A WGS84 coordinate, written either as {lat, lng} in decimal '
            'degrees or as a coordinate string — UTM as the brief renders it, '
            '"32V 0580083E 6551794N" (ADR-0061). Stored in the archive as '
            'GeoJSON [lng, lat], which the compiler flips. `decompile` always '
            'emits the {lat, lng} form, since UTM is metre-precision.',
        'oneOf': [
          {
            'type': 'object',
            'required': ['lat', 'lng'],
            'additionalProperties': false,
            'properties': {
              'lat': {'type': 'number', 'minimum': -90, 'maximum': 90},
              'lng': {'type': 'number', 'minimum': -180, 'maximum': 180},
            },
          },
          {
            'type': 'string',
            'examples': ['32V 0580083E 6551794N', '59.097921,10.397940'],
          },
        ],
      },
    },
  };

  static Map<String, dynamic> _scope(SourceScope scope) {
    final properties = <String, dynamic>{};

    for (final field in scope.fields) {
      // Derived fields are documented in the description, not offered as
      // properties: with additionalProperties false, listing them would make a
      // document that sets one *valid* against the schema while `build` ignores
      // it — the schema would be promising something the compiler does not do.
      if (field.isDerived) continue;
      properties[field.sourceKey] = _field(field);
    }

    for (final child in scope.children) {
      properties[child.sourceKey] = switch (child.collection) {
        SourceCollection.list ||
        SourceCollection.relocatedList => <String, dynamic>{
          'type': 'array',
          if (child.description != null) 'description': child.description,
          'items': {r'$ref': '#/\$defs/${child.scope.name}'},
        },
        SourceCollection.keyedMap => <String, dynamic>{
          'type': 'object',
          'description':
              child.description ??
              'Keyed by ${child.keyField}; the key becomes that field.',
          'additionalProperties': {r'$ref': '#/\$defs/${child.scope.name}'},
        },
      };
    }

    final derived = scope.derivedKeys.toList()..sort();
    return {
      'type': 'object',
      'additionalProperties': false,
      if (scope.description != null || derived.isNotEmpty)
        'description': [
          if (scope.description != null) scope.description,
          if (derived.isNotEmpty)
            'Derived and not writable here: ${derived.join(', ')}.',
        ].join(' '),
      'properties': properties,
    };
  }

  static Map<String, dynamic> _field(SourceField field) {
    final base = <String, dynamic>{
      if (field.description != null) 'description': field.description,
    };

    if (field.isIdentity) {
      // Spelled out because it is the one part of the format that surprises
      // people: optional on the way in, always present on the way out.
      base['description'] = [
        if (field.description != null) field.description,
        'Optional. Omit it and the compiler mints one; `decompile` always '
            'writes it, so a rebuilt document lands on the same entity rather '
            'than a copy.',
      ].join(' ');
    }

    return switch (field.shape) {
      SourceShape.string => {...base, 'type': 'string'},
      SourceShape.markdown => {
        ...base,
        'type': 'string',
        'description': [
          if (base['description'] != null) base['description'],
          'Markdown. Stored as ${field.mdFileName} in the archive. Write it '
              'as a YAML block scalar (|) — the content is literal there, so '
              'markdown needs no escaping. May contain {{var.<name>}} and '
              '{{station.loc.<slug>}} tokens, which resolve at render, not at '
              'build.',
        ].join(' '),
      },
      SourceShape.integer => {...base, 'type': 'integer'},
      SourceShape.boolean => {...base, 'type': 'boolean'},
      SourceShape.stringList => {
        ...base,
        'type': 'array',
        'items': {'type': 'string'},
      },
      SourceShape.stringMap => {
        ...base,
        'type': 'object',
        'additionalProperties': {'type': 'string'},
      },
      SourceShape.time => {
        ...base,
        'type': 'string',
        'pattern': r'^([01]?\d|2[0-3]):[0-5]\d$',
        'examples': ['09:45'],
        'description': [
          if (base['description'] != null) base['description'],
          'A clock face as "HH:MM", quoted.',
        ].join(' '),
      },
      SourceShape.position => {...base, r'$ref': '#/\$defs/position'},
      SourceShape.enumeration => {...base, 'enum': field.enumValues},
      // Only a location-typed variable's {place, position} reaches this, and it
      // is the one shape the scalar vocabulary cannot describe.
      SourceShape.raw => {
        ...base,
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'place': {'type': 'string'},
          'position': {r'$ref': '#/\$defs/position'},
        },
      },
    };
  }
}
