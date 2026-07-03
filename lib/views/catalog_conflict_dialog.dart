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
///
/// Non-dismissable: a conflict needs an explicit decision, so barrier tap,
/// drag-down and system back are all blocked and the action buttons are the
/// only way out. Cancel is one of them, so nothing is lost — the user just
/// has to choose consciously instead of swiping the sheet away.
Future<CatalogConflictChoice> showCatalogConflictDialog(
  BuildContext context, {
  required ProgramDiff diff,
  required bool ownedSlug,
  bool remoteUnchanged = false,
}) async {
  // The refresh flow may still be showing its "Refreshing…" snackbar; it
  // would sit on top of the sheet's action buttons, so clear it first.
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  final choice = await showResponsiveSheetOrDialog<CatalogConflictChoice>(
    context,
    maximizeHeight: true,
    isDismissible: false,
    dialogMaxWidth: 640,
    dialogMaxHeight: 680,
    builder: (context) => _CatalogConflictContent(
      diff: diff,
      remoteUnchanged: remoteUnchanged,
    ),
  );
  // The buttons are the only user-facing way to pop, but a programmatic pop
  // (e.g. the whole route stack being torn down) still lands here.
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    localizations.catalogConflictTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                // The usual close affordance other sheets/screens give
                // (e.g. ProgramFormScreen's AppBar leading "x"). Needed
                // here specifically because this sheet is non-dismissable
                // — no drag-down, no barrier tap — so without it there
                // would be no visible way out other than reading the
                // bottom action row.
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: localizations.catalogConflictCancel,
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      Navigator.pop(context, CatalogConflictChoice.cancel),
                ),
              ],
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
                    ProgramDiffView(diff: diff),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Discard is destructive (throws away local edits), so it
                // gets the error color even though it sits alongside Fork in
                // an otherwise equal-weight outlined pair.
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                    onPressed: () => Navigator.pop(
                      context,
                      CatalogConflictChoice.overwriteLocal,
                    ),
                    child: Text(localizations.catalogConflictOverwrite),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      CatalogConflictChoice.forkAsLocal,
                    ),
                    child: Text(localizations.catalogConflictFork),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, CatalogConflictChoice.cancel),
                  child: Text(localizations.catalogConflictCancel),
                ),
                const SizedBox(width: 8),
                // Flexible (not Spacer + bare button) so "Publish my
                // changes" is capped to the remaining width on narrow
                // screens — its text wraps instead of overflowing the row —
                // while still hugging the right edge when it fits on one
                // line.
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    // Wiki model: anyone can publish updates. We previously
                    // hid this option behind ownsCatalogSlug, which broke
                    // the flow for users who had installed a plan and
                    // wanted to contribute back without ever having
                    // published it first.
                    child: FilledButton(
                      onPressed: () => Navigator.pop(
                        context,
                        CatalogConflictChoice.publishMyChanges,
                      ),
                      child: Text(localizations.catalogConflictPublish),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
