import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/utils/slug.dart';

/// DESIGN-009 follow-up 4h — `randomSlug` generates a short random
/// `^[a-z][a-z0-9_]*$` reference, derived from no field, so it never drifts
/// out of sync with a display label/name that changes later.
void main() {
  final slugPattern = RegExp(r'^[a-z][a-z0-9_]*$');

  test('matches the slug rule: leading letter, then [a-z0-9]', () {
    final slug = randomSlug((_) => false);
    expect(slug, matches(slugPattern));
  });

  test('repeated calls against an accumulating isTaken set are all distinct', () {
    final existing = <String>{};
    for (var i = 0; i < 50; i++) {
      final slug = randomSlug(existing.contains);
      expect(slug, matches(slugPattern));
      expect(existing, isNot(contains(slug)));
      existing.add(slug);
    }
  });

  test('a collision forces a fresh value, not a _2 suffix', () {
    final calls = <String>[];
    var first = true;
    final slug = randomSlug((candidate) {
      calls.add(candidate);
      if (first) {
        first = false;
        return true; // force a retry on the first candidate
      }
      return false;
    });
    expect(calls, hasLength(2));
    expect(slug, isNot(calls.first));
    expect(slug, matches(slugPattern));
    expect(slug, isNot(endsWith('_2')));
  });
}
