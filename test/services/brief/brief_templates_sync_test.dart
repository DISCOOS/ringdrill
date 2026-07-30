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
