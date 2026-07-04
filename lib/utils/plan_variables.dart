/// Canonical `{{var.<name>}}` matching and substitution (ADR-0046) — the
/// single source for the token shape. Previously duplicated by hand across
/// `BriefRenderer`, `TokenTextEditingController` and
/// `plan_variable_refs.dart`; those now import this instead.
///
/// Pure and Flutter-free: `BriefRenderer` (and, transitively, the CLI at
/// `bin/ringdrill.dart`) depends on this, so it must never import
/// `package:flutter/*`.
library;

/// Matches `{{var.<name>}}`, tolerating inner whitespace around the name.
/// Capture group 1 is the name. A declared variable name (ADR-0046) starts
/// with a lowercase letter, then lowercase letters/digits/underscores —
/// see `lib/views/widgets/variables_section.dart`'s `_slugPattern` for the
/// matching authoring-time validation rule (a distinct concern: validating
/// a name being typed, not matching an existing token).
final planVariableTokenPattern = RegExp(
  r'\{\{\s*var\.([a-z][a-z0-9_]*)\s*\}\}',
);

/// Matches `{{var.<name>}}` for one specific [name], whitespace-tolerant —
/// for counting or rewriting references to a single declared variable
/// (`plan_variable_refs.dart`), rather than capturing an arbitrary name.
RegExp planVariableTokenPatternFor(String name) =>
    RegExp('\\{\\{\\s*var\\.${RegExp.escape(name)}\\s*\\}\\}');

/// Replaces every `{{var.<name>}}` token in [text] with its value in
/// [vars]. For a name that is not a key of [vars] (undeclared), calls
/// [onUnknown] with the name and substitutes its result; if [onUnknown] is
/// omitted, the token is left as literal text.
String substitutePlanVariables(
  String text,
  Map<String, String> vars, {
  String Function(String name)? onUnknown,
}) {
  return text.replaceAllMapped(planVariableTokenPattern, (match) {
    final name = match.group(1)!;
    final value = vars[name];
    if (value != null) return value;
    return onUnknown == null ? match.group(0)! : onUnknown(name);
  });
}
