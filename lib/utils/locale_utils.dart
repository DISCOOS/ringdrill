import 'package:flutter/widgets.dart';

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

/// Pick the supported [Locale] best matching the device locale list.
///
/// Walks [deviceLocales] in order, normalises each language subtag (so
/// `no_NO` is treated as `nb`), and returns the first [supportedLocales]
/// entry that matches the language. Falls back to the first supported
/// locale when nothing matches.
///
/// Suitable for use as `MaterialApp.localeListResolutionCallback`.
Locale resolveSupportedLocale(
  List<Locale>? deviceLocales,
  Iterable<Locale> supportedLocales,
) {
  final supported = supportedLocales.toList();
  if (deviceLocales != null) {
    for (final raw in deviceLocales) {
      final lang = normalizeLanguageSubtag(raw.languageCode);
      for (final candidate in supported) {
        if (candidate.languageCode == lang) return candidate;
      }
    }
  }
  return supported.first;
}
