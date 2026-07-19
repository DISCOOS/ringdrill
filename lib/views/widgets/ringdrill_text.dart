import 'package:flutter/widgets.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/views/widgets/brief_markdown.dart';
import 'package:ringdrill/views/widgets/brief_theme.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/resolve_scoped_field.dart';

/// Matches an (ADR-0050) `rdchip:` action-chip link — `[display](rdchip:…)`
/// — so [RingDrillText.plain] can strip it down to its display text, the
/// same way it strips a backtick copy chip down to its bare value. The
/// `rdchip:` scheme must never leak into a plain surface as raw markup.
final _rdchipLinkPattern = RegExp(r'\[([^\]]*)\]\(rdchip:[^)]*\)');

/// Strips chip markup a plain surface never wants to show: an `rdchip:`
/// action-chip link collapses to its display text, then any remaining
/// backtick copy-chip markers are dropped.
String _stripChipMarkup(String text) => text
    .replaceAllMapped(_rdchipLinkPattern, (m) => m.group(1) ?? '')
    .replaceAll('`', '');

/// Read-only counterpart to [Text] that resolves the full DESIGN-010 token
/// pipeline before rendering — `{{var.<name>}}` (ADR-0046), plus whatever
/// `{{program.*}}`/`{{exercise.*}}`/`{{station.*}}`/`{{roleplay.*}}`
/// cross-references the ancestor scopes offer — the display-surface half of
/// DESIGN-008's token-aware fields. Delegates to [resolveScopedField]
/// (ADR-0048), the same cascade the per-section preview and rollup already
/// read, so a surface using this widget never falls behind the brief.
///
/// Two rendering modes, chosen by constructor:
///
/// * [RingDrillText.plain] — one [Text]. The resolver emits markdown
///   (including inline-code chips for positions/addresses/phones); plain
///   surfaces (titles, subtitles, list rows, names) strip those markers so a
///   copy pill never appears where it makes no sense.
/// * [RingDrillText.rich] — renders the resolved markdown via
///   [BriefMarkdownBlock], so positions/addresses/phones become copy chips and
///   the prose reads exactly as it does in the brief / detail card. For
///   description bodies and scenario prose.
///
/// Reads [PlanScope.maybeOf], not [PlanScope.of]: a surface outside a program
/// context degrades to plain, unresolved [text] rather than throwing. Likewise
/// a missing `ExerciseScope`/`StationScope` simply leaves that level's
/// cross-references unresolved (ADR-0048) — never a crash. `{{roleplay.*}}`
/// references read from a `RoleplayScope` ancestor when present. [overrides]
/// shadows a declared value the same way an [Exercise]/[Station]'s
/// `variableOverrides` does.
class RingDrillText extends StatelessWidget {
  /// Plain rendering — titles, labels, names, list rows.
  const RingDrillText.plain(
    this.text, {
    super.key,
    this.overrides = const {},
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  }) : _rich = false;

  /// Markdown rendering (copy chips) — description bodies and scenario prose.
  const RingDrillText.rich(this.text, {super.key, this.overrides = const {}})
    : _rich = true,
      style = null,
      maxLines = null,
      overflow = null,
      textAlign = null;

  final String text;
  final Map<String, String> overrides;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool _rich;

  @override
  Widget build(BuildContext context) {
    final scope = PlanScope.maybeOf(context);
    // AppLocalizations can be absent in a bare test harness; the resolver
    // needs it (typed variable formatting, cross-reference placeholders), so
    // degrade to the plain string substitution without.
    final l10n = AppLocalizations.of(context);
    final String resolved;
    if (scope == null) {
      resolved = text;
    } else if (l10n == null) {
      resolved = substitutePlanVariables(text, {
        for (final v in scope.variables) v.name: overrides[v.name] ?? v.value,
      });
    } else {
      resolved =
          resolveScopedField(context, text, overrides: overrides) ?? text;
    }

    if (_rich) {
      // Markdown: positions/addresses/phones render as copy chips, matching
      // the brief / detail card.
      return BriefMarkdownBlock(
        data: resolved,
        theme: BriefTheme.of(context),
        gutter: 0,
      );
    }

    // Plain: strip chip markup so a resolved coordinate/address/phone reads
    // as plain text rather than leaking a literal backtick or an (ADR-0050)
    // rdchip: link into a title or list row.
    return Text(
      _stripChipMarkup(resolved),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
