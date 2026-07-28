import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/utils/word_diff.dart';
import 'package:ringdrill/views/widgets/exercise_number_badge.dart';

/// Left inset for a change row relative to the entity row it belongs to —
/// reused at every nesting depth (an exercise's own field changes, and a
/// nested station's own field changes, both indent by exactly this much
/// from their entity row) so the indentation rhythm stays consistent no
/// matter how deep the nesting goes. Matches the existing 24px badge + 8px
/// gap the entity row itself uses.
const double _kChangeIndent = 32;

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
              child: Text(
                '${localizations.catalogDiffAdded}: ${added.join(', ')}',
              ),
            ),
          if (removed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${localizations.catalogDiffRemoved}: ${removed.join(', ')}',
              ),
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
/// plain, non-localized identifiers chosen in lib/models/plan.dart (e.g.
/// `"name"`, `"methodMd"`) — this is the single place that turns them into
/// user-facing text, reusing existing field labels from elsewhere in the app
/// so the same field reads the same way wherever it appears.
///
/// `'name'` is shared by exercises, teams and role plays alike (each has its
/// own `add('name', ...)` in plan.dart), so it stays a plain "Name"
/// rather than "Exercise name" — the item's own card already names its
/// type via context (the section title above it), so a role play's name
/// change showing "Exercise name changed" would be actively wrong, not
/// just redundant.
String fieldChangeLabel(AppLocalizations l, String field) => switch (field) {
  'name' => l.catalogDiffFieldName,
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
  'roleDescription' => l.roleDescription,
  'background' => l.roleBackground,
  'behavior' => l.roleBehavior,
  'propsMd' => l.catalogDiffFieldProps,
  'methodMd' => l.briefSectionExerciseMethod,
  'learningGoalsMd' => l.briefSectionExerciseLearningGoals,
  'trainingFocusMd' => l.briefSectionExerciseTrainingFocus,
  'orderFormatMd' => l.briefSectionExerciseOrderFormat,
  'executionTipsMd' => l.briefSectionExerciseExecutionTips,
  'commsMd' => l.briefSectionExerciseComms,
  // Station fields — 'name'/'position' above already cover the station's
  // own name/position changes (same field keys, same meaning).
  'description' => l.stationDescription,
  'equipmentMd' => l.briefSectionStationEquipment,
  'situationMd' => l.briefSectionStationSituation,
  'missionMd' => l.briefSectionStationMission,
  'logisticsMd' => l.briefSectionStationLogistics,
  'criticalQuestionsMd' => l.briefSectionStationCriticalQuestions,
  'leaderAnswersMd' => l.briefSectionStationLeaderAnswers,
  'directorNotesMd' => l.briefSectionStationDirectorNotes,
  'other' => l.catalogDiffFieldOther,
  _ => field,
};

String _present(String? value) {
  if (value == null) return '—';
  final trimmed = value.trim();
  return trimmed.isEmpty ? '—' : trimmed;
}

/// Full grouped rendering of a [PlanDiff] for the catalog conflict
/// dialog: plan-level changes first (if any), then one section per entity
/// category in the same order the old flat layout used (exercises, teams,
/// sessions, role plays). Each category collapses to nothing when it has no
/// changes. Within a category, every change is grouped *per item* — an
/// exercise that both moved and had a field edited shows one card with both
/// facts, rather than being split across a "reorder" section and a
/// "modified" section (see [ItemDiff]).
///
/// [showDeletions] is owned by the dialog around this view (not by this
/// widget itself) — its own toggle lives in the dialog's fixed bottom row so
/// it stays reachable even when this view's content scrolls, rather than
/// scrolling away with it.
class PlanDiffView extends StatelessWidget {
  const PlanDiffView({
    super.key,
    required this.diff,
    required this.showDeletions,
  });

