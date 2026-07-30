// Generates lib/services/brief/brief_templates.g.dart from the mustache
// templates in assets/templates/. Run from the repo root:
//
//   dart run tools/generate_brief_templates.dart      (or: make templates)
//
// Why (DESIGN-014, the ADR-0048 amendment): BriefRenderer loaded its template
// through `rootBundle`, a Flutter AssetBundle, so `render` could not run
// headlessly. Reading the file from disk instead would work under `dart run` but
// not from an installed CLI — `dart pub global activate` and `dart build cli`
// produce something with no assets/ directory beside it. Same problem the ARB
// messages have, same answer: bake them in.
//
// Deterministic output; test/services/brief/brief_templates_sync_test.dart
// asserts it matches the assets, so an edited template cannot drift from the
// baked-in copy.
import 'dart:io';

void main() {
  final dir = Directory('assets/templates');
  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.mustache'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (files.isEmpty) {
    stderr.writeln('No .mustache templates found in ${dir.path}');
    exit(1);
  }

  final buf = StringBuffer()
    ..writeln('// GENERATED FILE — DO NOT EDIT.')
    ..writeln('//')
    ..writeln(
      '// Regenerate with: dart run tools/generate_brief_templates.dart',
    )
    ..writeln('// Source: assets/templates/*.mustache')
    ..writeln('//')
    ..writeln(
      '// See tools/generate_brief_templates.dart for why the templates',
    )
    ..writeln('// are baked in rather than loaded from the asset bundle.')
    ..writeln()
    ..writeln('/// Brief template sources, keyed by their asset path.')
    ..writeln('///')
    ..writeln(
      '/// The key is [BriefTemplate.assetPath], so the app and the CLI',
    )
    ..writeln('/// look a template up by exactly the same identifier.')
    ..writeln('const briefTemplateSources = <String, String>{');

  for (final file in files) {
    final assetPath = file.path.replaceAll(r'\', '/');
    buf.writeln("  '$assetPath': r'''");
    // Raw triple-quoted: the templates are mustache, so they are dense with {{ }}
    // and $ would otherwise interpolate. A template containing ''' would break
    // this, which is why the sync test compares content rather than trusting it.
    buf.write(file.readAsStringSync());
    buf.writeln("''',");
  }

  buf.writeln('};');

  File(
    'lib/services/brief/brief_templates.g.dart',
  ).writeAsStringSync(buf.toString());
  _format('lib/services/brief/brief_templates.g.dart');
  stdout.writeln(
    'Wrote lib/services/brief/brief_templates.g.dart '
    '(${files.length} templates)',
  );
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
