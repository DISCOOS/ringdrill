/// Language-subtag normalization, without Flutter.
///
/// Split out of `locale_utils.dart`, which imports `package:flutter/widgets.dart`
/// for the `Locale` type in `resolveSupportedLocale`. These two functions never
/// needed it, but `template_registry.dart` calls [languageOfLocaleTag] — and the
/// registry is in the brief layer, which the CLI's `render` reaches (DESIGN-014).
/// One `Locale` in an unrelated function was enough to make the whole brief layer
/// un-runnable headlessly.
///
/// Free of `package:flutter/*` (AGENTS.md rule 7).
library;

/// Map legacy / deprecated Norwegian language subtags onto Bokmål.
///
/// `Intl.getCurrentLocale()` and Flutter's `Locale.languageCode` can still
/// report the legacy ISO-639-1 Norwegian code `no` (and the seldom-used
/// `nn`) on some Android builds. The app only ships `nb`, so we collapse
/// both onto Bokmål; everything else passes through lowercased.
String normalizeLanguageSubtag(String code) {
  final lower = code.toLowerCase();
  if (lower == 'no' || lower == 'nn') return 'nb';
  return lower;
}

/// Lowercased, legacy-aware language subtag from any BCP 47 / ICU locale
/// string: `no_NO` -> `nb`, `en-US` -> `en`, `nb` -> `nb`. Returns `'en'`
/// for empty input.
String languageOfLocaleTag(String tag) {
  final clean = tag.trim();
  if (clean.isEmpty) return 'en';
  final sep = clean.indexOf(RegExp(r'[-_]'));
  final lang = sep < 0 ? clean : clean.substring(0, sep);
  return normalizeLanguageSubtag(lang);
}
