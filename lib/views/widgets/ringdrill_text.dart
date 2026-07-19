import 'package:flutter/widgets.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/resolve_scoped_field.dart';

/// Read-only counterpart to [Text] that resolves the full DESIGN-010 token
/// pipeline before rendering — `{{var.<name>}}` (ADR-0046), plus whatever
/// `{{program.*}}`/`{{exercise.*}}`/`{{station.*}}`/`{{roleplay.*}}`
/// cross-references the ancestor scopes offer — the display-surface half of
/// DESIGN-008's token-aware fields, with no chip rendering or insertion menu
/// (that is [RingDrillTextField]/[RingDrillTextArea]'s job for editing).
/// Delegates to [resolveScopedField] (ADR-0048), the same cascade the
/// per-section preview and rollup already read, so a surface using this
/// widget never falls behind the brief.
///
/// Reads [PlanScope.maybeOf], not [PlanScope.of]: a surface outside a
/// program context (e.g. a global list with no active plan resolved yet)
/// has no scope to read, and must degrade to plain, unresolved [text] rather
/// than throw. Likewise a missing `ExerciseScope`/`StationScope` simply
/// leaves that level's cross-references unresolved (ADR-0048) — never a
/// crash. [overrides] shadows a declared value the same way an
/// [Exercise]/[Station]'s `variableOverrides` does for [BriefRenderer] and
/// the token-aware fields — omit it where the entity has none (e.g. a
/// program or roleplay name). [roleplayFacets] is this text's own
/// roleplay's `roleplay.*` facets (DESIGN-010 folds these into the field's
/// context rather than a scope) — omit it outside a roleplay display.
///
/// An undeclared token is left as literal `{{var.name}}` text
/// (`substitutePlanVariables`'s default when no `onUnknown` is given) —
/// visible enough to flag a broken reference without the noisier
/// placeholder the brief renderer substitutes server-side.
class RingDrillText extends StatelessWidget {
  const RingDrillText(
    this.text, {
    super.key,
    this.overrides = const {},
    this.roleplayFacets,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final Map<String, String> overrides;
  final Map<String, dynamic>? roleplayFacets;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

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
          resolveScopedField(
            context,
            text,
            overrides: overrides,
            roleplayFacets: roleplayFacets,
          ) ??
          text;
    }
    // `resolveScopedField` emits markdown — including inline-code chips for
    // positions/addresses/phones (backtick-wrapped). RingDrillText renders
    // plain text (titles, subtitles, list rows), where a copy pill has no
    // place and a literal backtick would leak into the UI. Strip the
    // inline-code markers so those values read as plain text here; the chip
    // only renders on the markdown surfaces (NarrativeRollupCard, brief).
    return Text(
      resolved.replaceAll('`', ''),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
