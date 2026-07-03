import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/program_diff_widgets.dart';

/// Bottom sheet on mobile, a larger dialog on wide form factors — mirrors
/// showSelectPlansDialog/name_step_sheet. The diff itself can be long once
/// modified items show their field-level changes (not just names), so both
/// presentations get a bounded, scrollable body via [maximizeHeight].
Future<CatalogConflictChoice> showCatalogConflictDialog(
  BuildContext context, {
  required ProgramDiff diff,
  required bool ownedSlug,
  bool remoteUnchanged = false,
}) async {
  final choice = await showResponsiveSheetOrDialog<CatalogConflictChoice>(
    context,
    maximizeHeight: true,
    dialogMaxWidth: 640,
    dialogMaxHeight: 680,
    builder: (context) => _CatalogConflictContent(
      diff: diff,
      remoteUnchanged: remoteUnchanged,
    ),
  );
  return choice ?? CatalogConflictChoice.cancel;
}

class _CatalogConflictContent extends StatelessWidget {
  const _CatalogConflictContent({
    required this.diff,
    required this.remoteUnchanged,
  });

  final ProgramDiff diff;
  final bool remoteUnchanged;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.catalogConflictTitle,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      remoteUnchanged
                          ? localizations.catalogConflictBodyLocalOnly
                          : localizations.catalogConflictBody,
                    ),
                    const SizedBox(height: 16),
                    DiffField(
                      label: localizations.catalogDiffName,
                      local: diff.nameLocal,
                      remote: diff.nameRemote,
                    ),
                    DiffField(
                      label: localizations.catalogDiffDescription,
                      local: diff.descriptionLocal,
                      remote: diff.descriptionRemote,
                    ),
                    DiffField(
                      label: localizations.catalogDiffTags,
                      local: diff.tagsLocal,
                      remote: diff.tagsRemote,
                    ),
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
                    // "Script" is this app's own name for the role-play
                    // feature (see ProgramSegment.script) — reused here
                    // rather than coining a separate "Role plays" label.
                    DiffGroup(
                      title: localizations.scriptSegment,
                      added: diff.addedRolePlays,
                      removed: diff.removedRolePlays,
                      modified: diff.modifiedRolePlays,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, CatalogConflictChoice.cancel),
                  child: Text(localizations.catalogConflictCancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    CatalogConflictChoice.overwriteLocal,
                  ),
                  child: Text(localizations.catalogConflictOverwrite),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    CatalogConflictChoice.forkAsLocal,
                  ),
                  child: Text(localizations.catalogConflictFork),
                ),
                // Wiki model: anyone can publish updates. We previously hid
                // this option behind ownsCatalogSlug, which broke the flow
                // for users who had installed a plan and wanted to
                // contribute back without ever having published it first.
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    CatalogConflictChoice.publishMyChanges,
                  ),
                  child: Text(localizations.catalogConflictPublish),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