  final PlanDiff diff;
  final bool showDeletions;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final hasPlanChange =
        diff.nameLocal != null ||
        diff.descriptionLocal != null ||
        diff.tagsLocal != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasPlanChange)
          _DiffSection(
            title: localizations.catalogDiffPlan,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _DiffValueLine(
                  label: localizations.catalogDiffName,
                  local: diff.nameLocal,
                  remote: diff.nameRemote,
                  showDeletions: showDeletions,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _DiffValueLine(
                  label: localizations.catalogDiffDescription,
                  local: diff.descriptionLocal,
                  remote: diff.descriptionRemote,
                  showDeletions: showDeletions,
                ),
              ),
              _DiffValueLine(
                label: localizations.catalogDiffTags,
                local: diff.tagsLocal,
                remote: diff.tagsRemote,
                showDeletions: showDeletions,
              ),
            ],
          ),
        _EntitySection(
          title: localizations.catalogDiffExercises,
          added: diff.addedExercises,
          removed: diff.removedExercises,
          modified: diff.modifiedExercises,
          showDeletions: showDeletions,
        ),
        _EntitySection(
          title: localizations.catalogDiffTeams,
          added: diff.addedTeams,
          removed: diff.removedTeams,
          modified: diff.modifiedTeams,
          showDeletions: showDeletions,
        ),
        _EntitySection(
          title: localizations.catalogDiffSessions,
          added: diff.addedSessions,
          removed: diff.removedSessions,
          modified: diff.modifiedSessions,
          showDeletions: showDeletions,
        ),
        // "Script" is this app's own name for the role-play feature (see
        // PlanSegment.script) — reused here rather than coining a
        // separate "Role plays" label.
        _EntitySection(
          title: localizations.scriptSegment,
          added: diff.addedRolePlays,
          removed: diff.removedRolePlays,
          modified: diff.modifiedRolePlays,
          showDeletions: showDeletions,
        ),
      ],
    );
  }
}

/// Titled, lightly-shaded container used to visually group a set of related
/// diff rows (the plan-level fields, or one entity category). The title
/// sits in its own full-width, one-tonal-step-darker header bar rather than
/// as plain text inside the body — same convention as `PhaseHeaders` — so
/// it reads as a section divider. That visual separation is also what a
/// future tap-to-collapse affordance on the header would need, once a
/// conflict has enough sections to make collapsing worthwhile.
class _DiffSection extends StatelessWidget {
  const _DiffSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Solid tonal steps (not alpha-blended) so the body reads clearly
    // against the sheet's own surface behind it, with the header always one
    // step darker than the body above it.
    final light = scheme.brightness == Brightness.light;
    final headerColor = light
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainer;
    final bodyColor = light
        ? scheme.surfaceContainer
        : scheme.surfaceContainerLow;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bodyColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: headerColor,
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// One entity category (exercises/teams/sessions/role plays) within
/// [PlanDiffView]. Collapses to nothing when there is no added, removed
/// or modified item to show.
class _EntitySection extends StatelessWidget {
  const _EntitySection({
    required this.title,
    required this.added,
    required this.removed,
    required this.modified,
    required this.showDeletions,
  });

  final String title;
  final List<String> added;
  final List<String> removed;
  final List<ItemDiff> modified;
  final bool showDeletions;

  @override
  Widget build(BuildContext context) {
    if (added.isEmpty && removed.isEmpty && modified.isEmpty) {
      return const SizedBox.shrink();
    }
    final localizations = AppLocalizations.of(context)!;
    return _DiffSection(
      title: title,
      children: [
        if (added.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${localizations.catalogDiffAdded}: ${added.join(', ')}',
            ),
          ),
        if (removed.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${localizations.catalogDiffRemoved}: ${removed.join(', ')}',
            ),
          ),
        for (final item in modified)
          _ConflictItemTile(item: item, showDeletions: showDeletions),
      ],
    );
  }
}

