// Keeps the baked-in brief templates honest against the assets they came from.
//
// `lib/services/brief/brief_templates.g.dart` is a copy of
// `assets/templates/*.mustache` (DESIGN-014's ADR-0048 amendment): the CLI's
// `render` cannot load them through the Flutter asset bundle, and an installed
// CLI has no assets/ directory to read them from either. A copy can drift, and
// the failure mode is quiet — the app renders the edited template while the CLI
// renders the old one. When this fails, regenerate rather than editing the
// .g.dart:
//
//   dart run tools/generate_brief_templates.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/services/brief/brief_template_source.dart';
import 'package:ringdrill/services/brief/brief_templates.g.dart';
import 'package:ringdrill/services/brief/template_registry.dart';

void main() {
  test('every asset template is baked in, byte for byte', () {
    final assets =
        Directory('assets/templates')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.mustache'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    expect(assets, isNotEmpty, reason: 'no templates found to compare against');

    for (final asset in assets) {
      final key = asset.path.replaceAll(r'\', '/');
      expect(
        briefTemplateSources.containsKey(key),
        isTrue,
        reason:
            '$key is not baked in; run '
            'dart run tools/generate_brief_templates.dart',
      );
      expect(
        briefTemplateSources[key],
        asset.readAsStringSync(),
        reason:
            '$key drifted from the baked-in copy; run '
            'dart run tools/generate_brief_templates.dart',
      );
    }

    expect(
      briefTemplateSources.length,
      assets.length,
      reason: 'a baked-in template no longer has an asset behind it',
    );
  });

  // The other axis of the same failure, and the one nothing checked: this file
  // guarded asset-against-baked, per file, so a slot added to one *locale* and
  // forgotten in the other passed. That failure is silent in the worse direction —
  // a template that omits a slot drops the content without error (only a missing
  // *context key* throws), so English readers would quietly lose a section that
  // Norwegian readers see, with nothing in either output to say so.
  test('the locale variants of a template carry the same slots', () {
    final byFamily = <String, Map<String, String>>{};
    for (final entry in briefTemplateSources.entries) {
      // assets/templates/<family>.<locale>.md.mustache
      final base = entry.key.split('/').last.replaceAll('.md.mustache', '');
      final dot = base.lastIndexOf('.');
      if (dot < 0) continue;
      byFamily.putIfAbsent(
        base.substring(0, dot),
        () => {},
      )[base.substring(dot + 1)] = entry.value;
    }

    final tag = RegExp(r'\{\{[#^/&]?\s*([\w.]+)\s*\}\}');
    // The full ordered tag sequence, not a set: order and nesting are structure,
    // so a section moved or a loop closed in the wrong place is drift too.
    List<String> slots(String source) =>
        tag.allMatches(source).map((m) => m.group(0)!).toList();

    expect(byFamily, isNotEmpty, reason: 'no template families found');
    for (final family in byFamily.entries) {
      final locales = family.value.keys.toList()..sort();
      expect(
        locales.length,
        greaterThan(1),
        reason:
            '${family.key} has only ${locales.first} — add the other locale '
            'or drop the locale suffix',
      );
      final reference = slots(family.value[locales.first]!);
      for (final locale in locales.skip(1)) {
        expect(
          slots(family.value[locale]!),
          reference,
          reason:
              '${family.key}.$locale renders a different set or order of slots '
              'than ${family.key}.${locales.first}. A slot present in one locale '
              'and absent in the other silently drops that content for readers '
              'of the second.',
        );
      }
    }
  });

  test('every registered template resolves to a baked-in source', () async {
    // The registry is what the renderer asks; the source is what answers. A
    // registered template with no source is a runtime failure in the CLI only —
    // the app would have loaded it from the bundle — so it has to be caught here.
    const source = BakedBriefTemplateSource();
    for (final locale in ['nb', 'en', 'de', null]) {
      final template = TemplateRegistry.instance.resolve(null, locale);
      await expectLater(
        source.load(template.assetPath),
        completion(isNotEmpty),
        reason: 'locale $locale resolved to ${template.assetPath}',
      );
    }
  });

  test('an unknown path fails with what is available', () async {
    const source = BakedBriefTemplateSource();
    await expectLater(
      source.load('assets/templates/nope.mustache'),
      throwsA(
        isA<BriefTemplateNotFound>().having(
          (e) => e.toString(),
          'toString',
          contains('ringdrill-standard-v1'),
        ),
      ),
    );
  });
}
