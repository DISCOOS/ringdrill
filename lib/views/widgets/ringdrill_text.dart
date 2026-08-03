import 'package:flutter/widgets.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/services/brief/field_resolver.dart' as resolver;
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/views/widgets/brief_markdown.dart';
import 'package:ringdrill/views/widgets/brief_theme.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/plan_text.dart';
import 'package:ringdrill/views/widgets/resolve_scoped_field.dart';

/// Read-only counterpart to [Text] that resolves the full DESIGN-010 token
/// pipeline before rendering — `{{var.<name>}}` (ADR-0046), plus whatever
/// `{{plan.*}}`/`{{exercise.*}}`/`{{station.*}}`/`{{roleplay.*}}`
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
/// Reads [PlanScope.maybeOf], not [PlanScope.of]: a surface outside a plan
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
  }) : _rich = false,
       plan = null;

  /// Markdown rendering (copy chips) — description bodies and scenario prose.
  const RingDrillText.rich(this.text, {super.key, this.overrides = const {}})
    : _rich = true,
      plan = null,
      style = null,
      maxLines = null,
      overflow = null,
      textAlign = null;

  /// Plain rendering resolved against **[plan]'s own** scope, ignoring whatever
  /// [PlanScope] the tree offers.
  ///
  /// For a surface that shows text belonging to a plan other than the active one
  /// — the library list, the plan pickers — where the ambient scope is the *wrong*
  /// plan's. Resolving those against it would substitute one plan's variable
  /// values into another plan's name: worse than the literal token, because it
  /// looks correct.
  ///
  /// Also the right constructor for a surface with no scope at all to inherit
  /// (a dialog or sheet mounted on the Navigator's overlay), where [plain] would
  /// return the text verbatim.
  ///
  /// **Plain rendering only.** This class really has two independent axes —
  /// rendering mode (plain / rich) and resolve target (ambient scope / named
  /// plan) — and this constructor fixes the first while varying the second, which
  /// is an asymmetry rather than a design: every caller so far is a list-row
  /// *title*, and no cross-plan surface renders a plan's prose. If one appears
  /// (a description preview in the library or a plan picker), add a `richForPlan`
  /// beside this rather than passing markdown here, where it would show its raw
  /// `**markup**`. The resolve step is identical; only the returned widget
  /// differs.
  const RingDrillText.forPlan(
    this.plan,
    this.text, {
    super.key,
    this.overrides = const {},
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  }) : _rich = false;

  final String text;

  /// Non-null only for [RingDrillText.forPlan] — the plan whose variables and
  /// facets resolve [text], instead of the ancestor [PlanScope].
  final Plan? plan;

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
    final forPlan = plan;
    if (forPlan != null) {
      // Named plan wins over the ambient scope: see RingDrillText.forPlan.
      resolved = l10n == null
          ? substitutePlanVariables(text, effectivePlanVariables(forPlan))
          : resolvePlanText(forPlan, text, l10n);
    } else if (scope == null) {
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
    // ringdrill://chip link into a title or list row.
    return Text(
      resolver.stripChipMarkup(resolved),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
