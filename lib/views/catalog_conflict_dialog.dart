import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/plan_diff_widgets.dart';

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
  required PlanDiff diff,
  required bool ownedSlug,
  bool remoteUnchanged = false,
  String? localVersion,
  String? catalogVersion,
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
      localVersion: localVersion,
      catalogVersion: catalogVersion,
    ),
  );
  // The buttons are the only user-facing way to pop, but a programmatic pop
  // (e.g. the whole route stack being torn down) still lands here.
  return choice ?? CatalogConflictChoice.cancel;
}

class _CatalogConflictContent extends StatefulWidget {
  const _CatalogConflictContent({
    required this.diff,
    required this.remoteUnchanged,
    this.localVersion,
    this.catalogVersion,
  });

  final PlanDiff diff;
  final bool remoteUnchanged;
  final String? localVersion;
  final String? catalogVersion;

  @override
  State<_CatalogConflictContent> createState() =>
      _CatalogConflictContentState();
}

class _CatalogConflictContentState extends State<_CatalogConflictContent> {
  // Defaults to showing the full diff (struck-through deletions and all) —
  // matches the dialog's original always-on behavior; the switch below is an
  // opt-in for readers who find the surviving text easier to scan without
  // the removed half of a substitution alongside it.
  bool _showDeletions = true;

  @override
  Widget build(BuildContext context) {
    final diff = widget.diff;
    final remoteUnchanged = widget.remoteUnchanged;
    final localVersion = widget.localVersion;
    final catalogVersion = widget.catalogVersion;
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        // Horizontal 16 (not 20) and top 8 (not 16) to match the other
        // sheets' content padding (e.g. feedback.dart's fromLTRB(16, 8, 16,
        // 16)) — the sheet chrome already accounts for the drag-handle-sized
        // gap above this, so stacking a full 16px on top of that read as
        // noticeably more top/left inset than the "x" gets elsewhere.
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Leading, not trailing — RingDrill's bottom sheets put the
                // close "x" on the left (mirrors PlanFormScreen's AppBar
                // leading close icon). Needed here specifically because
                // this sheet is non-dismissable — no drag-down, no barrier
                // tap — so without it there would be no visible way out
                // other than reading the bottom action row. Zero padding
                // (rather than the IconButton default) so the glyph sits at
                // the same inset as the rest of the content, matching an
                // AppBar leading icon instead of adding its own extra gap.
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: localizations.catalogConflictCancel,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      Navigator.pop(context, CatalogConflictChoice.cancel),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    localizations.catalogConflictTitle,
                    style: theme.textTheme.titleLarge,
                  ),
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
                    const SizedBox(height: 10),
                    _VersionComparison(
                      localVersion: localVersion,
                      catalogVersion: catalogVersion,
                    ),
                    const SizedBox(height: 16),
                    PlanDiffView(diff: diff, showDeletions: _showDeletions),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // The "show deletions" switch sits in this fixed row rather than
            // above the scrollable diff, so it stays reachable no matter how
            // far the user has scrolled into a long diff. Leading, not
            // trailing, so it doesn't compete with the OverflowBar's own
            // end-alignment for the buttons — Expanded gives the bar the
            // rest of the row's width to right-align within, exactly as it
            // did when it owned the whole row.
            Row(
              children: [
                Tooltip(
                  message: localizations.catalogDiffShowDeletions,
                  child: Switch.adaptive(
                    value: _showDeletions,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    // Same error/red used by "Discard mine" below — this
                    // dialog's existing color for a destructive/removal
                    // concept — applied to the track when on, so the bin
                    // icon's red reads as a matching accent, not a stray
                    // color. The thumb itself is left at its default light
                    // color so the red icon on top of it keeps contrast.
                    activeTrackColor: theme.colorScheme.error,
                    // A bin — deletions are "thrown away" from view when the
                    // switch is off — baked into the thumb itself rather
                    // than a separate leading icon, so the control stays a
                    // single compact element next to three buttons.
                    thumbIcon: WidgetStateProperty.all(
                      Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.error,
                      ),
                    ),
                    onChanged: (value) =>
                        setState(() => _showDeletions = value),
                  ),
                ),
                Expanded(
                  // Cancel lives only in the header's close "x" now. The
                  // fork option is tucked into a context menu here (grouped
                  // with the two primary buttons in the same OverflowBar,
                  // so it shares their spacing and their wrap-to-column
                  // fallback) rather than sitting as an equal-weight third
                  // button — most conflicts resolve to discarding local
                  // edits or publishing them, so the common two-choice
                  // decision reads faster without losing the fork path for
                  // whoever does need it. OverflowBar — the same widget
                  // AlertDialog uses for its `actions` row — right-aligns
                  // the group and, unlike a bare Wrap inside a Column with
                  // CrossAxisAlignment.start (which only sizes to its own
                  // content, leaving "end" alignment with nothing to align
                  // against), actually stretches to fill this Expanded's
                  // width first, so the whole group (menu + buttons) sits
                  // flush against the dialog's trailing edge with an
                  // expandable gap after the switch. Falls back to a
                  // vertical stack, end-aligned, if the labels ever don't
                  // fit a narrow screen on one line.
                  child: OverflowBar(
                    alignment: MainAxisAlignment.end,
                    overflowAlignment: OverflowBarAlignment.end,
                    spacing: 8,
                    overflowSpacing: 8,
                    children: [
                      PopupMenuButton<CatalogConflictChoice>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (choice) => Navigator.pop(context, choice),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: CatalogConflictChoice.forkAsLocal,
                            child: Text(localizations.catalogConflictFork),
                          ),
                        ],
                      ),
                      // Discard is destructive (throws away local edits), so
                      // it gets the error color to stand apart from Publish.
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                        onPressed: () => Navigator.pop(
                          context,
                          CatalogConflictChoice.overwriteLocal,
                        ),
                        child: Text(localizations.catalogConflictOverwrite),
                      ),
                      // Wiki model: anyone can publish updates. We previously
                      // hid this option behind ownsCatalogSlug, which broke
                      // the flow for users who had installed a plan and
                      // wanted to contribute back without ever having
                      // published it first.
                      FilledButton(
                        onPressed: () => Navigator.pop(
                          context,
                          CatalogConflictChoice.publishMyChanges,
                        ),
                        child: Text(localizations.catalogConflictPublish),
                      ),
                    ],
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

/// The version comparison line shown below the informational text: which
/// published version the local copy last tracked, versus what the catalog
/// currently has (e.g. "Local v3 → Catalog v5"). A single lightweight row
/// rather than boxed chips so it stays subordinate to the colored word-diff
/// below it. A version that is not known — a plan installed before version
/// tracking existed, or a header the server did not send — renders as a muted
/// italic "None"/"Ingen" instead of being hidden, so the gap is visible.
class _VersionComparison extends StatelessWidget {
  const _VersionComparison({this.localVersion, this.catalogVersion});

  final String? localVersion;
  final String? catalogVersion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    TextSpan valueSpan(String? version) {
      if (version != null) {
        return TextSpan(
          text: 'v$version',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        );
      }
      return TextSpan(
        text: l.catalogConflictVersionUnknown,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            Icons.difference_outlined,
            size: 18,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${l.catalogConflictVersionLocalLabel} ',
                  style: labelStyle,
                ),
                valueSpan(localVersion),
                TextSpan(text: '  →  ', style: labelStyle),
                TextSpan(
                  text: '${l.catalogConflictVersionCatalogLabel} ',
                  style: labelStyle,
                ),
                valueSpan(catalogVersion),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
