import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/views/widgets/rollup.dart';

class ExerciseDescriptionRollup extends StatelessWidget {
  const ExerciseDescriptionRollup({
    super.key,
    required this.exercise,
    required this.role,
    this.onTapSection,
  });

  final Exercise exercise;
  final AppUserRole role;

  /// Called with a section's (or the lead's) id when its block is tapped.
  /// Null disables taps entirely (every block renders without an
  /// `InkWell`).
  final ValueChanged<String>? onTapSection;

  /// The effective plan-variable map (ADR-0046) at [exercise]'s scope,
  /// optionally narrowed to [Exercise]'s — the active plan's declared
  /// values overlaid by [exercise]'s overrides, then [Exercise]'s. Empty
  /// when there is no active plan (defense-in-depth; this screen only
  /// ever renders inside one).
  Map<String, String> _overridesFor() {
    final plan = PlanService().activePlan;
    if (plan == null) return const {};
    return effectivePlanVariables(plan, exercise: exercise);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final overrides = _overridesFor();
    return Rollup(
      sections: [
        RollupSection(
          id: 'method',
          label: l10n.briefSectionExerciseMethod,
          text: exercise.methodMd,
          overrides: overrides,
        ),
        RollupSection(
          id: 'orderFormat',
          label: l10n.briefSectionExerciseOrderFormat,
          text: exercise.orderFormatMd,
          overrides: overrides,
        ),
        RollupSection(
          id: 'comms',
          label: l10n.briefSectionExerciseComms,
          text: exercise.commsMd,
          overrides: overrides,
        ),
        RollupSection(
          id: 'learningGoals',
          label: l10n.briefSectionExerciseLearningGoals,
          text: exercise.learningGoalsMd,
          overrides: overrides,
        ),
        RollupSection(
          id: 'trainingFocus',
          label: l10n.briefSectionExerciseTrainingFocus,
          text: exercise.trainingFocusMd,
          overrides: overrides,
        ),
        RollupSection(
          id: 'executionTips',
          label: l10n.briefSectionExerciseExecutionTips,
          text: exercise.executionTipsMd,
          overrides: overrides,
        ),
      ],
      onTapSection: onTapSection,
    );
  }
}
