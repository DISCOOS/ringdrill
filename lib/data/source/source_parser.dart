/// Parses a DESIGN-014 source document into plain Dart collections, validating
/// each value against the field table as it goes.
///
/// This stops at the *document* level: the result is a normalized tree of maps
/// and lists whose values have the shapes [SourceScopes] declares, with keys
/// still in source spelling. Turning that into a [Plan] — filling derived
/// fields, minting uuids, relocating role plays — is `plan_builder.dart`. The
/// split keeps value-level validation (here) out of structural derivation
/// (there), so `analyze` can run this half alone on a document it will never
/// build.
///
/// Free of `package:flutter/*` (AGENTS.md rule 7).
library;

import 'package:ringdrill/data/source/source_diagnostic.dart';
import 'package:ringdrill/data/source/source_field.dart';
import 'package:ringdrill/data/source/source_fields.dart';
import 'package:yaml/yaml.dart';

/// A parsed source document: normalized values, source-spelled keys.
class SourceDocument {
  const SourceDocument({
    required this.sourceFormat,
    required this.plan,
    required this.exercises,
    required this.teams,
  });

  /// The declared format version, or [sourceFormatVersion] when the document
  /// omits it — an omitted version means "whatever this build speaks", which is
  /// the friendly reading for a hand-written or freshly generated document.
  final String sourceFormat;

  /// The `plan:` mapping, plus its `variables` child under the same key.
  final Map<String, dynamic> plan;

  final List<Map<String, dynamic>> exercises;

  /// Authored teams. Empty means "derive them" — not "no teams".
  final List<Map<String, dynamic>> teams;

  /// Variables as authored, keyed by name.
  Map<String, Map<String, dynamic>> get variables {
    final raw = plan['variables'];
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        e.key as String: (e.value as Map).cast<String, dynamic>(),
    };
  }
}

/// Reads source documents.
class SourceParser {
  /// Parses [yamlText], collecting every problem rather than stopping at the
  /// first.
  ///
  /// Throws [SourceFormatException] when the document cannot be understood at
  /// all (invalid YAML, missing `plan:`). Otherwise returns the document and
  /// appends findings to [diagnostics] — including warnings a caller may choose
  /// to tolerate.
  static SourceDocument parse(
    String yamlText, {
    required DiagnosticSink diagnostics,
  }) {
    final Object? root;
    try {
      root = loadYaml(yamlText);
    } on YamlException catch (e) {
      diagnostics.error('', 'not valid YAML: ${e.message}');
      throw SourceFormatException(diagnostics.items);
    }

    if (root == null) {
      diagnostics.error('', 'the document is empty');
      throw SourceFormatException(diagnostics.items);
    }
    if (root is! Map) {
      diagnostics.error(
        '',
        'the document must be a mapping, not ${_typeName(root)}',
      );
      throw SourceFormatException(diagnostics.items);
    }

    final doc = _plain(root) as Map<String, dynamic>;

    for (final key in doc.keys) {
      if (!SourceDocumentKeys.all.contains(key)) {
        diagnostics.warn(
          key,
          'unknown top-level key "$key"; ignored',
          hint: 'expected one of ${SourceDocumentKeys.all.join(', ')}',
        );
      }
    }

    final declaredVersion = doc[SourceDocumentKeys.sourceFormat];
    final sourceFormat = declaredVersion == null
        ? sourceFormatVersion
        : '$declaredVersion';
    if (declaredVersion != null && sourceFormat != sourceFormatVersion) {
      // Major/minor comparison would be premature at 1.0 — there is exactly one
      // version, so anything else is a document from a different build and the
      // honest answer is "this build does not speak that".
      diagnostics.error(
        SourceDocumentKeys.sourceFormat,
        'unsupported source format version "$sourceFormat"',
        hint: 'this build reads $sourceFormatVersion',
      );
    }

    final planRaw = doc[SourceDocumentKeys.plan];
    if (planRaw == null) {
      diagnostics.error(
        SourceDocumentKeys.plan,
        'the document has no "plan:" mapping',
      );
      throw SourceFormatException(diagnostics.items);
    }
    if (planRaw is! Map<String, dynamic>) {
      diagnostics.error(
        SourceDocumentKeys.plan,
        '"plan" must be a mapping, not ${_typeName(planRaw)}',
      );
      throw SourceFormatException(diagnostics.items);
    }

    final plan = _scope(
      planRaw,
      SourceScopes.plan,
      SourceDocumentKeys.plan,
      diagnostics,
    );

    final exercises = _list(
      doc[SourceDocumentKeys.exercises],
      SourceScopes.exercise,
      SourceDocumentKeys.exercises,
      diagnostics,
    );

    final teams = _list(
      doc[SourceDocumentKeys.teams],
      SourceScopes.team,
      SourceDocumentKeys.teams,
      diagnostics,
    );

    return SourceDocument(
      sourceFormat: sourceFormat,
      plan: plan,
      exercises: exercises,
      teams: teams,
    );
  }

