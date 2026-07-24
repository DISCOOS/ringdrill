import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/services/brief/brief_renderer.dart';

/// Renders a snippet of plan-scope markdown — `Plan.briefIntroMd`,
/// `commsMd` or `beforeRoundMd` — resolved against [plan]:
/// `{{var.<name>}}` tokens and `{{plan.name}}`/`{{plan.description}}`
/// cross-references are substituted before display, the same way
/// `BriefRenderer.render` resolves them in the full brief.
///
/// This is the sanctioned way to show one of those fields outside the full
/// brief. Reading the raw model field straight into a `Text` widget skips
/// resolution — a declared variable or cross-reference then shows up as a
/// literal `{{...}}` token instead of its value (this is exactly what
/// happened to the Plan view's overview card before this widget
/// existed). If a caller needs to post-process the text further (e.g.
/// extracting a preview paragraph), call [resolve] directly and build its
/// own `Text` from the result — resolution must still happen first, before
/// any such transform, never after.
class ResolvedMarkdownText extends StatelessWidget {
  const ResolvedMarkdownText({
    super.key,
    required this.plan,
    required this.content,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final Plan plan;

  /// Raw markdown, e.g. `plan.briefIntroMd`. Renders nothing when null
  /// or empty (after resolution).
  final String? content;

  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Resolves [content] against [plan] — the single entry point both
  /// this widget and any caller that needs the resolved string (not just a
  /// widget) should use.
  static String resolve(Plan plan, String content, AppLocalizations l10n) =>
      BriefRenderer.resolvePlanScopeText(plan, content, l10n);

  @override
  Widget build(BuildContext context) {
    final raw = content;
    if (raw == null || raw.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final resolved = resolve(plan, raw, l10n);
    if (resolved.isEmpty) return const SizedBox.shrink();
    return Text(resolved, style: style, maxLines: maxLines, overflow: overflow);
  }
}
