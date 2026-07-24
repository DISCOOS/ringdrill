import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/views/widgets/rollup.dart';

class RolePlayDescriptionRollup extends StatelessWidget {
  const RolePlayDescriptionRollup({
    super.key,
    required this.exercise,
    required this.station,
    required this.rolePlay,
    required this.role,
    this.onTapSection,
  });

  final Exercise exercise;
  final Station? station;
  final RolePlay rolePlay;
  final AppUserRole role;

  /// Called with a section's (or the lead's) id when its block is tapped.
  /// Null disables taps entirely (every block renders without an
  /// `InkWell`).
  final ValueChanged<String>? onTapSection;

  /// The effective plan-variable map (ADR-0046) at [exercise]'s scope,
  /// optionally narrowed to [station]'s — the active plan's declared
  /// values overlaid by [exercise]'s overrides, then [station]'s. Empty
  /// when there is no active plan (defense-in-depth; this screen only
  /// ever renders inside one).
  Map<String, String> _overridesFor() {
    final plan = PlanService().activePlan;
    if (plan == null) return const {};
    return effectivePlanVariables(
      plan,
      exercise: exercise,
      station: station,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final overrides = _overridesFor();
    return Rollup(
      sections: [
        RollupSection(
          id: 'description',
          text: rolePlay.description,
          overrides: overrides,
        ),
        RollupSection(
          id: 'background',
          text: rolePlay.background,
          label: l10n.roleBackground,
          overrides: overrides,
        ),
        RollupSection(
          id: 'behaviour',
          label: l10n.roleBehavior,
          text: rolePlay.behavior,
          overrides: overrides,
        ),
        RollupSection(
          id: 'props',
          label: l10n.roleProps,
          text: rolePlay.propsMd,
          overrides: overrides,
        ),
      ],
      onTapSection: onTapSection,
    );
  }
}
