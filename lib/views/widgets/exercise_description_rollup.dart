import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/views/widgets/rollup.dart';

/// The exercise's descriptive markdown sections, in the order the brief
/// presents them.
///
/// Shared by [ExerciseDescriptionRollup] (bare, inside the Plan tab's expanded
/// ExerciseCard) and `ExerciseDescriptionCard` (chromed, in the coordinator's
/// Info segment) so the two surfaces cannot drift apart. Unlike a station,
/// an exercise has no plain `description` lead field and no director-gated
/// section — every entry here is an ordinary markdown field.
List<RollupSection> exerciseDescriptionSections(
  AppLocalizations l10n,
  Exercise exercise,
  Map<String, String> overrides,
) => [
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
];

/// The effective plan-variable map (ADR-0046) at [exercise]'s scope. Empty when
/// there is no active plan (defense-in-depth; these surfaces only ever render
/// inside one).
Map<String, String> exerciseDescriptionOverrides(Exercise exercise) {
  final plan = PlanService().activePlan;
  if (plan == null) return const {};
  return effectivePlanVariables(plan, exercise: exercise);
}

class ExerciseDescriptionRollup extends StatelessWidget {
  const ExerciseDescriptionRollup({
    super.key,
    required this.exercise,
    required this.role,
    this.onTapSection,
  });

  final Exercise exercise;
  final StaffRole role;

  /// Called with a section's (or the lead's) id when its block is tapped.
  /// Null disables taps entirely (every block renders without an
  /// `InkWell`).
  final ValueChanged<String>? onTapSection;

  @override
  Widget build(BuildContext context) {
    return Rollup(
      sections: exerciseDescriptionSections(
        AppLocalizations.of(context)!,
        exercise,
        exerciseDescriptionOverrides(exercise),
      ),
      onTapSection: onTapSection,
    );
  }
}
