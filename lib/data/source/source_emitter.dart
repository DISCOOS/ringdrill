/// Writes a source document as YAML, deterministically.
///
/// Hand-rolled rather than taken from a package, for two reasons. The output has
/// to be **byte-stable** — the round-trip golden test compares what `decompile`
/// writes, and a library that reorders keys or varies quoting would make that
/// test flap. And markdown bodies have to land in **block scalars** (`|`), which
/// is the whole reason the format is YAML: block-scalar content is literal, so a
/// markdown `#`, `-` or `:` needs no escaping (worked example decision 1). No
/// pub emitter gives us both.
///
/// Key order comes from the field table, so a decompiled document reads in the
/// same order the format is documented in rather than in map-iteration order.
///
/// Free of `package:flutter/*` (AGENTS.md rule 7).
library;

import 'package:ringdrill/data/source/source_field.dart';
import 'package:ringdrill/data/source/source_fields.dart';

/// Renders source documents as YAML text.
class SourceEmitter {
  const SourceEmitter._();

  /// Emits the whole document.
  ///
  /// [plan] carries the plan scope's keys (including its `variables` child),
  /// [exercises] and [teams] the two top-level collections. Values are expected
  /// in *source* shape — `"HH:MM"` strings, `{lat, lng}` maps — which is what
  /// `plan_decompiler.dart` produces.
  static String emit({
    required Map<String, dynamic> plan,
    required List<Map<String, dynamic>> exercises,
    required List<Map<String, dynamic>> teams,
    String? header,
  }) {
    final buf = StringBuffer();
    if (header != null) {
      for (final line in header.trimRight().split('\n')) {
        buf.writeln(line.isEmpty ? '#' : '# $line');
      }
      buf.writeln();
    }

    // The version is written explicitly even though `build` defaults it: a
    // decompiled document is a machine artefact that may outlive this build, and
    // an unversioned one would be silently reinterpreted rather than rejected.
    buf.writeln('${SourceDocumentKeys.sourceFormat}: "$sourceFormatVersion"');
    buf.writeln();

    buf.writeln('${SourceDocumentKeys.plan}:');
    _scope(buf, plan, SourceScopes.plan, indent: 1);

    if (exercises.isNotEmpty) {
      buf.writeln();
      buf.writeln('${SourceDocumentKeys.exercises}:');
      for (final exercise in exercises) {
        _item(buf, exercise, SourceScopes.exercise, indent: 1);
      }
    }

    if (teams.isNotEmpty) {
      buf.writeln();
      buf.writeln('${SourceDocumentKeys.teams}:');
      for (final team in teams) {
        _item(buf, team, SourceScopes.team, indent: 1);
      }
    }

    return buf.toString();
  }

  /// Writes every key of [scope] present in [values], in table order.
  static void _scope(
    StringBuffer buf,
    Map<String, dynamic> values,
    SourceScope scope, {
    required int indent,
    bool firstKeyInline = false,
  }) {
    var inline = firstKeyInline;

    for (final field in scope.fields) {
      if (field.isDerived) continue;
      final value = values[field.sourceKey];
      if (value == null) continue;
      if (value is String && value.isEmpty) continue;
      if (value is Iterable && value.isEmpty) continue;
      if (value is Map && value.isEmpty) continue;
      _field(buf, field, value, indent: indent, inline: inline);
      inline = false;
    }

    for (final child in scope.children) {
      final value = values[child.sourceKey];
      if (value == null) continue;
      if (value is Iterable && value.isEmpty) continue;
      if (value is Map && value.isEmpty) continue;
      _prefix(buf, indent: indent, inline: inline);
      inline = false;
      buf.writeln('${child.sourceKey}:');
      switch (child.collection) {
        case SourceCollection.list:
        case SourceCollection.relocatedList:
          for (final item in (value as List).cast<Map<String, dynamic>>()) {
            _item(buf, item, child.scope, indent: indent + 1);
          }
        case SourceCollection.keyedMap:
          final map = (value as Map).cast<String, Map<String, dynamic>>();
          for (final entry in map.entries) {
            _prefix(buf, indent: indent + 1, inline: false);
            buf.writeln('${entry.key}:');
            // The key is the keyField, so it is not repeated inside.
            final inner = Map<String, dynamic>.from(entry.value)
              ..remove(child.keyField);
            _scope(buf, inner, child.scope, indent: indent + 2);
          }
      }
    }
  }