  /// Validates one mapping against [scope], returning normalized values.
  static Map<String, dynamic> _scope(
    Map<String, dynamic> raw,
    SourceScope scope,
    String path,
    DiagnosticSink diagnostics,
  ) {
    final out = <String, dynamic>{};

    for (final entry in raw.entries) {
      final key = entry.key;
      final at = path.isEmpty ? key : '$path.$key';

      final child = scope.child(key);
      if (child != null) {
        out[key] = _children(entry.value, child, at, diagnostics);
        continue;
      }

      final field = scope.field(key);
      if (field == null) {
        diagnostics.warn(
          at,
          'unknown key "$key" on ${scope.name}; ignored',
          hint:
              'expected one of ${(scope.writableKeys.toList()..sort()).join(', ')}',
        );
        continue;
      }
      if (field.isDerived) {
        // Not an error: an author who pasted a decompiled document from a future
        // build, or hand-copied from an archive, gets told what happened rather
        // than having the build fail on a field they cannot influence anyway.
        diagnostics.warn(
          at,
          '"$key" is derived and cannot be authored; ignored',
          hint: 'the compiler computes it from the fields it depends on',
        );
        continue;
      }
      if (entry.value == null) continue;

      final value = _value(entry.value, field, at, diagnostics);
      if (value != null) out[key] = value;
    }

    return out;
  }

