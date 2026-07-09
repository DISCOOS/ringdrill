/// Generates a random `^[a-z][a-z0-9_]*$` reference (ADR-0047:
/// `Location.slug`/`Person.slug`) — DESIGN-009 follow-up 4h: a reference
/// derived from any editable field drifts out of sync the moment that field
/// changes, so it is generated from nothing and never rewritten.
///
/// Pure and Flutter-free, like `plan_variables.dart`.
library;

import 'package:nanoid/nanoid.dart';

const _letters = 'abcdefghijklmnopqrstuvwxyz';
const _alphanumeric = 'abcdefghijklmnopqrstuvwxyz0123456789';

/// Length of the random part after the mandatory leading letter, so the
/// whole reference is ~6 characters.
const _randomSuffixLength = 5;

/// Generates a short random reference — a leading `[a-z]` letter followed by
/// [_randomSuffixLength] characters from `[a-z0-9]` — for which [isTaken]
/// returns `false`. Regenerated (not suffixed) on collision: the reference
/// carries no meaning, so there is nothing for a suffix to preserve.
String randomSlug(bool Function(String candidate) isTaken) {
  String candidate;
  do {
    candidate =
        customAlphabet(_letters, 1) +
        customAlphabet(_alphanumeric, _randomSuffixLength);
  } while (isTaken(candidate));
  return candidate;
}
