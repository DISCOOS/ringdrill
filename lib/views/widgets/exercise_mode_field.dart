/// The exercise's conduct mode as a form field (ADR-0062).
///
/// Deliberately not a new control. It is the pattern the forms already use for
/// "choose one, and show what is chosen": a `ListTile` carrying the current value,
/// opening [showRingdrillPicker] (ADR-0049) — the app's bottom-sheet-on-compact,
/// dialog-on-wide picker — with one `ListTile` per option. The station picker in the
/// roleplay editor reads the same way, which is the point: an author who has chosen a
/// station has already met this.
///
/// The mode's label, description and icon live here rather than at the two call
/// sites, so the row and the picker cannot describe the same mode differently.
library;

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/views/widgets/ringdrill_picker.dart';

/// What the UI calls [mode].
///
/// `ring` reuses `briefRingRoute` — the string the brief already prints for the same
/// thing — rather than a second wording for one concept. "Ring Drill" is deliberately
/// not it: that names the whole domain, not one mode of one exercise.
String exerciseModeLabel(AppLocalizations l10n, ExerciseMode mode) =>
    switch (mode) {
      ExerciseMode.ring => l10n.briefRingRoute,
      ExerciseMode.together => l10n.exerciseModeTogether,
      ExerciseMode.split => l10n.exerciseModeSplit,
    };

/// One sentence saying what the mode does. The app has to teach this, so the
/// sentence is the design rather than an afterthought.
String exerciseModeDescription(AppLocalizations l10n, ExerciseMode mode) =>
    switch (mode) {
      ExerciseMode.ring => l10n.exerciseModeRingDescription,
      ExerciseMode.together => l10n.exerciseModeTogetherDescription,
      ExerciseMode.split => l10n.exerciseModeSplitDescription,
    };

IconData exerciseModeIcon(ExerciseMode mode) => switch (mode) {
  ExerciseMode.ring => Icons.rotate_right,
  ExerciseMode.together => Icons.groups_outlined,
  ExerciseMode.split => Icons.call_split,
};

/// The form row: current mode, its sentence, and a tap that opens the picker.
class ExerciseModeField extends StatelessWidget {
  const ExerciseModeField({
    super.key,
    required this.mode,
    required this.onChanged,
    this.enabled = true,
  });

  final ExerciseMode mode;

  /// Called with the chosen mode, and only when it differs — so a caller that has
  /// to confirm a destructive change (leaving `split` discards its groups) is not
  /// asked to re-check whether anything changed.
  final ValueChanged<ExerciseMode> onChanged;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(exerciseModeIcon(mode)),
      title: Text(
        l10n.exerciseMode,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      subtitle: Text(exerciseModeLabel(l10n, mode)),
      trailing: const Icon(Icons.expand_more),
      enabled: enabled,
      onTap: enabled ? () => _pick(context, l10n) : null,
    );
  }

  Future<void> _pick(BuildContext context, AppLocalizations l10n) async {
    final chosen = await showRingdrillPicker<ExerciseMode>(
      context: context,
      title: l10n.exerciseModePickerTitle,
      items: ExerciseMode.values,
      itemBuilder: (context, value, onTap) => ListTile(
        leading: Icon(exerciseModeIcon(value)),
        title: Text(exerciseModeLabel(l10n, value)),
        subtitle: Text(exerciseModeDescription(l10n, value)),
        trailing: value == mode ? const Icon(Icons.check) : null,
        onTap: onTap,
      ),
    );
    if (chosen != null && chosen != mode) onChanged(chosen);
  }
}
