// AGENTS.md rule 7 / ADR-0005: `bin/ringdrill.dart` and everything it imports
// must stay free of `package:flutter/*`, or `dart pub global activate` breaks.
//
// `make cli-check` (`dart build cli`) is the authoritative check, but it takes
// minutes and reports a link failure rather than a cause. This walks the same
// import closure in milliseconds and names the chain that reached Flutter, which
// is the part you actually need in order to fix it.
//
// Why this became worth having: the closure used to be two files
// (drill_client + drill_file). DESIGN-014 extended it to the source compiler,
// the models, the schedule derivation and the headless label reader — and stage
// 5 adds the whole brief layer. That is a lot of surface on which someone can
// add one convenient import and only find out from a user.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Import/export/part targets of [file], as raw URI strings.
Iterable<String> _directives(File file) {
  final source = file.readAsStringSync();
  // Deliberately a regex over source rather than the analyzer: this test has to
  // stay cheap enough to run on every `flutter test`, and directives are the one
  // part of Dart that is reliably greppable. Conditional imports
  // (`if (dart.library.io)`) name both targets, and both are followed — which is
  // what we want, since either can be the one that gets compiled.
  final pattern = RegExp(
    r'''^\s*(?:import|export|part)\s+(?:'([^']+)'|"([^"]+)")''',
    multiLine: true,
  );
  return pattern.allMatches(source).map((m) => m.group(1) ?? m.group(2)!);
}

/// Resolves a `package:` URI to a file, using the package config the SDK wrote.
File? _resolvePackage(String uri, Map<String, String> packageRoots) {
  final withoutScheme = uri.substring('package:'.length);
  final slash = withoutScheme.indexOf('/');
  if (slash < 0) return null;
  final package = withoutScheme.substring(0, slash);
  final path = withoutScheme.substring(slash + 1);
  final root = packageRoots[package];
  if (root == null) return null;
  return File('$root$path');
}

void main() {
  test('the CLI import closure contains no Flutter', () {
    final config =
        jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
            as Map<String, dynamic>;
    final packageRoots = <String, String>{};
    for (final package in config['packages'] as List) {
      final map = package as Map<String, dynamic>;
      final rootUri = map['rootUri'] as String;
      final packageUri = (map['packageUri'] as String?) ?? 'lib/';
      // rootUri is relative to .dart_tool/ for path dependencies within the
      // repo, absolute (file://) for pub-cache ones.
      final root = rootUri.startsWith('file://')
          ? Uri.parse(rootUri).toFilePath()
          : File('.dart_tool/$rootUri').absolute.path;
      packageRoots[map['name'] as String] =
          '${root.endsWith('/') ? root : '$root/'}$packageUri';
    }

    final entry = File('bin/ringdrill.dart');
    expect(entry.existsSync(), isTrue);

    // Breadth-first so the reported chain is the shortest one — the most useful
    // for finding where to cut.
    final queue = <(File, List<String>)>[
      (entry, ['bin/ringdrill.dart']),
    ];
    final visited = <String>{entry.absolute.path};
    final offenders = <String>[];

    while (queue.isNotEmpty) {
      final (file, chain) = queue.removeAt(0);
      if (!file.existsSync()) continue;

      for (final uri in _directives(file)) {
        if (uri.startsWith('package:flutter/') ||
            uri == 'package:flutter' ||
            uri.startsWith('package:flutter_') ||
            uri == 'dart:ui' ||
            uri == 'dart:html') {
          offenders.add('${chain.join(' → ')} → $uri');
          continue;
        }
        if (uri.startsWith('dart:')) continue;

        final File? target;
        if (uri.startsWith('package:')) {
          // Only follow this package's own sources. A pub dependency that pulls
          // Flutter in is caught by `dart build cli`; following every transitive
          // package here would make the test slow and its failures unactionable.
          if (!uri.startsWith('package:ringdrill/')) continue;
          target = _resolvePackage(uri, packageRoots);
        } else {
          target = File(
            Uri.parse(file.absolute.path).resolve(uri).toFilePath(),
          );
        }
        if (target == null) continue;
        if (!visited.add(target.absolute.path)) continue;
        queue.add((target, [...chain, uri]));
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'bin/ringdrill.dart must not reach Flutter (AGENTS.md rule 7, '
          'ADR-0005). Offending chains:\n  ${offenders.join('\n  ')}',
    );
  });
}