  /// One list item: `- ` followed by the first key, the rest aligned under it.
  static void _item(
    StringBuffer buf,
    Map<String, dynamic> values,
    SourceScope scope, {
    required int indent,
  }) {
    final before = buf.length;
    buf.write('${'  ' * indent}- ');
    _scope(buf, values, scope, indent: indent + 1, firstKeyInline: true);
    // An item with nothing to write would leave a dangling "- ". Rare (a station
    // with only derived fields) but it would produce invalid-looking YAML.
    if (buf.length == before + '${'  ' * indent}- '.length) {
      buf.writeln('{}');
    }
  }

  static void _field(
    StringBuffer buf,
    SourceField field,
    Object value, {
    required int indent,
    required bool inline,
  }) {
    switch (field.shape) {
      case SourceShape.markdown:
        _prefix(buf, indent: indent, inline: inline);
        _blockScalar(buf, field.sourceKey, '$value', indent: indent);

      case SourceShape.position:
        _prefix(buf, indent: indent, inline: inline);
        final map = (value as Map).cast<String, dynamic>();
        buf.writeln(
          '${field.sourceKey}: { lat: ${_number(map['lat'])}, '
          'lng: ${_number(map['lng'])} }',
        );

      case SourceShape.stringList:
        _prefix(buf, indent: indent, inline: inline);
        final items = (value as Iterable).map((e) => _scalar('$e'));
        buf.writeln('${field.sourceKey}: [${items.join(', ')}]');

      case SourceShape.stringMap:
        final map = (value as Map).cast<String, dynamic>();
        _prefix(buf, indent: indent, inline: inline);
        buf.writeln('${field.sourceKey}:');
        for (final entry in map.entries) {
          _prefix(buf, indent: indent + 1, inline: false);
          buf.writeln('${entry.key}: ${_scalar('${entry.value}')}');
        }

      case SourceShape.raw:
        _prefix(buf, indent: indent, inline: inline);
        buf.writeln('${field.sourceKey}:');
        _raw(buf, value, indent: indent + 1);

      case SourceShape.integer:
      case SourceShape.boolean:
        _prefix(buf, indent: indent, inline: inline);
        buf.writeln('${field.sourceKey}: $value');

      case SourceShape.time:
        _prefix(buf, indent: indent, inline: inline);
        // Always quoted. The `yaml` package reads YAML 1.2, where `17:00` is a
        // string — but YAML 1.1 readers parse it as sexagesimal 1020, and the
        // documents this writes are meant to be read by other tools too (the MCP
        // server, whatever an agent uses). The worked example quotes times for
        // the same reason.
        buf.writeln('${field.sourceKey}: "$value"');

      case SourceShape.string:
      case SourceShape.enumeration:
        _prefix(buf, indent: indent, inline: inline);
        // Multi-line text in a plain string field (a station `description`
        // carrying a paragraph) gets a block scalar too — quoting it would
        // require escaping and would read far worse.
        final text = '$value';
        if (text.contains('\n')) {
          _blockScalar(buf, field.sourceKey, text, indent: indent);
        } else {
          buf.writeln('${field.sourceKey}: ${_scalar(text)}');
        }
    }
  }