/// One changed item's card: its name (plus [ItemDiff.number] badge when the
/// entity type has a numbering scheme — disambiguates identically-named
/// exercises, which a drill plan routinely has, e.g. the same round
/// repeated per team) followed by every fact about what changed on it,
/// reorder and field edits alike, as a single per-item group instead of
/// being split across separate by-change-type sections.
///
/// Recurses for [ItemDiff.nestedChanges] (currently only an exercise's
/// modified stations): a "Poster"/"Stations" divider at the *same* indent
/// as this item's own row, then one more `_ConflictItemTile` per station —
/// each one lays out its own row + changes exactly like this one does, so
/// the indentation rhythm (entity row, then its changes one step in) is
/// identical at every nesting depth without threading a depth counter
/// through.
class _ConflictItemTile extends StatelessWidget {
  const _ConflictItemTile({required this.item, required this.showDeletions});

  final ItemDiff item;
  final bool showDeletions;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final number = item.number;
    final stationsHeader = Text(
      localizations.stationsTab,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (number != null) ...[
                ExerciseNumberBadge(label: number, size: 24),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  item.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          for (final change in item.changes)
            Padding(
              padding: EdgeInsets.only(
                left: number != null ? _kChangeIndent : 0,
                top: 4,
              ),
              child: _FieldChangeLine(
                change: change,
                showDeletions: showDeletions,
              ),
            ),
          if (item.nestedChanges.isNotEmpty ||
              item.addedNested.isNotEmpty ||
              item.removedNested.isNotEmpty) ...[
            Padding(
              // The divider line only earns its keep when it's actually
              // separating this item's own change lines (above) from the
              // nested section (below) — with no own changes, a line
              // directly under the title/badge row separates nothing and
              // just reads as a stray rule, so it's dropped and the header
              // gets a smaller top gap instead.
              padding: EdgeInsets.only(
                top: item.changes.isNotEmpty ? 12 : 8,
                bottom: 6,
              ),
              child: item.changes.isNotEmpty
                  ? Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: theme.dividerColor),
                        ),
                      ),
                      padding: const EdgeInsets.only(top: 8),
                      child: stationsHeader,
                    )
                  : stationsHeader,
            ),
            // Plain name-list lines, same convention as _EntitySection's own
            // added/removed rows — no per-item card, just names.
            if (item.addedNested.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${localizations.catalogDiffAdded}: ${item.addedNested.join(', ')}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (item.removedNested.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${localizations.catalogDiffRemoved}: ${item.removedNested.join(', ')}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            for (final nested in item.nestedChanges)
              _ConflictItemTile(item: nested, showDeletions: showDeletions),
          ],
        ],
      ),
    );
  }
}

/// One field-change line: `order`/`other`/no-value changes render as plain
/// muted text same as before, but a change with both values renders as a
/// muted `"{field}: "` label (no "changed"/"endret" verb — the colored diff
/// itself is the signal something changed) followed by the word-diff
/// itself: unchanged words in the normal value color, inserted words green,
/// deleted words red+struck-through (shown inline, not hidden), and a
/// substituted word's old half red+struck-through immediately followed by
/// its new half in blue.
class _FieldChangeLine extends StatelessWidget {
  const _FieldChangeLine({required this.change, required this.showDeletions});

  final FieldChange change;
  final bool showDeletions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodySmall;

    if (change.field == 'order') {
      // 'order' stores the catalog's (old) position as `remote` and the
      // local plan's (new) position as `local` — see _diffItems in
      // plan.dart — so "from" is remote and "to" is local, matching the
      // rest of this dialog's local-vs-catalog framing.
      return Text(
        l.catalogDiffReorderedFromTo(change.remote ?? '', change.local ?? ''),
        style: baseStyle,
      );
    }
    final label = fieldChangeLabel(l, change.field);
    // 'other' already reads as a complete sentence on its own ("Other
    // changes") — running it through the generic "{field} changed"
    // template would double up on "changed".
    if (change.field == 'other') {
      return Text(label, style: baseStyle);
    }
    if (change.local == null && change.remote == null) {
      // No values to diff — "changed"/"endret" is the only signal here that
      // something happened, so (unlike the labelled case below) it stays.
      return Text(l.catalogDiffFieldChangedGeneric(label), style: baseStyle);
    }

