import 'package:flutter/widgets.dart';
// normalizeLanguageSubtag / languageOfLocaleTag live in language_tags.dart, which
// is free of Flutter so the brief layer can reach them headlessly (DESIGN-014).
// Re-exported here so existing callers and tests keep one import.
export 'package:ringdrill/utils/language_tags.dart';

import 'package:ringdrill/utils/language_tags.dart';

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
