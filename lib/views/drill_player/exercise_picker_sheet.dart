import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/widgets/exercise_number_badge.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';

/// Bottom-sheet picker that lets the user swap which exercise the
/// surrounding context (CoordinatorScreen, station/team/role view, or
/// wide-layout docked bar) is bound to, before any exercise has actually
/// started. Resolves to the picked [Exercise], or `null` if the user
/// dismissed the sheet without choosing.
///
/// Reads the list from [ProgramService.activeProgram]; the [current]
/// exercise is shown highlighted and tapping it just closes the sheet
/// (no-op switch).
Future<Exercise?> showExercisePickerSheet(
  BuildContext context, {
  required Exercise current,
}) {
  return showRingdrillActionSheet<Exercise>(
    context: context,
    builder: (_) => _ExercisePickerBody(current: current),
  );
}

class _ExercisePickerBody extends StatelessWidget {
  const _ExercisePickerBody({required this.current});

  final Exercise current;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final program = ProgramService().activeProgram;
    final exercises = program?.exercises ?? const <Exercise>[];
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            localizations.exercisePickerTitle,
            style: theme.textTheme.titleMedium,
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              final isCurrent = exercise.uuid == current.uuid;
              final label = Numbering.exercise(
                program?.exerciseNumberFormat ?? ExerciseNumberFormat.hash,
                index + 1,
              );
              final st = exercise.startTime.toMaterial();
              final et = exercise.endTime.toMaterial();
              return ListTile(
                leading: ExerciseNumberBadge(
                  label: label,
                  size: 36,
                  highlight: isCurrent,
                ),
                title: Text(
                  exercise.name,
                  style: TextStyle(
                    fontWeight: isCurrent
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text('${st.formal()} – ${et.formal()}'),
                trailing: isCurrent
                    ? Icon(Icons.check, color: theme.colorScheme.primary)
                    : null,
                onTap: () =>
                    Navigator.of(context).pop(isCurrent ? null : exercise),
              );
            },
          ),
        ),
      ],
    );
  }
}
