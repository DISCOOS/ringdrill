import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/bulk_export.dart';
import 'package:ringdrill/models/plan.dart';

Plan _plan(String uuid, String name) {
  final now = DateTime(2026, 1, 1);
  return Plan(
    uuid: uuid,
    name: name,
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
    teams: const [],
    sessions: const [],
    exercises: const [],
    rolePlays: const [],
    actors: const [],
  );
}

void main() {
  group('bulkExportFileName', () {
    test('formats date correctly', () {
      expect(
        bulkExportFileName(DateTime(2026, 6, 29)),
        'ringdrill-eksport-2026-06-29.zip',
      );
    });

    test('pads single-digit month and day', () {
      expect(
        bulkExportFileName(DateTime(2026, 1, 5)),
        'ringdrill-eksport-2026-01-05.zip',
      );
    });
  });

  group('exportAllPlans', () {
    test('produces one .drill file per plan', () {
      final plans = [
        _plan('uuid-1', 'Alfa plan'),
        _plan('uuid-2', 'Beta plan'),
        _plan('uuid-3', 'Gamma plan'),
      ];

      final bytes = exportAllPlans(plans);
      final archive = ZipDecoder().decodeBytes(bytes);
      final drillFiles =
          archive.files.where((f) => f.isFile && f.name.endsWith('.drill'));

      expect(drillFiles.length, 3);
    });

    test('filenames are derived from plan names', () {
      final plans = [
        _plan('uuid-1', 'Alfa plan'),
        _plan('uuid-2', 'Beta plan'),
      ];

      final bytes = exportAllPlans(plans);
      final archive = ZipDecoder().decodeBytes(bytes);
      final names =
          archive.files
              .where((f) => f.isFile && f.name.endsWith('.drill'))
              .map((f) => f.name)
              .toSet();

      expect(names, contains('alfa-plan.drill'));
      expect(names, contains('beta-plan.drill'));
    });

    test('empty plan list returns a valid (empty) ZIP', () {
      final bytes = exportAllPlans([]);
      expect(bytes, isNotEmpty);
      // Should not throw
      ZipDecoder().decodeBytes(bytes);
    });

    test('inner .drill files are valid archives', () {
      final plans = [_plan('uuid-1', 'Test plan')];
      final bytes = exportAllPlans(plans);

      final outer = ZipDecoder().decodeBytes(bytes);
      final drillEntry = outer.files.firstWhere(
        (f) => f.isFile && f.name.endsWith('.drill'),
      );

      // Decoding must not throw and must contain at least program.json
      final inner = ZipDecoder().decodeBytes(drillEntry.content as List<int>);
      final hasPlan = inner.files.any(
        (f) => f.isFile && f.name == 'program.json',
      );
      expect(hasPlan, isTrue);
    });

    test('deduplicates filenames for plans with identical sanitised slugs',
        () {
      final plans = [
        _plan('uuid-1', 'My Plan'),
        _plan('uuid-2', 'My Plan'),
      ];

      final bytes = exportAllPlans(plans);
      final archive = ZipDecoder().decodeBytes(bytes);
      final names =
          archive.files.where((f) => f.isFile).map((f) => f.name).toList();

      expect(names.toSet().length, names.length);
    });

    test('plan with non-ascii name falls back to uuid slug', () {
      // A name that sanitises to empty (all non-ascii after strip) uses uuid.
      final plans = [_plan('my-uuid', '!!!')];

      final bytes = exportAllPlans(plans);
      final archive = ZipDecoder().decodeBytes(bytes);
      final name = archive.files
          .where((f) => f.isFile && f.name.endsWith('.drill'))
          .map((f) => f.name)
          .single;

      expect(name, 'my-uuid.drill');
    });
  });
}
