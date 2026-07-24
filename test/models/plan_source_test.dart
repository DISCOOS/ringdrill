import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/plan.dart';

/// Coverage for [PlanSource.catalog]'s `latestVersion` field — added so
/// the catalog conflict dialog can show "what version is installed locally"
/// alongside "what version the catalog currently has". Must round-trip
/// through JSON, and must default to null for JSON written before this
/// field existed (an already-installed catalog plan on disk).
void main() {
  test('latestVersion round-trips through JSON', () {
    const source = PlanSource.catalog(
      slug: 'sprint-1',
      latestEtag: '"etag-v5"',
      latestVersion: '5',
    );

    final json = source.toJson();
    final decoded = PlanSource.fromJson(json);

    expect(decoded, isA<PlanSource>());
    decoded.when(
      local: () => fail('expected catalog source'),
      imported: (_) => fail('expected catalog source'),
      catalog: (slug, latestEtag, installedAt, latestVersion) {
        expect(slug, 'sprint-1');
        expect(latestEtag, '"etag-v5"');
        expect(latestVersion, '5');
      },
    );
  });

  test('a legacy JSON blob without latestVersion decodes it as null', () {
    final decoded = PlanSource.fromJson({
      'runtimeType': 'catalog',
      'slug': 'legacy-plan',
      'latestEtag': '"etag-v1"',
    });

    decoded.when(
      local: () => fail('expected catalog source'),
      imported: (_) => fail('expected catalog source'),
      catalog: (slug, latestEtag, installedAt, latestVersion) {
        expect(slug, 'legacy-plan');
        expect(latestVersion, isNull);
      },
    );
  });
}