    // "old" is the catalog's (remote) value, "new" is the local plan's —
    // same remote-then-local framing as the 'order' branch above.
    return _DiffValueLine(
      label: label,
      local: change.local,
      remote: change.remote,
      showDeletions: showDeletions,
    );
  }
}

/// Muted `"{label}: "` prefix followed by the colored word-diff of [remote]
/// (old) against [local] (new) — the shared rendering for every scalar
/// field-change line in this dialog, so a plan-level rename and an
/// exercise's own name change read identically instead of the plan section
/// using a separate, older two-line "Your version:"/"Catalog version:"
/// layout with no coloring at all. Renders nothing when both sides are null.
class _DiffValueLine extends StatelessWidget {
  const _DiffValueLine({
    required this.label,
    required this.local,
    required this.remote,
    required this.showDeletions,
  });

  final String label;
  final String? local;
  final String? remote;
  final bool showDeletions;

  @override
  Widget build(BuildContext context) {
    if (local == null && remote == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodySmall;
    final mutedStyle = baseStyle?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final segments = diffWords(_present(remote), _present(local));
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label: ', style: mutedStyle),
          ..._diffSpans(
            segments,
            baseStyle,
            theme,
            showDeletions: showDeletions,
          ),
        ],
      ),
    );
  }
}

/// Maps [WordDiffSegment]s to colored [InlineSpan]s, joining consecutive
/// segments with a single space (word-diff tokenization already discards
/// the original spacing, so this is the only spacing the render needs).
///
/// When [showDeletions] is false, a pure [WordDiffOp.delete] segment is
/// omitted entirely (there is nothing "new" to show for it) and a
/// [WordDiffOp.replace] segment shows only its new half — the struck-through
/// old text some users find harder to read alongside the surviving text is
/// dropped, while insertions and substitutions still keep their color as the
/// signal that something changed there.
List<InlineSpan> _diffSpans(
  List<WordDiffSegment> segments,
  TextStyle? baseStyle,
  ThemeData theme, {
  required bool showDeletions,
}) {
  final dark = theme.brightness == Brightness.dark;
  // Brighter tones on a dark surface, deeper tones on a light one — same
  // "pop against the background" convention already used for the AppBar's
  // catalog-status badge and this dialog's own section header/body tones.
  final insertColor = dark ? Colors.green.shade300 : Colors.green.shade700;
  final deleteColor = dark ? Colors.red.shade300 : Colors.red.shade700;
  final replaceColor = dark ? Colors.blue.shade300 : Colors.blue.shade700;

  final spans = <InlineSpan>[];
  var needsSpace = false;
  void addSpan(String? text, TextStyle? style) {
    if (text == null) return;
    if (needsSpace) spans.add(TextSpan(text: ' ', style: baseStyle));
    spans.add(TextSpan(text: text, style: style));
    needsSpace = true;
  }

  for (final segment in segments) {
    switch (segment.op) {
      case WordDiffOp.equal:
        addSpan(segment.newText, baseStyle);
      case WordDiffOp.insert:
        addSpan(segment.newText, baseStyle?.copyWith(color: insertColor));
      case WordDiffOp.delete:
        if (showDeletions) {
          addSpan(
            segment.oldText,
            baseStyle?.copyWith(
              color: deleteColor,
              decoration: TextDecoration.lineThrough,
            ),
          );
        }
      case WordDiffOp.replace:
        if (showDeletions) {
          addSpan(
            segment.oldText,
            baseStyle?.copyWith(
              color: deleteColor,
              decoration: TextDecoration.lineThrough,
            ),
          );
        }
        addSpan(segment.newText, baseStyle?.copyWith(color: replaceColor));
    }
  }
  return spans;
}
