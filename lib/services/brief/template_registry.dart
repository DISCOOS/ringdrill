/// A registered brief template. Identified by [id]. Loaded from [assetPath]
/// via the Flutter asset bundle.
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
  final String locale; // BCP 47 tag, 'nb' for v1
  final String scope; // 'system' for v1; 'org' and 'team' come later
  final String assetPath; // path under assets/, used by rootBundle.loadString
}

/// In-memory registry of brief templates. v1 has exactly one entry. The
/// registry is the only thing the renderer needs to know about template
/// discovery; callers always pass a [BriefTemplate.id], never a path.
class TemplateRegistry {
  TemplateRegistry._(this._templates);

  static final TemplateRegistry instance = TemplateRegistry._({
    'ringdrill-standard-v1': const BriefTemplate(
      id: 'ringdrill-standard-v1',
      version: 1,
      locale: 'nb',
      scope: 'system',
      assetPath: 'assets/templates/ringdrill-standard-v1.nb.md.mustache',
    ),
  });

  final Map<String, BriefTemplate> _templates;

  BriefTemplate? get(String id) => _templates[id];

  BriefTemplate get systemDefault => _templates['ringdrill-standard-v1']!;

  /// Resolves the template for [exercise]. Falls back to [systemDefault]
  /// when [Exercise.templateId] is null or unknown. When team/org defaults
  /// arrive, they are consulted here before the system default.
  BriefTemplate resolve(String? templateId) {
    if (templateId == null) return systemDefault;
    return _templates[templateId] ?? systemDefault;
  }
}
