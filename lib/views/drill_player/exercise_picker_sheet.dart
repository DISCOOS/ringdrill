import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/widgets/exercise_number_badge.dart';
import 'package:ringdrill/views/widgets/ringdrill_picker.dart';

/// Adaptive picker (ADR-0049) that lets the user swap which exercise the
/// surrounding context (CoordinatorScreen, station/team/role view, or
/// wide-layout docked bar) is bound to, before any exercise has actually
/// started. Resolves to the picked [Exercise], or `null` if the user
/// dismissed the picker without choosing.
///
/// Reads the list from [PlanService.activePlan]; the [current]
/// exercise is shown highlighted and tapping it just closes the picker
/// (no-op switch).
Future<Exercise?> showExercisePickerSheet(
  BuildContext context, {
  required Exercise current,
}) {
  final localizations = AppLocalizations.of(context)!;
  final plan = PlanService().activePlan;
  final exercises = plan?.exercises ?? const <Exercise>[];

  String label(Exercise exercise) => plan == null
      ? exercise.name
      : substitutePlanVariables(
          exercise.name,
          effectivePlanVariables(plan, exercise: exercise),
        );

  return showRingdrillPicker<Exercise>(
    context: context,
    title: localizations.pickerSelectExerciseTitle,
    items: exercises,
    itemBuilder: (context, exercise, onTap) {
      final theme = Theme.of(context);
      final isCurrent = exercise.uuid == current.uuid;
      final index = exercises.indexWhere((e) => e.uuid == exercise.uuid);
      final numberLabel = Numbering.exercise(
        plan?.exerciseNumberFormat ?? ExerciseNumberFormat.hash,
        index + 1,
      );
      final st = exercise.startTime.toMaterial();
      final et = exercise.endTime.toMaterial();
      return ListTile(
        leading: ExerciseNumberBadge(
          label: numberLabel,
          size: 36,
          highlight: isCurrent,
        ),
        title: Text(
          label(exercise),
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text('${st.formal()} – ${et.formal()}'),
        trailing: isCurrent
            ? Icon(Icons.check, color: theme.colorScheme.primary)
            : null,
        onTap: isCurrent ? () => Navigator.of(context).pop() : onTap,
      );
    },
    searchText: label,
    searchHint: localizations.pickerSearchHint,
  );
}