  /// A nested map/list with no scope of its own — only a `location`-typed
  /// variable's `{place, position}` reaches this.
  static void _raw(StringBuffer buf, Object? value, {required int indent}) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = '${entry.key}';
        final inner = entry.value;
        if (inner == null) continue;
        if (key == 'position' && inner is Map) {
          final map = inner.cast<String, dynamic>();
          _prefix(buf, indent: indent, inline: false);
          buf.writeln(
            'position: { lat: ${_number(map['lat'])}, '
            'lng: ${_number(map['lng'])} }',
          );
          continue;
        }
        if (inner is Map || inner is List) {
          _prefix(buf, indent: indent, inline: false);
          buf.writeln('$key:');
          _raw(buf, inner, indent: indent + 1);
          continue;
        }
        _prefix(buf, indent: indent, inline: false);
        buf.writeln('$key: ${_scalar('$inner')}');
      }
      return;
    }
    if (value is List) {
      for (final item in value) {
        _prefix(buf, indent: indent, inline: false);
        buf.writeln('- ${_scalar('$item')}');
      }
    }
  }

  /// `key: |` followed by the body, indented.
  ///
  /// Uses `|` (keep the final newline) when the body ends in one and `|-` (strip
  /// it) when it does not, so the exact bytes survive a round trip. Getting this
  /// wrong is the classic way a YAML round trip silently gains or loses a
  /// trailing `\n` — and a changed markdown body is a changed `contentHash`.
  static void _blockScalar(
    StringBuffer buf,
    String key,
    String body, {
    required int indent,
  }) {
    final lines = body.split('\n');
    final endsWithNewline = lines.isNotEmpty && lines.last.isEmpty;
    final content = endsWithNewline
        ? lines.sublist(0, lines.length - 1)
        : lines;

    // A body whose first line is indented, or which ends in more than one
    // newline, needs an explicit indentation indicator or chomping the reader
    // would guess differently. Both are rare; a double-quoted scalar is the
    // honest fallback rather than emitting something that re-reads differently.
    final needsQuoting =
        content.isEmpty ||
        content.first.startsWith(' ') ||
        content.first.startsWith('\t') ||
        body.endsWith('\n\n');
    if (needsQuoting) {
      buf.writeln('$key: ${_doubleQuoted(body)}');
      return;
    }

    buf.writeln('$key: ${endsWithNewline ? '|' : '|-'}');
    final pad = '  ' * (indent + 1);
    for (final line in content) {
      buf.writeln(line.isEmpty ? '' : '$pad$line');
    }
  }

  /// Indentation, or nothing when this key follows a `- ` on the same line.
  static void _prefix(
    StringBuffer buf, {
    required int indent,
    required bool inline,
  }) {
    if (!inline) buf.write('  ' * indent);
  }

  /// A scalar, quoted only when it has to be.
  ///
  /// Unquoted where safe because the format is read by people as well as tools,
  /// and a document where every value is quoted is markedly harder to scan.
  static String _scalar(String value) {
    if (value.isEmpty) return '""';
    final needsQuotes =
        RegExp(
          r'''^[\s]|[\s]$|^[-?:,\[\]{}#&*!|>'"%@`]|:\s|\s#''',
        ).hasMatch(value) ||
        // Anything that would re-read as a non-string: numbers, booleans, nulls,
        // and the YAML 1.1 spellings the parser still honours.
        const {
          'true',
          'false',
          'null',
          'yes',
          'no',
          'on',
          'off',
          '~',
        }.contains(value.toLowerCase()) ||
        num.tryParse(value) != null ||
        value.contains('\n');
    if (!needsQuotes) return value;
    if (!value.contains("'") && !value.contains('\n')) return "'$value'";
    return _doubleQuoted(value);
  }

  static String _doubleQuoted(String value) {
    final escaped = value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\t', r'\t');
    return '"$escaped"';
  }

  /// Coordinates without exponent notation or a trailing `.0`.
  ///
  /// `59.09789` must not come back as `5.909789e1`: it re-reads to the same
  /// double, but the document is meant to be diffed and read by hand.
  static String _number(Object? value) {
    if (value is int) return '$value';
    if (value is! num) return '$value';
    final text = value.toString();
    return text.contains('e') ? value.toStringAsFixed(8) : text;
  }
}
