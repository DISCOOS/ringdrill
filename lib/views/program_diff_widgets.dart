import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/views/widgets/exercise_number_badge.dart';

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
///
/// `'name'` is shared by exercises, teams and role plays alike (each has its
/// own `add('name', ...)` in program.dart), so it stays a plain "Name"
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

/// Full grouped rendering of a [ProgramDiff] for the catalog conflict
/// dialog: plan-level changes first (if any), then one section per entity
/// category in the same order the old flat layout used (exercises, teams,
/// sessions, role plays). Each category collapses to nothing when it has no
/// changes. Within a category, every change is grouped *per item* — an
/// exercise that both moved and had a field edited shows one card with both
/// facts, rather than being split across a "reorder" section and a
/// "modified" section (see [ItemDiff]).
class ProgramDiffView extends StatelessWidget {
  const ProgramDiffView({super.key, required this.diff});

  final ProgramDiff diff;

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
            ],
          ),
        _EntitySection(
          title: localizations.catalogDiffExercises,
          added: diff.addedExercises,
          removed: diff.removedExercises,
          modified: diff.modifiedExercises,
        ),
        _EntitySection(
          title: localizations.catalogDiffTeams,
          added: diff.addedTeams,
          removed: diff.removedTeams,
          modified: diff.modifiedTeams,
        ),
        _EntitySection(
          title: localizations.catalogDiffSessions,
          added: diff.addedSessions,
          removed: diff.removedSessions,
          modified: diff.modifiedSessions,
        ),
        // "Script" is this app's own name for the role-play feature (see
        // ProgramSegment.script) — reused here rather than coining a
        // separate "Role plays" label.
        _EntitySection(
          title: localizations.scriptSegment,
          added: diff.addedRolePlays,
          removed: diff.removedRolePlays,
          modified: diff.modifiedRolePlays,
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
/// [ProgramDiffView]. Collapses to nothing when there is no added, removed
/// or modified item to show.
class _EntitySection extends StatelessWidget {
  const _EntitySection({
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
        for (final item in modified) _ConflictItemTile(item: item),
      ],
    );
  }
}

/// One changed item's card: its name (plus [ItemDiff.number] badge when the
/// entity type has a numbering scheme — disambiguates identically-named
/// exercises, which a drill program routinely has, e.g. the same round
/// repeated per team) followed by every fact about what changed on it,
/// reorder and field edits alike, as a single per-item group instead of
/// being split across separate by-change-type sections.
class _ConflictItemTile extends StatelessWidget {
  const _ConflictItemTile({required this.item});

  final ItemDiff item;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final number = item.number;
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
              padding: EdgeInsets.only(left: number != null ? 32 : 0, top: 4),
              child: Text(
                _describeChange(localizations, change),
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  String _describeChange(AppLocalizations l, FieldChange change) {
    if (change.field == 'order') {
      // 'order' stores the catalog's (old) position as `remote` and the
      // local plan's (new) position as `local` — see _diffItems in
      // program.dart — so "from" is remote and "to" is local, matching the
      // rest of this dialog's local-vs-catalog framing.
      return l.catalogDiffReorderedFromTo(change.remote ?? '', change.local ?? '');
    }
    final label = fieldChangeLabel(l, change.field);
    // 'other' already reads as a complete sentence on its own ("Other
    // changes") — running it through the generic "{field} changed"
    // template would double up on "changed".
    if (change.field == 'other') {
      return label;
    }
    if (change.local == null && change.remote == null) {
      return l.catalogDiffFieldChangedGeneric(label);
    }
    return l.catalogDiffFieldChanged(
      label,
      _present(change.local),
      _present(change.remote),
    );
  }
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
