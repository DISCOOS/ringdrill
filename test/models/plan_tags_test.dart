import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/plan.dart';

void main() {
  final now = DateTime(2026);

  Plan base() => Plan(
        uuid: 'prog-1',
        name: 'Test',
        description: '',
        metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
        teams: const [],
        sessions: const [],
        exercises: const [],
      );

  Map<String, dynamic> minimalJson() => {
        'uuid': 'prog-1',
        'name': 'Test',
        'description': '',
        'metadata': {
          'created': '2026-01-01T00:00:00.000',
          'updated': '2026-01-01T00:00:00.000',
          'version': '1.0',
        },
        'teams': [],
        'sessions': [],
        'exercises': [],
      };

  test('program.json without tags deserializes to empty list', () {
    final json = minimalJson(); // no 'tags' key
    final plan = Plan.fromJson(json);
    expect(plan.tags, isEmpty);
  });

  test('program.json with tags: [] deserializes to empty list', () {
    final json = minimalJson()..['tags'] = <String>[];
    final plan = Plan.fromJson(json);
    expect(plan.tags, isEmpty);
  });

  test('program.json with tags round-trips correctly', () {
    final json = minimalJson()..['tags'] = ['sar', 'urban'];
    final plan = Plan.fromJson(json);
    expect(plan.tags, ['sar', 'urban']);

    // toJson must include the tags key so it serializes back out
    final reEncoded = plan.toJson();
    expect(reEncoded['tags'], ['sar', 'urban']);
  });

  test('default Plan() has empty tags', () {
    expect(base().tags, isEmpty);
  });

  test('copyWith replaces tags', () {
    final p = base().copyWith(tags: ['a', 'b']);
    expect(p.tags, ['a', 'b']);
    final p2 = p.copyWith(tags: []);
    expect(p2.tags, isEmpty);
  });
}
