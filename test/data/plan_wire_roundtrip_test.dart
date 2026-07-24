import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/models/plan.dart';

/// Proves the `Program` → `Plan` Dart rename is wire-invisible (see
/// `docs/prompts/refactor-program-to-plan-and-person-description.md`): the
/// `.drill` archive's root manifest stays named `program.json`, its JSON
/// keys are unaffected by the class rename, and `PlanSource`'s union
/// discriminator (the frozen `local`/`imported`/`catalog` factory names)
/// round-trips intact.
void main() {
  Plan buildPlan() {
    final now = DateTime(2026);
    return Plan(
      uuid: 'prog-1',
      name: 'Wire round-trip',
      description: 'Proves Program->Plan is wire-invisible',
      metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
      source: const PlanSource.catalog(
        slug: 'wire-roundtrip',
        latestEtag: '"etag-v1"',
        latestVersion: '1',
      ),
      teams: const [],
      sessions: const [],
      exercises: const [],
      rolePlays: const [],
      actors: const [],
    );
  }

  test(
    'the archive still contains program.json and its JSON keys are unchanged',
    () {
      final drill = DrillFile.fromPlan(buildPlan(), 'test');
      final archive = ZipDecoder().decodeBytes(drill.content);

      final manifest = archive.files.singleWhere(
        (f) => f.name == 'program.json',
        orElse: () => fail('archive root manifest is not named program.json'),
      );

      final json =
          jsonDecode(utf8.decode(manifest.content as List<int>))
              as Map<String, dynamic>;
      expect(json.keys, containsAll(['uuid', 'name', 'exercises', 'source']));
      expect(json['uuid'], 'prog-1');
      expect(json['name'], 'Wire round-trip');
    },
  );

  test('a PlanSource.catalog(...) round-trips with its discriminator intact', () {
    final plan = buildPlan();
    final drill = DrillFile.fromPlan(plan, 'test');
    final archive = ZipDecoder().decodeBytes(drill.content);
    final manifest = archive.files.singleWhere((f) => f.name == 'program.json');
    final json =
        jsonDecode(utf8.decode(manifest.content as List<int>))
            as Map<String, dynamic>;

    // The union discriminator is keyed by the factory name (frozen),
    // never the Dart class name (renamed Program -> Plan).
    expect(json['source']['runtimeType'], 'catalog');

    final decoded = drill.plan();
    expect(decoded.source, plan.source);
    decoded.source.when(
      local: () => fail('expected catalog source'),
      imported: (_) => fail('expected catalog source'),
      catalog: (slug, latestEtag, installedAt, latestVersion) {
        expect(slug, 'wire-roundtrip');
        expect(latestEtag, '"etag-v1"');
        expect(latestVersion, '1');
      },
    );
  });

  test('a drill authored before the rename still imports', () {
    final bytes = File('test/fixtures/test-7x.drill').readAsBytesSync();
    final drill = DrillFile.fromBytes('test-7x.drill', bytes);

    expect(() => drill.plan(), returnsNormally);
    expect(drill.plan().exercises, isNotEmpty);
  });
}
