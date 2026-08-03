// Generates lib/l10n/headless_labels.g.dart from the ARB files. Run from the
// repo root:
//
//   dart run tools/generate_headless_labels.dart      (or: make labels)
//
// Why this exists (DESIGN-014, the ADR-0048 amendment): the brief layer and the
// source-format builder need a handful of localized strings while running
// headless — under `dart run`, under `dart pub global activate`, and inside a
// `dart compile exe` binary. DESIGN-014 assumed the headless label provider
// could read `app_en.arb`/`app_nb.arb` at runtime, but a compiled executable
// has no package directory to resolve them from, so the messages are baked into
// Dart instead. That also moves ICU parsing to generation time, where a
// malformed message fails loudly here rather than at render.
//
// The output is deterministic. `test/l10n/headless_labels_sync_test.dart`
// asserts it matches the ARBs, so an edited message cannot silently drift from
// the headless copy — regenerate when that test fails.
import 'dart:convert';
import 'dart:io';

/// Messages the headless label provider serves. Everything the brief layer and
/// the builder ask for, and nothing else — this is a deliberate subset of the
/// ~hundreds of app messages, kept small so the generated file stays reviewable.
///
/// Grouped by what needs them, because the two groups land in different stages
/// and it should be obvious which is which.
const headlessKeys = <String>[
  // Generated default names, used by the source-format builder (`build`) and
  // the `create` scaffold.
  'team',
  'station',
  'exercise',
  // The brief layer (`render`): field_resolver, brief_renderer and
  // exercise_share_format between them use exactly these. DESIGN-014 counted
  // nine, having looked only at the first two — exercise_share_format is in the
  // closure too and adds the rest.
  'round',
  'briefRingRoute',
  'briefModeTogether',
  'briefModeSplit',
  'briefStationNoPosition',
  'briefUnknownReference',
  'briefUnknownVariable',
  'rotationShareLegendPhases',
  // The round table's column headers.
  'execution',
  'evaluation',
  'rotation',
  'rotationShareTitle',
  'variableDurationHourUnit',
  'hour',
  'briefPerStation',
  'shareNoteRevisits',
  'shareNoteUnderCoverage',
  'rotationShareEachRound',
  'rotationShareReturn',
  'rotationShareNext',
];

/// Locales to bake in — the set the app ships (`flutter gen-l10n` reads the
/// same two ARBs).
const locales = <String>['en', 'nb'];

void main() {
  final tables = <String, Map<String, Object>>{};
  for (final locale in locales) {
    final path = 'lib/l10n/app_$locale.arb';
    final arb =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final table = <String, Object>{};
    for (final key in headlessKeys) {
      final raw = arb[key];
      if (raw is! String) {
        stderr.writeln('$path: message "$key" is missing or not a string.');
        exit(1);
      }
      table[key] = _parse(key, raw, path);
    }
    tables[locale] = table;
  }

  final buf = StringBuffer()
    ..writeln('// GENERATED FILE — DO NOT EDIT.')
    ..writeln('//')
    ..writeln(
      '// Regenerate with: dart run tools/generate_headless_labels.dart',
    )
    ..writeln('// Source: lib/l10n/app_en.arb, lib/l10n/app_nb.arb')
    ..writeln('//')
    ..writeln('// See tools/generate_headless_labels.dart for why the headless')
    ..writeln('// label provider bakes these in instead of reading the ARB at')
    ..writeln('// runtime, and lib/l10n/headless_labels.dart for the reader.')
    ..writeln()
    ..writeln('/// ARB messages the headless label provider serves, by locale.')
    ..writeln('///')
    ..writeln('/// A plain message is a `String`. An ICU plural is a')
    ..writeln('/// `Map<String, String>` keyed by its arms (`=0`, `=1`, `one`,')
    ..writeln('/// `other`, …), already parsed so the reader only has to pick')
    ..writeln('/// one and substitute placeholders.')
    ..writeln('const headlessLabelMessages = <String, Map<String, Object>>{');
  for (final locale in locales) {
    buf.writeln("  '$locale': {");
    for (final key in headlessKeys) {
      final value = tables[locale]![key]!;
      if (value is String) {
        buf.writeln("    '$key': ${_literal(value)},");
      } else {
        final arms = value as Map<String, String>;
        buf.writeln("    '$key': <String, String>{");
        for (final arm in arms.entries) {
          buf.writeln("      '${arm.key}': ${_literal(arm.value)},");
        }
        buf.writeln('    },');
      }
    }
    buf.writeln('  },');
  }
  buf.writeln('};');

  File('lib/l10n/headless_labels.g.dart').writeAsStringSync(buf.toString());
  _format('lib/l10n/headless_labels.g.dart');
  stdout.writeln(
    'Wrote lib/l10n/headless_labels.g.dart '
    '(${headlessKeys.length} messages × ${locales.length} locales)',
  );
}

/// Parses the ICU subset the selected messages actually use: either a plain
/// string (possibly with `{placeholder}`s, left for the reader to substitute)
/// or a single top-level `{count, plural, ...}` with literal arms.
///
/// Nested plurals, `select`, and formatted arguments (`{n, number}`) are not
/// supported — none of [headlessKeys] uses them, and failing loudly here is
/// better than growing a general ICU parser nobody asked for. If a message
/// grows one of those, this is the place that tells you.
Object _parse(String key, String raw, String path) {
  final match = RegExp(
    r'^\{(\w+),\s*plural,\s*(.*)\}$',
    dotAll: true,
  ).firstMatch(raw.trim());
  if (match == null) {
    if (raw.contains(', plural,') || raw.contains(', select,')) {
      stderr.writeln(
        '$path: message "$key" looks like ICU this generator cannot parse: '
        '$raw',
      );
      exit(1);
    }
    return raw;
  }
  final arms = <String, String>{};
  final body = match.group(2)!;
  // Walk the arms by hand: `=0{...} one{...} other{...}`, where an arm body may
  // itself contain braces around a placeholder.
  var i = 0;
  while (i < body.length) {
    if (body[i] == ' ') {
      i++;
      continue;
    }
    final armStart = i;
    while (i < body.length && body[i] != '{') {
      i++;
    }
    if (i >= body.length) break;
    final arm = body.substring(armStart, i).trim();
    var depth = 0;
    final valueStart = i + 1;
    while (i < body.length) {
      if (body[i] == '{') depth++;
      if (body[i] == '}') {
        depth--;
        if (depth == 0) break;
      }
      i++;
    }
    arms[arm] = body.substring(valueStart, i);
    i++;
  }
  if (arms.isEmpty || !arms.containsKey('other')) {
    stderr.writeln(
      '$path: message "$key" is a plural with no "other" arm: $raw',
    );
    exit(1);
  }
  return arms;
}

/// A single-quoted Dart string literal for [value], escaping what has to be.
String _literal(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n');
  return "'$escaped'";
}

/// Runs `dart format` on [path].
///
/// Without this the generated file is written unformatted, so `make format`
/// rewrites it and the next regeneration undoes that — an endless one-line diff
/// that shows up in every unrelated commit. A generator that does not produce
/// formatted output is a generator whose output is never actually stable.
void _format(String path) {
  final result = Process.runSync('dart', ['format', path]);
  if (result.exitCode != 0) {
    stderr.writeln('dart format failed for $path: ${result.stderr}');
    exit(result.exitCode);
  }
}
