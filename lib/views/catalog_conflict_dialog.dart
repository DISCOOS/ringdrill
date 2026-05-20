import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/services/program_service.dart';

Future<CatalogConflictChoice> showCatalogConflictDialog(
  BuildContext context, {
  required ProgramDiff diff,
  required bool ownedSlug,
}) async {
  final localizations = AppLocalizations.of(context)!;
  final choice = await showDialog<CatalogConflictChoice>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(localizations.catalogConflictTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(localizations.catalogConflictBody),
              const SizedBox(height: 16),
              _DiffGroup(
                title: localizations.catalogDiffExercises,
                added: diff.addedExercises,
                removed: diff.removedExercises,
                modified: diff.modifiedExercises,
              ),
              _DiffGroup(
                title: localizations.catalogDiffTeams,
                added: diff.addedTeams,
                removed: diff.removedTeams,
                modified: diff.modifiedTeams,
              ),
              _DiffGroup(
                title: localizations.catalogDiffSessions,
                added: diff.addedSessions,
                removed: diff.removedSessions,
                modified: diff.modifiedSessions,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, CatalogConflictChoice.cancel),
          child: Text(localizations.catalogConflictCancel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, CatalogConflictChoice.overwriteLocal),
          child: Text(localizations.catalogConflictOverwrite),
        ),
        if (ownedSlug)
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, CatalogConflictChoice.publishMyChanges),
            child: Text(localizations.catalogConflictPublish),
          )
        else
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, CatalogConflictChoice.forkAsLocal),
            child: Text(localizations.catalogConflictFork),
          ),
      ],
    ),
  );
  return choice ?? CatalogConflictChoice.cancel;
}

class _DiffGroup extends StatelessWidget {
  const _DiffGroup({
    required this.title,
    required this.added,
    required this.removed,
    required this.modified,
  });

  final String title;
  final List<String> added;
  final List<String> removed;
  final List<String> modified;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final rows = [
      (localizations.catalogDiffAdded, added),
      (localizations.catalogDiffRemoved, removed),
      (localizations.catalogDiffModified, modified),
    ].where((row) => row.$2.isNotEmpty).toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${row.$1}: ${row.$2.join(', ')}'),
            ),
        ],
      ),
    );
  }
}
