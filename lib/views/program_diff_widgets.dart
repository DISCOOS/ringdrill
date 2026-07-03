import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';

class DiffGroup extends StatelessWidget {
  const DiffGroup({
    super.key,
    required this.title,
    required this.added,
    required this.removed,
    required this.modified,
  });

  final String title;
  final List<String> added;
  final List<String> removed;
  final List<ItemDiff> modified;

  @override
  Widget build(BuildContext context) {
    if (added.isEmpty && removed.isEmpty && modified.isEmpty) {
      return const SizedBox.shrink();
    }
    final localizations = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          if (added.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${localizations.catalogDiffAdded}: ${added.join(', ')}'),
            ),
          if (removed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${localizations.catalogDiffRemoved}: ${removed.join(', ')}'),
            ),
          for (final item in modified)
            DiffItemTile(label: localizations.catalogDiffModified, item: item),
        ],
      ),
    );
  }
}

/// Renders a single modified item's name plus every field it changed on
/// (e.g. "Method: old text → new text"), so a catalog conflict shows *what*
/// changed rather than just *which* exercise/team/session did.
class DiffItemTile extends StatelessWidget {
  const DiffItemTile({super.key, required this.label, required this.item});

  final String label;
  final ItemDiff item;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${item.name}'),
          for (final change in item.changes)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: Text(
                _describeChange(localizations, change),
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  String _describeChange(AppLocalizations localizations, FieldChange change) {
    final label = fieldChangeLabel(localizations, change.field);
    if (change.local == null && change.remote == null) {
      return '$label (${localizations.catalogDiffModified})';
    }
    return '$label: ${_present(change.local)} → ${_present(change.remote)}';
  }
}

/// Maps a [FieldChange.field] key to its localized display label. Keys are
/// plain, non-localized identifiers chosen in lib/models/program.dart (e.g.
/// `"name"`, `"methodMd"`) — this is the single place that turns them into
/// user-facing text, reusing existing field labels from elsewhere in the app
/// so the same field reads the same way wherever it appears.
String fieldChangeLabel(AppLocalizations l, String field) => switch (field) {
  'name' => l.exerciseName,
  'startTime' => l.startTime,
  'endTime' => l.catalogDiffFieldEndTime,
  'numberOfTeams' => l.numberOfTeams,
  'numberOfRounds' => l.numberOfRounds,
  'executionTime' => l.executionTime,
  'evaluationTime' => l.evaluationTime,
  'rotationTime' => l.rotationTime,
  'stations' => l.stationsTab,
  'numberOfMembers' => l.numberOfMembers,
  'position' => l.position,
  'startedAt' => l.catalogDiffFieldStartedAt,
  'endedAt' => l.catalogDiffFieldEndedAt,
  'age' => l.roleAge,
  'signalement' => l.roleSignalement,
  'background' => l.roleBackground,
  'behavior' => l.roleBehavior,
  'propsMd' => l.catalogDiffFieldProps,
  'methodMd' => l.briefSectionExerciseMethod,
  'learningGoalsMd' => l.briefSectionExerciseLearningGoals,
  'trainingFocusMd' => l.briefSectionExerciseTrainingFocus,
  'orderFormatMd' => l.briefSectionExerciseOrderFormat,
  'executionTipsMd' => l.briefSectionExerciseExecutionTips,
  'commsMd' => l.briefSectionExerciseComms,
  'other' => l.catalogDiffFieldOther,
  _ => field,
};

String _present(String? value) {
  if (value == null) return '—';
  final trimmed = value.trim();
  return trimmed.isEmpty ? '—' : trimmed;
}

/// Renders a single before/after field change (e.g. plan name, description).
/// Renders nothing when both sides are null or equal.
class DiffField extends StatelessWidget {
  const DiffField({
    super.key,
    required this.label,
    required this.local,
    required this.remote,
  });

  final String label;
  final String? local;
  final String? remote;

  @override
  Widget build(BuildContext context) {
    if (local == null && remote == null) return const SizedBox.shrink();
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${localizations.catalogDiffLocal}: ${_present(local)}',
          ),
          Text(
            '${localizations.catalogDiffRemote}: ${_present(remote)}',
          ),
        ],
      ),
    );
  }
}