  static List<Map<String, dynamic>> _list(
    Object? raw,
    SourceScope scope,
    String path,
    DiagnosticSink diagnostics,
  ) {
    if (raw == null) return const [];
    if (raw is! List) {
      diagnostics.error(path, '"$path" must be a list, not ${_typeName(raw)}');
      return const [];
    }
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      final at = '$path[$i]';
      if (item is! Map<String, dynamic>) {
        diagnostics.error(
          at,
          'each ${scope.name} must be a mapping, not ${_typeName(item)}',
        );
        continue;
      }
      out.add(_scope(item, scope, at, diagnostics));
    }
    return out;
  }

  /// A nested collection, in whichever form its [SourceChild] declares.
  static Object _children(
    Object? raw,
    SourceChild child,
    String path,
    DiagnosticSink diagnostics,
  ) {
    switch (child.collection) {
      case SourceCollection.list:
      case SourceCollection.relocatedList:
        return _list(raw, child.scope, path, diagnostics);
      case SourceCollection.keyedMap:
        if (raw == null) return <String, Map<String, dynamic>>{};
        if (raw is! Map) {
          diagnostics.error(
            path,
            '"${child.sourceKey}" must be a mapping keyed by '
            '${child.keyField}, not ${_typeName(raw)}',
          );
          return <String, Map<String, dynamic>>{};
        }
        final out = <String, Map<String, dynamic>>{};
        for (final entry in raw.entries) {
          final key = '${entry.key}';
          final at = '$path.$key';
          final value = entry.value;
          if (value is! Map<String, dynamic>) {
            diagnostics.error(
              at,
              'each ${child.scope.name} must be a mapping, not '
              '${_typeName(value)}',
            );
            continue;
          }
          // The map key *is* the keyField; a document that also spells it out
          // inside is contradicting itself if the two differ.
          final inner = _scope(value, child.scope, at, diagnostics);
          final declared = inner[child.keyField];
          if (declared != null && declared != key) {
            diagnostics.error(
              '$at.${child.keyField}',
              '"${child.keyField}" is "$declared" but the key is "$key"',
              hint: 'the key is the ${child.keyField}; omit it inside',
            );
          }
          out[key] = {...inner, child.keyField!: key};
        }
        return out;
    }
  }

  /// Normalizes one scalar against its declared shape.
  ///
  /// Returns null (with a diagnostic) when the value cannot be used, so the
  /// caller drops the key rather than propagating something ill-typed into the
  /// model, where the failure would surface as an opaque `TypeError` from
  /// generated `fromJson` code.
  static Object? _value(
    Object? raw,
    SourceField field,
    String path,
    DiagnosticSink diagnostics,
  ) {
    switch (field.shape) {
      case SourceShape.string:
      case SourceShape.markdown:
        if (raw is String) return raw;
        // YAML gives numbers and booleans for unquoted scalars; a name of "2026"
        // or a value of "true" is a perfectly reasonable thing to write and
        // quoting it is a YAML detail an author should not have to know.
        if (raw is num || raw is bool) return '$raw';
        diagnostics.error(path, 'expected text, got ${_typeName(raw)}');
        return null;

      case SourceShape.integer:
        if (raw is int) return raw;
        if (raw is String) {
          final parsed = int.tryParse(raw.trim());
          if (parsed != null) return parsed;
        }
        diagnostics.error(
          path,
          'expected a whole number, got ${_typeName(raw)}',
        );
        return null;

      case SourceShape.boolean:
        if (raw is bool) return raw;
        diagnostics.error(
          path,
          'expected true or false, got ${_typeName(raw)}',
        );
        return null;

      case SourceShape.stringList:
        if (raw is List) {
          final out = <String>[];
          for (var i = 0; i < raw.length; i++) {
            final item = raw[i];
            if (item is String) {
              out.add(item);
            } else if (item is num || item is bool) {
              out.add('$item');
            } else {
              diagnostics.error(
                '$path[$i]',
                'expected text, got ${_typeName(item)}',
              );
            }
          }
          return out;
        }
        diagnostics.error(path, 'expected a list, got ${_typeName(raw)}');
        return null;

      case SourceShape.stringMap:
        if (raw is Map) {
          final out = <String, String>{};
          for (final entry in raw.entries) {
            final value = entry.value;
            if (value is String || value is num || value is bool) {
              out['${entry.key}'] = '$value';
            } else {
              diagnostics.error(
                '$path.${entry.key}',
                'expected text, got ${_typeName(value)}',
              );
            }
          }
          return out;
        }
        diagnostics.error(path, 'expected a mapping, got ${_typeName(raw)}');
        return null;

      case SourceShape.time:
        return _time(raw, path, diagnostics);

      case SourceShape.position:
        return _position(raw, path, diagnostics);

      case SourceShape.raw:
        return raw;

      case SourceShape.enumeration:
        final value = raw is String ? raw : '$raw';
        if (field.enumValues.isNotEmpty && !field.enumValues.contains(value)) {
          diagnostics.error(
            path,
            '"$value" is not a valid ${field.sourceKey}',
            hint: 'expected one of ${field.enumValues.join(', ')}',
          );
          return null;
        }
        return value;
    }
  }

  /// `"HH:MM"` → `{hour, minute}`.
  ///
  /// Accepts an unpadded hour (`9:45`), because that is what a hand-written
  /// document tends to contain, and a bare YAML integer only when it is
  /// unambiguous — `startTime: 9` is far more likely to mean 09:00 than a
  /// mistake, but it is warned about because `9:45` unquoted is *not* an
  /// integer and the inconsistency is worth naming.
  static Map<String, dynamic>? _time(
    Object? raw,
    String path,
    DiagnosticSink diagnostics,
  ) {
    if (raw is int) {
      if (raw < 0 || raw > 23) {
        diagnostics.error(path, 'expected a time as "HH:MM", got $raw');
        return null;
      }
      diagnostics.warn(
        path,
        'read "$raw" as ${raw.toString().padLeft(2, '0')}:00',
        hint: 'write times as "HH:MM" in quotes',
      );
      return {'hour': raw, 'minute': 0};
    }
    if (raw is! String) {
      diagnostics.error(
        path,
        'expected a time as "HH:MM", got ${_typeName(raw)}',
      );
      return null;
    }
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim());
    if (match == null) {
      diagnostics.error(path, 'expected a time as "HH:MM", got "$raw"');
      return null;
    }
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) {
      diagnostics.error(path, '"$raw" is not a valid time of day');
      return null;
    }
    return {'hour': hour, 'minute': minute};
  }

  /// `{lat, lng}` → GeoJSON `{coordinates: [lng, lat]}`.
  ///
  /// The flip happens here and nowhere else. Latitude and longitude are range-
  /// checked because a swapped pair in Norway (lat ~59, lng ~10) still parses as
  /// two valid doubles, and the resulting plan puts every station in the Indian
  /// Ocean without complaint — a check on latitude catches it at the boundary.
  static Map<String, dynamic>? _position(
    Object? raw,
    String path,
    DiagnosticSink diagnostics,
  ) {
    if (raw is! Map) {
      diagnostics.error(
        path,
        'expected a coordinate as {lat, lng}, got ${_typeName(raw)}',
      );
      return null;
    }
    final map = raw.map((k, v) => MapEntry('$k', v));
    final unknown = map.keys.where((k) => k != 'lat' && k != 'lng').toList();
    if (unknown.isNotEmpty) {
      diagnostics.warn(
        path,
        'ignored ${unknown.join(', ')} in a coordinate',
        hint: 'a coordinate is {lat, lng}',
      );
    }
    final lat = _double(map['lat']);
    final lng = _double(map['lng']);
    if (lat == null || lng == null) {
      diagnostics.error(path, 'a coordinate needs numeric lat and lng');
      return null;
    }
    if (lat.abs() > 90) {
      diagnostics.error(
        path,
        'latitude $lat is out of range',
        hint: lng.abs() <= 90
            ? 'lat and lng may be swapped'
            : 'latitude runs -90 to 90',
      );
      return null;
    }
    if (lng.abs() > 180) {
      diagnostics.error(path, 'longitude $lng is out of range');
      return null;
    }
    return {
      'coordinates': [lng, lat],
    };
  }

  static double? _double(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.trim());
    return null;
  }

  /// Recursively converts `YamlMap`/`YamlList` into plain maps and lists.
  ///
  /// Everything downstream — the field table, the model's `fromJson`, the JSON
  /// encoder — expects plain collections; a `YamlMap` masquerades as a `Map` but
  /// is immutable and compares unequal, which produces confusing failures far
  /// from here.
  static Object? _plain(Object? node) {
    if (node is YamlMap) {
      return <String, dynamic>{
        for (final entry in node.nodes.entries)
          '${(entry.key as YamlScalar).value}': _plain(entry.value),
      };
    }
    if (node is YamlList) {
      return node.nodes.map(_plain).toList();
    }
    if (node is YamlScalar) return node.value;
    if (node is Map) {
      return <String, dynamic>{
        for (final entry in node.entries) '${entry.key}': _plain(entry.value),
      };
    }
    if (node is List) return node.map(_plain).toList();
    return node;
  }

  static String _typeName(Object? value) {
    if (value == null) return 'nothing';
    if (value is String) return 'text';
    if (value is int) return 'a whole number';
    if (value is num) return 'a number';
    if (value is bool) return 'true/false';
    if (value is List) return 'a list';
    if (value is Map) return 'a mapping';
    return value.runtimeType.toString();
  }
}
