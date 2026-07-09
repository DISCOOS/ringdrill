import 'package:flutter/widgets.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/utils/variable_values.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/variable_type_labels.dart';

/// Read-only counterpart to [Text] that resolves `{{var.<name>}}` tokens
/// (ADR-0046) before rendering — the display-surface half of DESIGN-008's
/// token-aware fields, with no chip rendering or insertion menu (that is
/// [RingDrillTextField]/[RingDrillTextArea]'s job for editing).
///
/// Reads [PlanScope.maybeOf], not [PlanScope.of]: a surface outside a
/// program context (e.g. a global list with no active plan resolved yet)
/// has no scope to read, and must degrade to plain, unresolved [text] rather
/// than throw. [overrides] shadows a declared value the same way an
/// [Exercise]/[Station]'s `variableOverrides` does for [BriefRenderer] and
/// the token-aware fields — omit it where the entity has none (e.g. a
/// program or roleplay name).
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
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final Map<String, String> overrides;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final scope = PlanScope.maybeOf(context);
    // AppLocalizations can be absent in a bare test harness; the typed
    // formatting (localized dates, duration units — DESIGN-008 follow-up
    // 11) needs it, so degrade to the plain string substitution without.
    final l10n = AppLocalizations.of(context);
    final String resolved;
    if (scope == null) {
      resolved = text;
    } else if (l10n == null) {
      resolved = substitutePlanVariables(text, {
        for (final v in scope.variables) v.name: overrides[v.name] ?? v.value,
      });
    } else {
      resolved = resolveTypedPlanVariables(
        text,
        {
          for (final v in scope.variables)
            v.name: applyVariableOverride(v, overrides[v.name]),
        },
        format: variableFormatOf(l10n),
      );
    }
    return Text(
      resolved,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
