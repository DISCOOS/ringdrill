import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/program_diff_widgets.dart';

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
              DiffGroup(
                title: localizations.catalogDiffExercises,
                added: diff.addedExercises,
                removed: diff.removedExercises,
                modified: diff.modifiedExercises,
              ),
              DiffGroup(
                title: localizations.catalogDiffTeams,
                added: diff.addedTeams,
                removed: diff.removedTeams,
                modified: diff.modifiedTeams,
              ),
              DiffGroup(
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
