import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/views/widgets/exercise_description_rollup.dart';
import 'package:ringdrill/views/widgets/rollup.dart';

/// The exercise's descriptive markdown, as a titled card.
///
/// The exercise-level counterpart to `StationDescriptionCard`, for the
/// coordinator's Info segment. Before this, an exercise's method, order format,
/// comms, learning goals, training focus and execution tips were only reachable
/// from the brief or the editor — nothing on the coordinator surfaced them.
///
/// Shares its section list with [ExerciseDescriptionRollup] (the bare rollup
/// inside the Plan tab's expanded ExerciseCard) via
/// [exerciseDescriptionSections], so the two cannot drift. [Rollup] omits empty
/// sections, so a sparsely-filled exercise still renders a compact card.
class ExerciseDescriptionCard extends StatelessWidget {
  const ExerciseDescriptionCard({
    super.key,
    required this.exercise,
    this.onTapSection,
    this.trailing,
  });

  final Exercise exercise;

  /// Called with a section's id when its block is tapped — the coordinator
  /// wires this to the exercise editor, opened at the matching section. Null
  /// disables tap-to-edit entirely (every block renders without an `InkWell`).
  final ValueChanged<String>? onTapSection;

  /// Header action, shown before the collapse chevron — the coordinator's
  /// copy-exercise button lives here rather than floating over the body.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return RollupCard(
      sectionId: 'description',
      icon: Icons.description,
      title: l10n.exerciseDescriptionCardTitle,
      sections: exerciseDescriptionSections(
        l10n,
        exercise,
        exerciseDescriptionOverrides(exercise),
      ),
      onTapSection: onTapSection,
      trailing: trailing,
    );
  }
}
