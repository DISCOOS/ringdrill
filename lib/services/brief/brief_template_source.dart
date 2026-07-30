/// Where [BriefRenderer] gets its mustache template text.
///
/// Replaces the `AssetBundle` the renderer used to take (DESIGN-014's amendment
/// to ADR-0048). Rendering a brief is pure string work, but one `rootBundle`
/// reference made the whole brief layer unusable outside a Flutter app.
///
/// Free of `package:flutter/*` (AGENTS.md rule 7).
library;

import 'package:ringdrill/services/brief/brief_templates.g.dart';

/// Loads template source by asset path.
abstract class BriefTemplateSource {
  const BriefTemplateSource();

  /// The template at [assetPath], as text.
  ///
  /// Async because the original `AssetBundle.loadString` was, and because a
  /// future source (an org template fetched from the backend — the `scope` field
  /// on `BriefTemplate` anticipates it) will genuinely need to be.
  Future<String> load(String assetPath);
}

/// Thrown when a source has no template at the requested path.
class BriefTemplateNotFound implements Exception {
  const BriefTemplateNotFound(this.assetPath, this.available);

  final String assetPath;
  final Iterable<String> available;

  @override
  String toString() =>
      'BriefTemplateNotFound: $assetPath (have: ${available.join(', ')})';
}

/// The default: templates compiled into the binary.
///
/// `tools/generate_brief_templates.dart` bakes `assets/templates/*.mustache` into
/// `brief_templates.g.dart`. Reading from disk instead would work under
/// `dart run` but not from an installed CLI, which has no `assets/` directory
/// beside it — the same constraint that put the ARB messages in
/// `headless_labels.g.dart`.
class BakedBriefTemplateSource extends BriefTemplateSource {
  const BakedBriefTemplateSource();

  @override
  Future<String> load(String assetPath) async {
    final source = briefTemplateSources[assetPath];
    if (source == null) {
      throw BriefTemplateNotFound(assetPath, briefTemplateSources.keys);
    }
    return source;
  }
}

/// An in-memory source, for tests that render against a template of their own.
class MapBriefTemplateSource extends BriefTemplateSource {
  const MapBriefTemplateSource(this.templates);

  final Map<String, String> templates;

  @override
  Future<String> load(String assetPath) async {
    final source = templates[assetPath];
    if (source == null) {
      throw BriefTemplateNotFound(assetPath, templates.keys);
    }
    return source;
  }
}
