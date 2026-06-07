/// A registered brief template. Identified by [id]. Loaded from [assetPath]
/// via the Flutter asset bundle.
///
/// A template id names a *family*; each family has one or more locale
/// variants (e.g. `nb`, `en`) that share the same [id] but differ in
/// [locale] and [assetPath]. See [TemplateRegistry.resolve].
class BriefTemplate {
  const BriefTemplate({
    required this.id,
    required this.version,
    required this.locale,
    required this.scope,
    required this.assetPath,
  });

  final String id;
  final int version;
  final String locale; // BCP 47 tag, e.g. 'nb' or 'en'
  final String scope; // 'system' for v1; 'org' and 'team' come later
  final String assetPath; // path under assets/, used by rootBundle.loadString
}

/// A template family: all locale variants registered under one [BriefTemplate.id],
/// plus the [defaultLocale] used when no variant matches the requested locale.
class _TemplateFamily {
  const _TemplateFamily({required this.defaultLocale, required this.variants});

  /// Language subtag to fall back to, e.g. `nb`. Must be a key in [variants].
  final String defaultLocale;

  /// Variants keyed by language subtag (lowercased), e.g. `nb`, `en`.
  final Map<String, BriefTemplate> variants;

  BriefTemplate get fallback => variants[defaultLocale]!;

  /// Picks the variant matching [locale]'s language subtag, or [fallback]
  /// when [locale] is null or unknown.
  BriefTemplate forLocale(String? locale) {
    if (locale == null) return fallback;
    return variants[_languageOf(locale)] ?? fallback;
  }
}

/// Extracts the lowercased language subtag from a BCP 47 / ICU locale tag:
/// `en` -> `en`, `en_US` -> `en`, `nb-NO` -> `nb`.
String _languageOf(String locale) {
  final tag = locale.trim().toLowerCase();
  final sep = tag.indexOf(RegExp(r'[-_]'));
  return sep < 0 ? tag : tag.substring(0, sep);
}

/// In-memory registry of brief templates. v1 has a single family
/// (`ringdrill-standard-v1`) with `nb` and `en` variants. The registry is the
/// only thing the renderer needs to know about template discovery; callers
/// always pass a [BriefTemplate.id], never a path.
class TemplateRegistry {
  TemplateRegistry._(this._families);

  static final TemplateRegistry instance = TemplateRegistry._({
    'ringdrill-standard-v1': const _TemplateFamily(
      defaultLocale: 'nb',
      variants: {
        'nb': BriefTemplate(
          id: 'ringdrill-standard-v1',
          version: 1,
          locale: 'nb',
          scope: 'system',
          assetPath: 'assets/templates/ringdrill-standard-v1.nb.md.mustache',
        ),
        'en': BriefTemplate(
          id: 'ringdrill-standard-v1',
          version: 1,
          locale: 'en',
          scope: 'system',
          assetPath: 'assets/templates/ringdrill-standard-v1.en.md.mustache',
        ),
      },
    ),
  });

  final Map<String, _TemplateFamily> _families;

  static const String _defaultFamilyId = 'ringdrill-standard-v1';

  /// The default-locale variant of a family by [id], or null if unknown.
  BriefTemplate? get(String id) => _families[id]?.fallback;

  /// The default-locale variant of the system default family.
  BriefTemplate get systemDefault => _families[_defaultFamilyId]!.fallback;

  /// Resolves the template for a given [templateId] and [locale]. Falls back
  /// to the system default family when [templateId] is null or unknown, and
  /// to the family's default locale when [locale] is null or has no matching
  /// variant. When team/org defaults arrive, they are consulted here before
  /// the system default.
  BriefTemplate resolve(String? templateId, [String? locale]) {
    final family = _families[templateId] ?? _families[_defaultFamilyId]!;
    return family.forLocale(locale);
  }
}
