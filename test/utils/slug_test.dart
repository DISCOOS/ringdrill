import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/utils/slug.dart';

/// DESIGN-009 follow-up 3b — `generateSlug` derives a
/// `^[a-z][a-z0-9_]*$` reference from a display label/name, breaking ties
/// with a numeric suffix so callers never have to type one manually.
void main() {
  final slugPattern = RegExp(r'^[a-z][a-z0-9_]*$');

  test('lowercases and joins words with underscores', () {
    expect(generateSlug('Sist kjente posisjon', (_) => false), 'sist_kjente_posisjon');
  });

  test('folds common Norwegian letters to ASCII', () {
    expect(generateSlug('Bosted på Gården', (_) => false), 'bosted_pa_garden');
  });

  test('falls back to x for input with no usable letters/digits', () {
    expect(generateSlug('', (_) => false), 'x');
    expect(generateSlug('!!!', (_) => false), 'x');
  });

  test('prefixes with x_ when the input starts with a digit', () {
    final slug = generateSlug('39 år', (_) => false);
    expect(slug, matches(slugPattern));
    expect(slug, startsWith('x_'));
  });

  test('suffixes _2, _3, ... until isTaken returns false', () {
    final taken = {'anne', 'anne_2'};
    expect(generateSlug('Anne', taken.contains), 'anne_3');
  });

  test('two same-named entries get distinct references', () {
    final existing = <String>{};
    final first = generateSlug('Anne', existing.contains);
    existing.add(first);
    final second = generateSlug('Anne', existing.contains);

    expect(first, isNot(second));
    expect(first, matches(slugPattern));
    expect(second, matches(slugPattern));
  });
}
