/// The exercise's conduct mode as a form field (ADR-0062).
///
/// Deliberately not a new control. It is the pattern this form already uses for a
/// tappable value — an `InkWell` around an [InputDecorator], the same as the start-time
/// field beside the exercise name — opening [showRingdrillPicker] (ADR-0049), the app's
/// bottom-sheet-on-compact, dialog-on-wide picker, with one `ListTile` per option. The
/// station picker in the roleplay editor reads the same way, which is the point: an
/// author who has chosen a station has already met this.
///
/// The border is the outlined variant rather than the siblings' underline. As a bare
/// `ListTile` this had no frame at all and read as a caption floating between two rows
/// of real inputs; and unlike those inputs it governs the whole exercise — the counters
/// below it change meaning when it changes — so reading as its own enclosed thing is
/// right rather than merely decorative.
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
/// One word each, so the three read as a set: Ring · Together · Split. `ring` has its
/// own string rather than reusing the brief's `briefRingRoute` — the brief names the
/// *route* ("Ring Route" / "Ringløype") in a sentence with room for it, while a picker
/// row sits beside two one-word siblings. "Ring Drill" is deliberately neither: that
/// names the whole domain, not one mode of one exercise.
String exerciseModeLabel(AppLocalizations l10n, ExerciseMode mode) =>
    switch (mode) {
      ExerciseMode.ring => l10n.exerciseModeRing,
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
    final theme = Theme.of(context);
    const radius = BorderRadius.all(Radius.circular(8));
    return InkWell(
      onTap: enabled ? () => _pick(context, l10n) : null,
      borderRadius: radius,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.exerciseMode,
          enabled: enabled,
          border: const OutlineInputBorder(borderRadius: radius),
          prefixIcon: Icon(exerciseModeIcon(mode)),
          suffixIcon: const Icon(Icons.expand_more),
        ),
        child: Text(
          exerciseModeLabel(l10n, mode),
          // ADR-0037: themed, not a hardcoded size — and bodyLarge, so the value sits
          // at the same weight as the text the sibling fields hold.
          style: theme.textTheme.bodyLarge?.copyWith(
            color: enabled
                ? null
                : theme.colorScheme.onSurface.withValues(alpha: 0.38),
          ),
        ),
      ),
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
