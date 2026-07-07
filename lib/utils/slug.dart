/// Derives a stable `^[a-z][a-z0-9_]*$` reference from a display label/name
/// (ADR-0047: `Location.slug`/`Person.slug`) — DESIGN-009 follow-up 3b
/// removed the manual reference field; the reference is generated once at
/// creation and never changes when the display text is edited afterward.
///
/// Pure and Flutter-free, like `plan_variables.dart`.
library;

/// Common Norwegian letters folded to their closest ASCII equivalent before
/// slugifying, so "Bosted" stays readable-ish rather than losing every
/// æ/ø/å to an underscore.
const _foldedLetters = {
  'æ': 'ae',
  'ø': 'o',
  'å': 'a',
};

final _nonSlugChars = RegExp(r'[^a-z0-9]+');
final _leadingOrTrailingUnderscore = RegExp(r'^_+|_+$');
final _startsWithLetter = RegExp(r'^[a-z]');

/// Generates a reference for [input] that satisfies the slug rule and for
/// which [isTaken] returns `false`. Ties are broken with a `_2`, `_3`, ...
/// suffix. An input with no usable letters/digits (e.g. empty, or entirely
/// punctuation) falls back to `x` before suffixing, so the result always
/// matches `^[a-z][a-z0-9_]*$`.
String generateSlug(String input, bool Function(String candidate) isTaken) {
  var folded = input.toLowerCase();
  for (final entry in _foldedLetters.entries) {
    folded = folded.replaceAll(entry.key, entry.value);
  }
  final normalized = folded
      .replaceAll(_nonSlugChars, '_')
      .replaceAll(_leadingOrTrailingUnderscore, '');
  final base = normalized.isEmpty
      ? 'x'
      : (_startsWithLetter.hasMatch(normalized) ? normalized : 'x_$normalized');

  if (!isTaken(base)) return base;
  var suffix = 2;
  while (isTaken('${base}_$suffix')) {
    suffix++;
  }
  return '${base}_$suffix';
}
